/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "COCollection.h"
#import "GNUstep.h"

@interface TestCollection: NSObject <UKTest>
{
	NSString *testPath;
	NSString *file1;
	NSString *file2;
	NSFileManager *fm;
}

@end

@implementation TestCollection
- (void) testBasic
{
	COFileObject *fo1 = [[COFileObject alloc] initWithPath: file1];
	UKStringsEqual(@"TestFile1.txt", [[fo1 path] lastPathComponent]);
	COFileObject *fo2 = [[COFileObject alloc] initWithPath: file2];
	UKStringsEqual(@"TestFile2.txt", [[fo2 path] lastPathComponent]);

	NSString *p = [testPath stringByAppendingPathComponent: @"test.collection"];
	COCollection *collection = [[COCollection alloc] initWithLocation: p];
	UKNotNil(collection);
	BOOL isDir = NO;
	UKTrue([fm fileExistsAtPath: p isDirectory: &isDir]);
	UKTrue(isDir);
//	NSLog(@"%@", [collection pathForFileObject: fo1]);
//	NSLog(@"%@", [collection pathForFileObject: fo2]);
	[collection addMember: fo1];
	UKIntsEqual([[collection objects] count], 1);
	[collection addMember: fo2];
	UKIntsEqual([[collection objects] count], 2);

	NSString *p1 = [fo1 path];
	NSString *p2 = [fo2 path];
	UKTrue([p1 hasPrefix: [collection location]]);
	UKTrue([p2 hasPrefix: [collection location]]);

	[collection removeMember: fo2];
	UKIntsEqual([[collection objects] count], 1);
	[collection removeMember: fo1];
	UKIntsEqual([[collection objects] count], 0);
	UKNil([fo1 path]);
	UKNil([fo2 path]);
}

- (id) init
{
	self = [super init];

	/* Create a subdirectory for testing */
	fm = [NSFileManager defaultManager];

	ASSIGN(testPath, [NSTemporaryDirectory() stringByAppendingPathComponent: @"CollectionTest"]);
	[fm createDirectoryAtPath: testPath attributes: nil];
	NSLog(@"Create %@", testPath);
	
	ASSIGN(file1, [testPath stringByAppendingPathComponent: @"TestFile1.txt"]);
	[@"This is a test file for COCollection" writeToFile: file1 atomically: YES];
	ASSIGN(file2, [testPath stringByAppendingPathComponent: @"TestFile2.txt"]);
	[@"This is another test file for COCollection" writeToFile: file2 atomically: YES];
	return self;

}

- (void) dealloc
{
	[fm removeFileAtPath: testPath handler: nil];
	NSLog(@"Remove %@", testPath);
	DESTROY(testPath);
	DESTROY(file1);
	DESTROY(file2);
	[super dealloc];
}

@end
