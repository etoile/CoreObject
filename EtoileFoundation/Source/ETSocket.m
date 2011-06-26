#import "ETSocket.h"
#import "Macros.h"
#import "NSFileHandle+Socket.h"
#import "EtoileCompatibility.h"
#include <openssl/ssl.h>
#include <openssl/err.h>
#include <fcntl.h>
#include "glibc_hack_unistd.h"
#include <arpa/inet.h>
#include <netinet/in.h>
#include <netdb.h>

NSString *ETSocketException = @"ETSocketException";

/**
 * Private subclass handling sockets with SSL enabled.
 */
@interface ETSSLSocket : ETSocket
@end

@interface ETSocket (Private)
- (void)receiveData: (NSNotification*)aNotification;
@end

@implementation ETSocket
+ (void)initialize
{
	SSL_library_init();
}

- (id)initWithFileHandle: (NSFileHandle*)anHandle
{
	SUPERINIT;
	handle = [anHandle retain];
	return self;
}

- (id)initConnectedToRemoteHost: (NSString*)aHost
					 forService: (NSString*)aService
{
	NSFileHandle *theHandle = [NSFileHandle fileHandleConnectedToRemoteHost: aHost
	                                                             forService: aService];
	if (nil == theHandle)
	{
		return nil;
	}
	return [self initWithFileHandle: theHandle];
}
+ (id)socketConnectedToRemoteHost: (NSString*)aHost
					   forService: (NSString*)aService
{
	return [[[self alloc] initConnectedToRemoteHost: aHost
										 forService: aService] autorelease];
}
- (BOOL)negotiateSSL
{
	// Put the file descriptor in blocking mode so that the SSL_connect call
	// will complete synchronously.
	fcntl([handle fileDescriptor], F_SETFL, 0);
	sslContext = SSL_CTX_new(SSLv23_client_method());
	ssl = SSL_new(sslContext);
	SSL_set_fd(ssl, [handle fileDescriptor]);
	int ret = SSL_connect(ssl);
	fcntl([handle fileDescriptor], F_SETFL, O_NONBLOCK);
	isa = [ETSSLSocket class];
	return ret == 1;
}

- (void)setDelegate: (id)aDelegate
{
	delegate = aDelegate;
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	if (nil != delegate)
	{
		[center addObserver: self
				   selector: @selector(receiveData:)
					   name: NSFileHandleDataAvailableNotification
					 object: handle];
		[handle waitForDataInBackgroundAndNotify];
	}
	else
	{
		[center removeObserver: self];
	}
}
- (NSMutableData*)readDataFromSocket
{
	NSMutableData *data = [NSMutableData data];
	int s = [handle fileDescriptor];
	int count = 0;
	while (0 < (count = read(s, buffer, 512)))
	{
		[data appendBytes: buffer length: count];
	}
	return data;
}
- (void)receiveData: (NSNotification*)aNotification
{
	NSMutableData *data = [self readDataFromSocket];
	FOREACH(inFilters, filter, id<ETSocketFilter>)
	{
		data = [filter filterData: data];
	}
	if (nil != data)
	{
		[delegate receivedData: data fromSocket: self];
	}
	[handle waitForDataInBackgroundAndNotify];
}
- (void)sendDataToSocket: (NSData*)data
{
	int s = [handle fileDescriptor];
	const char *bytes = [data bytes];
	unsigned len = [data length];

	int sent;
	while(len > 0)
	{
		sent = write(s, bytes, len);
		if (sent < 0)
		{
			if (errno != EAGAIN && 
				errno != EINTR && 
				errno != EAGAIN && 
				errno != EWOULDBLOCK)
			{
				[NSException raise: ETSocketException
							format: @"Sending failed"];
			}
			sent = 0;
		}
		len -= sent;
		bytes += sent;
	}
}
- (void)sendData: (NSData*)data
{
	if ([outFilters count] > 0)
	{
		data = [data mutableCopy];
		FOREACH(outFilters, filter, id<ETSocketFilter>)
		{
			data = [filter filterData: (NSMutableData*)data];
		}
	}
	[self sendDataToSocket: data];
}
- (void)dealloc
{
	[inFilters release];
	[outFilters release];
	[handle release];
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center removeObserver: self];
	[super dealloc];
}
@end

