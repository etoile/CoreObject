#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETUUID.h>
#import <CoreObject/COTrack.h>

@class COEditingContext;

@interface COCommand : NSObject <COTrackNode>

+ (COCommand *) commandWithPlist: (id)aPlist;
- (id) plist;

- (COCommand *) inverse;

// FIXME: Perhaps distinguish between edits that can't be applied and edits that are already applied. (e.g. "create branch", but that branch already exists)

- (BOOL) canApplyToContext: (COEditingContext *)aContext;

- (void) applyToContext: (COEditingContext *)aContext;

/**
 * Framework private
 */
- (id) initWithPlist: (id)plist;


@end

@interface COSingleCommand : COCommand
{
    ETUUID *_storeUUID;
    ETUUID *_persistentRootUUID;
    NSDate *_timestamp;
}

@property (readwrite, nonatomic, copy) ETUUID *storeUUID;
@property (readwrite, nonatomic, copy) ETUUID *persistentRootUUID;
@property (readwrite, nonatomic, copy) NSDate *timestamp;
/**
 * Framework private, implemented by COCommand but not subclasses
 */
- (id) copyWithZone:(NSZone *)zone;

@end

