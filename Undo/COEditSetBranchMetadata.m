#import "COEditSetBranchMetadata.h"
#import <EtoileFoundation/Macros.h>

@implementation COEditSetBranchMetadata 

//static NSString *kCOOldMetadata = @"COOldMetadata";
//static NSString *kCONewMetadata = @"CONewMetadata";
//static NSString *kCOBranch = @"COBranch";
//
//- (id) initWithOldMetadata: (NSDictionary *)oldMeta
//               newMetadata: (NSDictionary *)newMeta
//                      UUID: (ETUUID*)aUUID
//                branchUUID: (ETUUID*)aBranch
//                      date: (NSDate*)aDate
//               displayName: (NSString*)aName
//{
//    NILARG_EXCEPTION_TEST(oldMeta);
//    NILARG_EXCEPTION_TEST(newMeta);
//    NILARG_EXCEPTION_TEST(aBranch);
//    
//    self = [super initWithUUID: aUUID date: aDate displayName: aName];
//    ASSIGN(old_, [NSDictionary dictionaryWithDictionary: oldMeta]);
//    ASSIGN(new_, [NSDictionary dictionaryWithDictionary: newMeta]);
//    ASSIGN(branch_, aBranch);
//    return self;
//}
//
//
//- (id) initWithPlist: (id)plist
//{
//    self = [super initWithPlist: plist];
//    
//    ASSIGN(old_, [plist objectForKey: kCOOldMetadata]);
//    ASSIGN(new_, [plist objectForKey: kCONewMetadata]);
//    ASSIGN(branch_, [ETUUID UUIDWithString: [plist objectForKey: kCOBranch]]);
//    
//    return self;
//}
//
//- (id)plist
//{
//    NSMutableDictionary *result = [NSMutableDictionary dictionary];
//    [result addEntriesFromDictionary: [super plist]];
//    [result setObject: old_ forKey: kCOOldMetadata];
//    [result setObject: new_ forKey: kCONewMetadata];
//    [result setObject: [branch_ stringValue] forKey: kCOBranch];
//    [result setObject: kCOEditSetBranchMetadata forKey: kCOUndoAction];
//    return result;
//}
//
//- (COEdit *) inverseForApplicationTo: (COPersistentRootInfo *)aProot
//{
//    return [[[[self class] alloc] initWithOldMetadata: new_
//                                          newMetadata: old_
//                                                 UUID: uuid_
//                                           branchUUID: branch_
//                                                 date: date_
//                                          displayName: displayName_] autorelease];
//}
//
//- (void) applyToPersistentRoot: (COPersistentRootInfo *)aProot
//{
//    [aProot setMetadata: new_];
//}
//
//+ (BOOL) isUndoable
//{
//    return YES;
//}

@end
