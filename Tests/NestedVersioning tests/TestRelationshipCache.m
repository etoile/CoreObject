#import "TestCommon.h"

@interface TestRelationshipCache : NSObject <UKTest>
{
    CORelationshipCache *cache;
}
@end

@implementation TestRelationshipCache

- (id)init
{
    self = [super init];
    cache = [[CORelationshipCache alloc] initWithOwner: self];
    return self;
}
- (void)dealloc
{
    [cache release];
    [super dealloc];
}

- (void) testParent
{
    UKNil([cache parentForUUID: nil]);
    
    ETUUID *u1 = [ETUUID UUID];
    ETUUID *u2 = [ETUUID UUID];
    ETUUID *u3 = [ETUUID UUID];
    
    [cache updateRelationshipCacheWithOldValue: nil
                                       oldType: nil
                                      newValue: u2
                                       newType: kCOTypeCompositeReference
                                   forProperty: @"child"
                                      ofObject: u1];
    
    
    UKObjectsEqual([CORelationshipRecord recordWithUUID: u1 property: @"child"], [cache parentForUUID: u2]);

    [cache updateRelationshipCacheWithOldValue: nil
                                       oldType: nil
                                      newValue: u2
                                       newType: kCOTypeCompositeReference
                                   forProperty: @"child"
                                      ofObject: u3];
    
    UKObjectsEqual([CORelationshipRecord recordWithUUID: u3 property: @"child"], [cache parentForUUID: u2]);
    
    [cache updateRelationshipCacheWithOldValue: u2
                                       oldType: kCOTypeCompositeReference
                                      newValue: nil
                                       newType: kCOTypeCompositeReference
                                   forProperty: @"child"
                                      ofObject: u3];
    
    UKNil([cache parentForUUID: u2]);
}

- (void) testParentWithEmbeddedItemSet
{
    ETUUID *p1 = [ETUUID UUID];
    ETUUID *p2 = [ETUUID UUID];
    
    ETUUID *u2 = [ETUUID UUID];
    ETUUID *u3 = [ETUUID UUID];
    ETUUID *u4 = [ETUUID UUID];
    
    [cache updateRelationshipCacheWithOldValue: nil
                                       oldType: nil
                                      newValue: S(u2, u3)
                                       newType: kCOTypeCompositeReference | kCOTypeSet
                                   forProperty: @"children"
                                      ofObject: p1];
    
    UKObjectsEqual([CORelationshipRecord recordWithUUID: p1 property: @"children"], [cache parentForUUID: u2]);
    UKObjectsEqual([CORelationshipRecord recordWithUUID: p1 property: @"children"], [cache parentForUUID: u3]);
    UKNil([cache parentForUUID: u4]);
    
    [cache updateRelationshipCacheWithOldValue: S(u2, u3)
                                       oldType: kCOTypeCompositeReference | kCOTypeSet
                                      newValue: S(u2, u4)
                                       newType: kCOTypeCompositeReference | kCOTypeSet
                                   forProperty: @"children"
                                      ofObject: p1];
    
    UKObjectsEqual([CORelationshipRecord recordWithUUID: p1 property: @"children"], [cache parentForUUID: u2]);
    UKNil([cache parentForUUID: u3]);
    UKObjectsEqual([CORelationshipRecord recordWithUUID: p1 property: @"children"], [cache parentForUUID: u4]);

    // Test that adding u2 to p2 updates the parent correctly
    
    [cache updateRelationshipCacheWithOldValue: nil
                                       oldType: nil
                                      newValue: S(u2)
                                       newType: kCOTypeCompositeReference | kCOTypeSet
                                   forProperty: @"children"
                                      ofObject: p2];

    UKObjectsEqual([CORelationshipRecord recordWithUUID: p2 property: @"children"], [cache parentForUUID: u2]);
    UKNil([cache parentForUUID: u3]);
    UKObjectsEqual([CORelationshipRecord recordWithUUID: p1 property: @"children"], [cache parentForUUID: u4]);    
}

