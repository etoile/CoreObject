/**
    Copyright (C) 2012 Eric Wasylishen

    Date:  March 2012
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <CoreObject/COType.h>

@class ETUUID;


#pragma mark base class

@interface COItemGraphEdit : NSObject <NSCopying>
{
    ETUUID *UUID;
    NSString *attribute;
    id sourceIdentifier;
}

@property (readonly, nonatomic) ETUUID *UUID;
@property (readonly, nonatomic) NSString *attribute;
@property (readonly, nonatomic) id sourceIdentifier;

// NO applyTo: (applying a set of array edits requires a special procedure)
// NO doesntConflictWith: (checking a set of array edits for conflicts requires a special procedure)

- (BOOL) isEqualIgnoringSourceIdentifier: (id)other;

- (instancetype) initWithUUID: (ETUUID *)aUUID
          attribute: (NSString *)anAttribute
   sourceIdentifier: (id)aSourceIdentifier NS_DESIGNATED_INITIALIZER;

// information

@property (nonatomic, readonly) NSSet *insertedInnerItemUUIDs;

- (BOOL) isSameKindOfEdit: (COItemGraphEdit*)anEdit;

@end









