#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>

@interface TestCOObject : NSObject <UKTest> {
	
}

@end


@implementation TestCOObject

#if 0



- (void) testObjectMerging
{
	NSLog(@"Testing object merging");
    
	COEditingContext *ctx = [[COEditingContext alloc] init];
	COObject *obj1 = [[COObject alloc] initWithContext:ctx];
	[obj1 setValue: @"Necronomicon" forProperty: @"title"];
	[obj1 setValue: @"Abdhul Al-hazred" forProperty: @"author"];
	[obj1 setValue: A(@"H.P. Lovecraft", @"Eric Wasylishen") forProperty: @"readers"];
	
	COObject *obj2 = [[COObject alloc] initWithContext:ctx];
	[obj2 setValue: @"The King in Yellow" forProperty: @"title"];
	[obj2 setValue: A(@"Eric Wasylishen") forProperty: @"readers"];
	
	COObject *obj3 = [[COObject alloc] initWithContext:ctx];
	[obj3 setValue: @"The King in Blue" forProperty: @"title"];
	[obj3 setValue: A(@"H.P. Lovecraft", @"Eric Wasylishen", @"Tolkien") forProperty: @"readers"];
	
	COObjectGraphDiff *oa = [COObjectGraphDiff diffObject: obj1 with: obj2];
	COObjectGraphDiff *ob = [COObjectGraphDiff diffObject: obj1 with: obj3];
	COObjectGraphDiff *merged = [COObjectGraphDiff mergeDiff: oa withDiff: ob];
	
	NSLog(@"O-A diff: %@", oa);
	NSLog(@"O-B diff: %@", ob);
	NSLog(@"Merged diff: %@", merged);  
	
	[merged applyToContext:ctx];
	
	NSLog(@"Merged object:%@", obj1);
	
	NSLog(@"Obejct merging works");
	
	
	[ctx release];
}

- (void) testObjectComposition
{
	NSLog(@"Testing object composition");
	ETUUID *libraryUUID;
	
	{
		COStoreCoordinator *sc = [[COStoreCoordinator alloc] initWithURL: STORE_URL];
		COEditingContext *ctx = [[COEditingContext alloc] initWithStoreCoordinator: sc];
		
		COObject *book1 = [[COObject alloc] initWithContext:ctx];
		[book1 setValue: @"The King in Yellow" forProperty: @"title"];
		[book1 setValue: A(@"Eric Wasylishen") forProperty: @"readers"];  
		
		COObject *book2 = [[COObject alloc] initWithContext:ctx];
		[book2 setValue: @"The King in Blue" forProperty: @"title"];
		[book2 setValue: A(@"H.P. Lovecraft", @"Eric Wasylishen", @"Tolkien") forProperty: @"readers"];
		
		COObject *obj1 = [[COObject alloc] initWithContext:ctx];
		[obj1 setValue: @"Arkham Public Library" forProperty: @"name"];
		[obj1 setValue: A(book1, book2) forProperty: @"books"];
		libraryUUID = [obj1 uuid];
		
		NSLog(@"obj1 %@", obj1);
		
		[ctx commit];
		
		[ctx release];
		[sc release];
	}
	
	NSLog(@"Reopening store..");  
	{
		COStoreCoordinator *sc2 = [[COStoreCoordinator alloc] initWithURL: STORE_URL];
		COEditingContext *ctx2 = [[COEditingContext alloc] initWithHistoryGraphNode: [sc2 tip]];
		COObject *library = [ctx2 objectForUUID: libraryUUID];
		NSLog(@"Library (reopened): %@", library);
		
		assert([library isFault]);
		assert([[library valueForProperty: @"name"] isEqual: @"Arkham Public Library"]);
		assert(![library isFault]);
		
		COObject *book1 = [[library valueForProperty: @"books"] objectAtIndex: 0];
		COObject *book2 = [[library valueForProperty: @"books"] objectAtIndex: 1];
		
		NSLog(@"Book1 %@ Book2 %@", book1, book2);
		
		assert([book1 isFault]);
		assert([book2 isFault]);
		assert([[book1 valueForProperty: @"title"] isEqual: @"The King in Yellow"]);
		
		[sc2 release];
		[ctx2 release];
	}
	NSLog(@"Testing object composition success");
}

#endif

@end
