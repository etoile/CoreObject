/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"

/**
 * This class is for testing COSerialization, i.e. for testing the mapping
 * between COObject property values and their COItem representation.
 */
@interface TestSerialization : EditingContextTestCase <UKTest>
@end

@implementation TestSerialization

/**
 * Adds an attachment to the store and returns its NSData ID
 */
- (COAttachmentID *) createAttachment
{
    NSString *fakeAttachment1 = @"this is a large attachment";
    NSString *path1 = [[SQLiteStoreTestCase temporaryPathForTestStorage] stringByAppendingPathComponent: @"coreobject-test1.txt"];
    
    [fakeAttachment1 writeToFile: path1
                      atomically: YES
                        encoding: NSUTF8StringEncoding
						   error: NULL];

    COAttachmentID *hash1 = [store importAttachmentFromURL: [NSURL fileURLWithPath: path1]];
    return hash1;
}

- (void) testAttachment
{
	COAttachmentID *attachmentID = [self createAttachment];
	COPersistentRoot *proot = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"];
	OutlineItem *item = proot.rootObject;
	item.attachmentID = attachmentID;
	
	// Test writing to COItem
	
	COItem *itemValue = item.storeItem;
	UKIntsEqual(kCOTypeAttachment, [itemValue typeForAttribute: @"attachmentID"]);
	UKObjectsEqual(attachmentID, [itemValue valueForAttribute: @"attachmentID"]);
	
	// Test reading COItem into a COObjectGraphContext
	
	COObjectGraphContext *tempGraph = [COObjectGraphContext new];
	[tempGraph insertOrUpdateItems: @[itemValue]];
	COObject *deserializedObject = [tempGraph loadedObjectForUUID: itemValue.UUID];
	
	UKObjectsEqual(attachmentID, [deserializedObject valueForKey: @"attachmentID"]);
	UKObjectsEqual(@"COAttachmentID", [deserializedObject.entityDescription propertyDescriptionForName: @"attachmentID"].type.name);
}

- (void) testUnknowItemAttributes
{
	COPersistentRoot *proot = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"];
	COObject *rootObject = proot.rootObject;
	COMutableItem *item = [rootObject.storeItem mutableCopy];
	
	[item setValue: @"foo" forAttribute: @"bar" type: kCOTypeString];
	
	COItemGraph *itemGr = [[COItemGraph alloc] initWithItems: @[item] rootItemUUID: item.UUID];
	COObjectGraphContext *newCtx = [COObjectGraphContext new];
	
	// @"foo" : @"bar" should not cause a problem, it should be ignored
	// during deserialization
	UKDoesNotRaiseException([newCtx setItemGraph: itemGr]);
}

@end
