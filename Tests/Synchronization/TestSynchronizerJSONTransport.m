#import "TestCommon.h"

#import "COSynchronizerJSONClient.h"
#import "COSynchronizerJSONServer.h"

@interface TestSynchronizerJSONTransportDelegate : NSObject <COSynchronizerJSONClientDelegate, COSynchronizerJSONServerDelegate>
@property (nonatomic, readwrite, weak) COSynchronizerJSONServer *server;
@property (nonatomic, readwrite, weak) COSynchronizerJSONClient *client1;
@property (nonatomic, readwrite, weak) COSynchronizerJSONClient *client2;
@end

@implementation TestSynchronizerJSONTransportDelegate

@synthesize server, client1, client2;

- (void) JSONServer: (COSynchronizerJSONServer *)server sendText: (NSString *)text toClient: (NSString *)client
{
	if ([client isEqualToString: @"client1"])
	{
		[self.client1 receiveTextFromServer: text];
	}
	else if ([client isEqualToString: @"client2"])
	{
		[self.client2 receiveTextFromServer: text];
	}
	else
	{
		ETAssertUnreachable();
	}
}

- (void) JSONClient: (COSynchronizerJSONClient *)client sendTextToServer: (NSString *)text
{
	[self.server receiveText: text fromClient: client.client.clientID];
}

- (void) JSONClient: (COSynchronizerJSONClient *)client didStartSharingOnBranch: (COBranch *)aBranch
{
}

@end


@interface TestSynchronizerJSONTransport : NSObject <UKTest>
{
	TestSynchronizerJSONTransportDelegate *transportDelegate;
	COSynchronizerJSONServer *server;
	COSynchronizerJSONClient *client1;
	COSynchronizerJSONClient *client2;
}
@end


@implementation TestSynchronizerJSONTransport

- (id) init
{
	SUPERINIT;
	transportDelegate = [TestSynchronizerJSONTransportDelegate new];
	server = [COSynchronizerJSONServer new];
	client1 = [COSynchronizerJSONClient new];
	client2 = [COSynchronizerJSONClient new];
	server.delegate = transportDelegate;
	client1.delegate = transportDelegate;
	client2.delegate = transportDelegate;
	
	
	return self;
}

@end
