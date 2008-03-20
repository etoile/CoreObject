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
@interface SubFile : COFile
@end

@interface COFile (Tests) <UKTest>
@end

@implementation COFile (Tests)

- (id) initForTest
{
	SUPERINIT;
	return [self initWithURL: TEMP_URL isCopyPromise: NO];
}

- (void) testCopy
{
	id file = [self copy];
	UKTrue([file isCopyPromise]);
	UKObjectsEqual([self URL], [file URL]);
	DESTROY(file);
}

- (void) testIsEqual
{
	NSObject *obj = [[NSObject alloc] init];
	COFile *file1 = [COFile objectWithURL: [self URL]];
	SubFile *file2 = [SubFile objectWithURL: [self URL]];
	COGroup *group = [[COGroup alloc] init]; // TODO: Replace by -initWithURL
	CODirectory *dir = [CODirectory objectWithURL: [self URL]];

	UKObjectsNotEqual(self, obj);
	UKObjectsEqual(self, file1);
	UKObjectsEqual(self, file2);
	UKObjectsNotEqual(self, group);
	UKObjectsNotEqual(self, dir);

	DESTROY(obj);
	DESTROY(group);
}

- (void) testProperties
{
	id properties = [self properties];

	UKNotNil(properties); 
	UKTrue([properties count] > 0);
}

- (void) testMetadatas
{
	id metadatas = [self metadatas];

	UKNotNil(metadatas);
	UKIntsEqual(0, [metadatas count]); // Temp file doesn't exist
	[self create];
	metadatas = [self metadatas];
	UKTrue([metadatas count] > 0);
	[self delete];
}

- (void) testAccessors
{
	UKNotNil([self name]);
	UKNotNil([self displayName]);
	UKNotNil([self icon]);
}

- (void) testFileExistence
{
	UKFalse([self exists]);
	[self create];
	UKTrue([self exists]);
	[self delete];
	UKFalse([self exists]);

	id file = [COFile objectWithURL: [NSURL fileURLWithPath: @"~"]];
	UKFalse([file exists]); // file object points to a directory and not a file
}

@end

@implementation SubFile

@end
