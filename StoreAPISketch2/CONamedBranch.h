#import <EtoileFoundation/EtoileFoundation.h>

@class COStore;

@interface CONamedBranch : NSObject
{
	COStore *store;
}

- (ETUUID*)UUID;

- (NSString*)name;
- (void)setName: (NSString*)name;

- (NSDictionary*)metadata;
- (void)setMetadata: (NSDictionary*)meta;

@end