@implementation ETSSLSocket
- (NSMutableData*)readDataFromSocket
{
	NSMutableData *data = [NSMutableData data];
	int count = 0;
	while (0 < (count = SSL_read(ssl, buffer, 512)))
	{
		[data appendBytes: buffer length: count];
	}
	return data;
}
- (void)sendDataToSocket: (NSData*)data
{
	const char *bytes = [data bytes];
	unsigned len = [data length];

	int sent;
	int error;
	while(len > 0)
	{
		sent = SSL_write(ssl, bytes, len);
		if (sent <= 0)
		{
			error = SSL_get_error(ssl, sent);
			while(error == SSL_ERROR_WANT_WRITE || error == SSL_ERROR_WANT_READ)
			{
				sent = SSL_write(ssl, bytes, len);
				if(sent <= 0)
				{
					error = SSL_get_error(ssl, sent);
				}
				else
				{
					error = SSL_ERROR_NONE;
				}
			}
			if(error != SSL_ERROR_NONE)
			{
				[NSException raise: ETSocketException
							format: @"Sending failed"];
			}
		}
		len -= sent;
		bytes += sent;
	}
}
- (void)dealloc
{
	SSL_free(ssl);
	SSL_CTX_free(sslContext);
	[super dealloc];
}
@end


@implementation ETListenSocket
+ (id)listenSocketOnPort: (unsigned short)aPort
{
	return [[[self alloc] initOnPort: aPort] autorelease];
}

+ (id)listenSocketForAddress: (NSString*)anAddress
                      onPort: (unsigned short)aPort
{
	return [[[self alloc] initForAddress: anAddress
	                              onPort: aPort] autorelease];
}

- (id)initWithSockAddr: (struct sockaddr_storage*)address
{
	// We create stream sockets only:
	int s = socket(address->ss_family, SOCK_STREAM, IPPROTO_TCP);
	if (0 == s)
	{
		NSLog(@"Failed to create socket.");
		return nil;
	}
	size_t addrSize = 0;
	if (AF_INET == address->ss_family)
	{
		addrSize = sizeof(struct sockaddr_in);
	}
	else if (AF_INET6 == address->ss_family)
	{
		addrSize = sizeof(struct sockaddr_in6);
	}
	if (bind(s, (struct sockaddr*)address, addrSize))
	{
		NSLog(@"Failed to bind socket.");
		close(s);
		return nil;
	}

	if (listen(s, 1))
	{
		NSLog(@"Failed to make socket listen.");
		close(s);
		return nil;
	}

	NSFileHandle *descriptor = [[[NSFileHandle alloc] initWithFileDescriptor: s
	                                                          closeOnDealloc: YES] autorelease];

	if (nil == descriptor)
	{
		return nil;
	}

	if (nil == (self = [super initWithFileHandle: descriptor]))
	{
		return nil;
	}
	return self;
}

