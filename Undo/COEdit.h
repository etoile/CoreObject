#import <Foundation/Foundation.h>

#import <EtoileFoundation/ETUUID.h>

@class COEditingContext;

@interface COEdit : NSObject
{
    ETUUID *_storeUUID;
    ETUUID *_persistentRootUUID;
    NSDate *_timestamp;
    NSString *_displayName;
}

+ (COEdit *) editWithPlist: (id)aPlist;
- (id) plist;

@property (readwrite, nonatomic, copy) ETUUID *storeUUID;
@property (readwrite, nonatomic, copy) ETUUID *persistentRootUUID;
@property (readwrite, nonatomic, copy) NSDate *timestamp;
@property (readwrite, nonatomic, copy) NSString *displayName;

- (COEdit *) inverse;

// FIXME: Perhaps distinguish between edits that can't be applied and edits that are already applied. (e.g. "create branch", but that branch already exists)

- (BOOL) canApplyToContext: (COEditingContext *)aContext;

- (void) applyToContext: (COEditingContext *)aContext;

/**
 * Framework private
 */
- (id) initWithPlist: (id)plist;

/**
 * Framework private, implemented by COEdit but not subclasses
 */
- (id) copyWithZone:(NSZone *)zone;

@end

