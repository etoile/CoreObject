#import <Foundation/Foundation.h>

@protocol COUndoNode <NSObject>

@property (readonly, nonatomic) NSDate *timestamp;

/**
 * Doesn't make sense to store localized messages in the undo track..
 * pass to COCommitDescriptor to localize (?)
 */
@property (readonly, nonatomic) NSDictionary *metadata;

@end