- (id)initForAddress: (NSString*) anAddress
              onPort: (unsigned short)aPort
{
	struct sockaddr_storage sa;
	const char* address = [anAddress UTF8String];

	// sockaddr_storage can be safely cast to the protocol-specific variants. We
	// define the following aliases to load sa with the protocol specific values.
	struct sockaddr_in *sa4 = (struct sockaddr_in*)&sa;
	struct sockaddr_in6 *sa6 = (struct sockaddr_in6*)&sa;

	// First we test whether anAddress contained an IPv4 address
	int res = inet_pton(AF_INET,address,&(sa4->sin_addr));

	// A return value of -1 signifies an error during the conversion.
	if (-1 == res)
	{
		NSDebugLog(@"Error %d in IP address conversion",errno);
	}

	// A return value of 1 signifies success, in all other cases (only 0 == res
	// should happen, though) we attempt conversion to an IPv6 address.
	if (1 == res)
	{
		sa4->sin_family = AF_INET;
		sa4->sin_port = htons(aPort);
	}
	else
	{
		res = inet_pton(AF_INET6,address,&(sa6->sin6_addr));
		if (-1 == res)
		{
			NSDebugLog(@"Error %d in IP address conversion",errno);
		}
		if (1 == res)
		{
			sa6->sin6_family = AF_INET6;
			sa6->sin6_port = htons(aPort);
		}
		else
		{
			NSDebugLog(@"Could not convert \"%@\" to an IP address.", anAddress);
			return nil;
		}
	}
	return [self initWithSockAddr: &sa];
}

- (id)initOnPort: (unsigned short)aPort
{
	struct addrinfo hints, *address_list, *address;
	const char* port = [[[NSNumber numberWithInt: aPort] stringValue] UTF8String];
	memset(&hints, 0, sizeof hints);
	hints.ai_family = AF_UNSPEC;
	hints.ai_socktype = SOCK_STREAM;
	hints.ai_flags = AI_PASSIVE;

	// Resolve ourselves:
	int res = getaddrinfo(NULL,port,&hints, &address_list);
	if (res != 0)
	{
		NSLog(@"Error in getaddrinfo: %s", gai_strerror(res));
		return nil;
	}

	// Try to set up the socket for one of our addresses;
	for (address = address_list; address != NULL; address = address->ai_next)
	{
		// NOTE: Don't assign the result to self. Once it's nil, we'll not be
		// calling any methods.
		id listener = [self initWithSockAddr: (struct sockaddr_storage*)(address->ai_addr)];

		if (listener != nil)
		{
			freeaddrinfo(address_list);
			address_list = NULL;
			return listener;
		}
	}
	if (address_list != NULL)
	{
		freeaddrinfo(address_list);
	}
	return nil;
}

// Wrap -initWithSockAddr in order not expose internals.
- (id)initWithSocketAddress: (NSData*)socketAddress
{
	return [self initWithSockAddr: (struct sockaddr_storage*)[socketAddress bytes]];
}

- (void)sendData: (NSData*)data
{
	NSDebugLog(@"Attempt to send data via socket (%@) in listening mode", self);
}

- (void)makeHandleSafelyAcceptConnectionInBackgroundAndNotify
{
	if (NO == hasAccept)
	{
		[handle acceptConnectionInBackgroundAndNotify];
		hasAccept = YES;
	}
}
- (void)newConnection: (NSNotification*)notification
{
	hasAccept = NO;
	//TODO: Maybe add some ACL checking mechanism?
	NSFileHandle *clientHandle = [[notification userInfo] objectForKey: NSFileHandleNotificationFileHandleItem];

	/*
	 * TODO: For SSL connections, add a ETIncomingSSLSocket subclass with proper
	 * SSL parameters.
	 */
	ETSocket *clientSocket = [[[ETSocket alloc] initWithFileHandle: clientHandle] autorelease];

	// Notify the delegate about the new connection:
	[delegate newConnection: clientSocket
	             fromSocket: self];

	// Accept further connections:
	[self makeHandleSafelyAcceptConnectionInBackgroundAndNotify];
}

- (void)setDelegate: (id)aDelegate
{
	if (aDelegate == delegate)
	{
		return;
	}
	else if (delegate != nil)
	{
		delegate = aDelegate;
		return;
	}
	else
	{
		delegate = aDelegate;
	}

	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	if (nil != delegate)
	{
		[center addObserver: self
		           selector: @selector(newConnection:)
	                   name: NSFileHandleConnectionAcceptedNotification
		             object: handle];
	
		[self makeHandleSafelyAcceptConnectionInBackgroundAndNotify];
	}
	else
	{
		[center removeObserver: self];
	}
}
@end
