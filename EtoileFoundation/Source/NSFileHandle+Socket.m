#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include "glibc_hack_unistd.h"
#import <Foundation/Foundation.h>

@implementation NSFileHandle (SocketAdditions)
+ (NSFileHandle*) fileHandleConnectedToRemoteHost: (NSString*)aHost
                                       forService: (NSString*)aService
{
	const char * server = [aHost UTF8String];
	const char * service = [aService UTF8String];
	struct addrinfo hints, *res0;
	int error;

	memset(&hints, 0, sizeof(hints));
	hints.ai_family = PF_UNSPEC;
	hints.ai_socktype = SOCK_STREAM;
	//Ask for a stream address.
	error = getaddrinfo(server, service, &hints, &res0);
	if (error) 	{ return nil; }

	int s = -1;
	for (struct addrinfo *res = res0; 
		res != NULL && s < 0 ; 
		res = res->ai_next) 
	{
		s = socket(res->ai_family, res->ai_socktype,
			res->ai_protocol);
		//If the socket failed, try the next address
		if (s < 0) 	{ continue ; }

		//If the connection failed, try the next address
		if (connect(s, res->ai_addr, res->ai_addrlen) < 0) 
		{
			close(s);
			s = -1;
			continue;
		}
	}
	freeaddrinfo(res0);
	if (s < 0) { return nil; }
	return [[[self alloc] initWithFileDescriptor: s
	                              closeOnDealloc: YES] autorelease];
}
@end
