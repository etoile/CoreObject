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
	UKNotNil([self objects]);
	UKTrue([[self objects] isEmpty]);

	[self create];
	[self createChildFileWithName: @"Wherever"];
	[self createChildFileWithName: @"Hector"];
	UKFalse([[self objects] isEmpty]);
	UKIntsEqual(2, [[self objects] count]);
	[self delete];
}

@end

@implementation SubDirectory

@end
