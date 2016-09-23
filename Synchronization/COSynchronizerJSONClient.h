/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@class COSynchronizerJSONClient;

@protocol COSynchronizerJSONClientDelegate <NSObject>

- (void) JSONClient: (COSynchronizerJSONClient *)client sendTextToServer: (NSString *)text;

- (void) JSONClient: (COSynchronizerJSONClient *)client didStartSharingOnBranch: (COBranch *)aBranch;

@end

@interface COSynchronizerJSONClient : NSObject <COSynchronizerClientDelegate>
{
	NSMutableArray *queuedMessages;
	BOOL paused;
}

@property (nonatomic, readwrite, strong) id<COSynchronizerJSONClientDelegate> delegate;
@property (nonatomic, readwrite, weak) COSynchronizerClient *client;

- (void) receiveTextFromServer: (NSString *)text;

@property (nonatomic, readwrite, assign, getter=isPaused) BOOL paused;

@end
