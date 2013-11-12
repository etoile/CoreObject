#import <CoreObject/COSynchronizerClient.h>

@class COSynchronizerJSONClient;

@protocol COSynchronizerJSONClientDelegate <NSObject>

- (void) JSONClient: (COSynchronizerJSONClient *)client sendTextToServer: (NSString *)text;

- (void) JSONClient: (COSynchronizerJSONClient *)client didStartSharingOnBranch: (COBranch *)aBranch;

@end
@interface COSynchronizerJSONClient : NSObject <COSynchronizerClientDelegate>

@property (nonatomic, readwrite, strong) id<COSynchronizerJSONClientDelegate> delegate;
@property (nonatomic, readwrite, weak) COSynchronizerClient *client;

- (void) receiveTextFromServer: (NSString *)text;

@end