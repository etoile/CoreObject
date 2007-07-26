/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "OKCollection.h"
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
	OKFileObject *fo1 = [[OKFileObject alloc] initWithPath: file1];
	UKStringsEqual(@"TestFile1.txt", [[fo1 path] lastPathComponent]);
	OKFileObject *fo2 = [[OKFileObject alloc] initWithPath: file2];
	UKStringsEqual(@"TestFile2.txt", [[fo2 path] lastPathComponent]);

	NSString *p = [testPath stringByAppendingPathComponent: @"test.collection"];
	OKCollection *collection = [[OKCollection alloc] initWithLocation: p];
	UKNotNil(collection);
	BOOL isDir = NO;
	UKTrue([fm fileExistsAtPath: p isDirectory: &isDir]);
	UKTrue(isDir);
//	NSLog(@"%@", [collection pathForFileObject: fo1]);
//	NSLog(@"%@", [collection pathForFileObject: fo2]);
	[collection addObject: fo1];
	UKIntsEqual([[collection objects] count], 1);
	[collection addObject: fo2];
	UKIntsEqual([[collection objects] count], 2);

	NSString *p1 = [fo1 path];
	NSString *p2 = [fo2 path];
	UKTrue([p1 hasPrefix: [collection location]]);
	UKTrue([p2 hasPrefix: [collection location]]);

	[collection removeObject: fo2];
	UKIntsEqual([[collection objects] count], 1);
	[collection removeObject: fo1];
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
	[@"This is a test file for OKCollection" writeToFile: file1 atomically: YES];
	ASSIGN(file2, [testPath stringByAppendingPathComponent: @"TestFile2.txt"]);
	[@"This is another test file for OKCollection" writeToFile: file2 atomically: YES];
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