- (void) testReferences
{
    ETUUID *u1 = [ETUUID UUID];
    ETUUID *u2 = [ETUUID UUID];
    ETUUID *u3 = [ETUUID UUID];
    
    [cache updateRelationshipCacheWithOldValue: nil
                                       oldType: nil
                                      newValue: u2
                                       newType: kCOTypeReference
                                   forProperty: @"link1"
                                      ofObject: u1];
    
    [cache updateRelationshipCacheWithOldValue: nil
                                       oldType: nil
                                      newValue: u2
                                       newType: kCOTypeReference
                                   forProperty: @"link2"
                                      ofObject: u1];

    [cache updateRelationshipCacheWithOldValue: nil
                                       oldType: nil
                                      newValue: u2
                                       newType: kCOTypeReference
                                   forProperty: @"link1"
                                      ofObject: u3];
    
    UKObjectsEqual(S([CORelationshipRecord recordWithUUID: u1 property: @"link1"],
                     [CORelationshipRecord recordWithUUID: u1 property: @"link2"],
                     [CORelationshipRecord recordWithUUID: u3 property: @"link1"]), [cache referrersForUUID: u2]);
    
    [cache updateRelationshipCacheWithOldValue: u2
                                       oldType: kCOTypeReference
                                      newValue: nil
                                       newType: nil
                                   forProperty: @"link1"
                                      ofObject: u3];

    UKObjectsEqual(S([CORelationshipRecord recordWithUUID: u1 property: @"link1"],
                     [CORelationshipRecord recordWithUUID: u1 property: @"link2"]), [cache referrersForUUID: u2]);
}

- (void) testReferencesSet
{
    ETUUID *g1 = [ETUUID UUID];
    ETUUID *g2 = [ETUUID UUID];
    ETUUID *t1 = [ETUUID UUID];
    
    ETUUID *u1 = [ETUUID UUID];
    ETUUID *u2 = [ETUUID UUID];
    ETUUID *u3 = [ETUUID UUID];
    
    [cache updateRelationshipCacheWithOldValue: nil
                                       oldType: nil
                                      newValue: S(u1, u2)
                                       newType: kCOTypeReference | kCOTypeSet
                                   forProperty: @"groupContents"
                                      ofObject: g1];
    
    [cache updateRelationshipCacheWithOldValue: nil
                                       oldType: nil
                                      newValue: S(u2, u3)
                                       newType: kCOTypeReference | kCOTypeSet
                                   forProperty: @"groupContents"
                                      ofObject: g2];
    
    [cache updateRelationshipCacheWithOldValue: nil
                                       oldType: nil
                                      newValue: S(u3, g1)
                                       newType: kCOTypeReference | kCOTypeSet
                                   forProperty: @"taggedObjects"
                                      ofObject: t1];
    
    UKObjectsEqual(S([CORelationshipRecord recordWithUUID: g1 property: @"groupContents"]), [cache referrersForUUID: u1]);

    UKObjectsEqual(S([CORelationshipRecord recordWithUUID: g1 property: @"groupContents"],
                     [CORelationshipRecord recordWithUUID: g2 property: @"groupContents"]), [cache referrersForUUID: u2]);

    UKObjectsEqual(S([CORelationshipRecord recordWithUUID: g2 property: @"groupContents"],
                     [CORelationshipRecord recordWithUUID: t1 property: @"taggedObjects"]), [cache referrersForUUID: u3]);
    
    UKObjectsEqual(S([CORelationshipRecord recordWithUUID: t1 property: @"taggedObjects"]), [cache referrersForUUID: g1]);

    UKObjectsEqual(S(g2), [cache referrersForUUID: u3 propertyInParent: @"groupContents"]);
    UKObjectsEqual(S(t1), [cache referrersForUUID: u3 propertyInParent: @"taggedObjects"]);
    
    [cache updateRelationshipCacheWithOldValue: S(u1, u2)
                                       oldType: kCOTypeReference | kCOTypeSet
                                      newValue: S(u1, u3)
                                       newType: kCOTypeReference | kCOTypeSet
                                   forProperty: @"groupContents"
                                      ofObject: g1];
    
    [cache updateRelationshipCacheWithOldValue: S(u2, u3)
                                       oldType: kCOTypeReference | kCOTypeSet
                                      newValue: [NSSet set]
                                       newType: kCOTypeReference | kCOTypeSet
                                   forProperty: @"groupContents"
                                      ofObject: g2];
    
    
    UKObjectsEqual(S([CORelationshipRecord recordWithUUID: g1 property: @"groupContents"]), [cache referrersForUUID: u1]);    
    UKObjectsEqual([NSSet set], [cache referrersForUUID: u2]);
    UKObjectsEqual(S([CORelationshipRecord recordWithUUID: g1 property: @"groupContents"],
                     [CORelationshipRecord recordWithUUID: t1 property: @"taggedObjects"]), [cache referrersForUUID: u3]);
}

@end