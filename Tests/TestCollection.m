#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"
#import "COEditingContext.h"
#import "COBookmark.h"
#import "COObject.h"
#import "COCollection.h"
#import "COContainer.h"
#import "COGroup.h"
#import "COLibrary.h"
#import "COPersistentRoot.h"
#import "COTag.h"

@interface TestCollection : EditingContextTestCase <UKTest>
@end

@implementation TestCollection

- (void)testLibraryForContentType
{
	ETEntityDescription *bookmarkType = [[ctx modelRepository] descriptionForName: @"COBookmark"];

	UKObjectsEqual([ctx bookmarkLibrary], [ctx libraryForContentType: bookmarkType]);
}

- (void)testBookmarkLibrary
{
	COLibrary *library = [ctx bookmarkLibrary];
	ETEntityDescription *entity = [library entityDescription];

	UKObjectsEqual([COLibrary class], [library class]);
	UKStringsEqual(@"COBookmarkLibrary", [entity name]);
	UKStringsEqual(@"COLibrary", [[entity parent] name]);

	UKStringsEqual(@"COBookmark", [[[entity propertyDescriptionForName: @"contents"] type] name]);
	UKObjectsEqual([ETUTI typeWithClass: [COBookmark class]], [library objectType]);

	UKTrue([library isOrdered]);
}
								  
- (void)testNoteLibrary
{
	COLibrary *library = [ctx noteLibrary];
	ETEntityDescription *entity = [library entityDescription];

	UKObjectsEqual([COLibrary class], [library class]);
	UKStringsEqual(@"CONoteLibrary", [entity name]);
	UKStringsEqual(@"COLibrary", [[entity parent] name]);

	UKStringsEqual(@"COContainer", [[[entity propertyDescriptionForName: @"contents"] type] name]);
	UKObjectsEqual([ETUTI typeWithClass: [COContainer class]], [library objectType]);

	UKTrue([library isOrdered]);
}

- (void)testTagLibrary
{
	COTagLibrary *library = [[ctx insertNewPersistentRootWithEntityName: @"COTagLibrary"] rootObject];
	
	UKObjectsEqual([ETUTI typeWithClass: [COTag class]], [library objectType]);
	UKTrue([[library content] isKindOfClass: [NSMutableArray class]]);
	UKTrue([[library tagGroups] isKindOfClass: [NSMutableArray class]]);
}

- (void)testTagGroup
{
	COTagGroup *tagGroup = [[ctx insertNewPersistentRootWithEntityName: @"COTagGroup"] rootObject];
	COTag *tag = [[ctx insertNewPersistentRootWithEntityName: @"COTag"] rootObject];

	UKObjectsEqual([ETUTI typeWithClass: [COTag class]], [tagGroup objectType]);
	UKTrue([[tagGroup content] isKindOfClass: [NSMutableArray class]]);
	UKTrue([[tag tagGroups] isKindOfClass: [NSSet class]]);

	[tagGroup addObject: tag];

	UKObjectsEqual(A(tag), [tagGroup content]);
	UKObjectsEqual(S(tagGroup), [tag tagGroups]);
}

@end
