/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import "COFile.h"
#import "CODirectory.h"
#import "COGroup.h"
#import "GNUstep.h"

#define FM [NSFileManager defaultManager]
#define TEMP_URL [NSURL fileURLWithPath: [FM nameForTempFile]]

@interface COFile (Private)
- (id) initWithURL: (NSURL *)url isCopyPromise: (BOOL)isCopy;
@end

/* For testing type equality */
@interface SubDirectory : CODirectory
@end

@interface CODirectory (Tests) <UKTest>
@end

@implementation CODirectory (Tests)

- (id) initForTest
{
	SUPERINIT;
	return [self initWithURL: TEMP_URL isCopyPromise: NO];
}

- (void) testIsEqual
{
	NSObject *obj = [[NSObject alloc] init];
	CODirectory *dir1 = [CODirectory objectWithURL: [self URL]];
	SubDirectory *dir2 = [SubDirectory objectWithURL: [self URL]];
	COGroup *group = [[COGroup alloc] init]; // TODO: Replace by -initWithURL
	COFile *file = [COFile objectWithURL: [self URL]];

	UKObjectsNotEqual(self, obj);
	UKObjectsEqual(self, dir1);
	UKObjectsEqual(self, dir2);
	UKObjectsNotEqual(self, group);
	UKObjectsNotEqual(self, file);

	DESTROY(obj);
	DESTROY(group);
}

- (void) testFileExistence
{
	UKFalse([self exists]);
	[self create];
	UKTrue([self exists]);
	[self delete];
	UKFalse([self exists]);

	NSString *path = [FM nameForTempFile];
	BOOL result = [FM createFileAtPath: path contents: nil attributes: nil];
	UKTrue(result);
	id dir = [CODirectory objectWithURL: [NSURL fileURLWithPath: path]];
	UKFalse([dir exists]); // file object points to a file and not a directory
	if ([FM removeFileAtPath: path handler: nil] == NO)
		ETLog(@"Cannot delete the file at path %@", path);
}

- (void) createChildFileWithName: (id)name
{
	NSString *path = [[[self URL] path] appendPath: name];
	BOOL result = [FM createFileAtPath: path contents: nil attributes: nil];
	UKTrue(result);
}

- (void) testObjects
{
	UKNotNil([self members]);
	UKTrue([[self members] isEmpty]);

	[self create];
	[self createChildFileWithName: @"Wherever"];
	[self createChildFileWithName: @"Hector"];
	UKFalse([[self members] isEmpty]);
	UKIntsEqual(2, [[self members] count]);
	[self delete];
}

- (void) testMoveObject
{
	id file1 = [COFile objectWithURL: TEMP_URL];
	id sourceURL = [file1 URL];

	[self create];
	[file1 create];
	UKFalse([[self members] containsObject: file1]);

	[self addMember: file1];
	UKObjectsNotEqual([file1 URL], sourceURL);
	UKTrue([file1 exists]);
	UKTrue([[self members] containsObject: file1]);	
	
	id file2 = [COFile objectWithURL: sourceURL];
	UKFalse([file2 exists]);
	UKObjectsNotEqual([file2 URL], [file1 URL]);

	[self delete]; // will delete file1 moved inside
}

- (void) testCopyObject
{
	id file1 = [COFile objectWithURL: TEMP_URL];
	id sourceURL = [file1 URL];

	[self create];
	[file1 create];
	id file1Copy = [file1 copy];
	UKObjectsEqual(file1Copy, file1);
	UKTrue([file1Copy exists]); // points to file1 URL	
	UKFalse([[self members] containsObject: file1]);
	UKFalse([[self members] containsObject: file1Copy]);

	[self addMember: file1Copy];
	UKObjectsNotEqual([file1Copy URL], sourceURL);
	UKTrue([file1Copy exists]);
	UKTrue([[self members] containsObject: file1Copy]);
	
	UKTrue([file1 exists]);
	UKObjectsNotEqual([file1 URL], [file1Copy URL]);
	UKFalse([[self members] containsObject: file1]);	

	[self delete]; // will delete file1Copy located inside
	[file1 delete];
}

@end

@implementation SubDirectory

@end
