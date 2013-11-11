#import <CoreObject/COSynchronizerClient.h>

@protocol COSynchronizerJSONClientDelegate <NSObject>

- (void) sendTextToServer: (NSString *)text;

@end

@interface COSynchronizerJSONClient : NSObject <COSynchronizerClientDelegate>

@property (nonatomic, readwrite, strong) id<COSynchronizerJSONClientDelegate> delegate;
@property (nonatomic, readwrite, weak) COSynchronizerClient *client;

- (void) receiveTextFromServer: (NSString *)text;

@end