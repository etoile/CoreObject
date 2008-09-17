/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "CODirectory.h"
#import "COFile.h"
#import "GNUstep.h"

#define FM [NSFileManager defaultManager]
#define FM_HANDLER [CODirectory delegate]
#define FSPATH(x) [[x URL] path]

@interface CODirectory (Private)
- (BOOL) addMovedObject: (id)object;
- (BOOL) addCopiedObject: (id)object;
- (BOOL) checkObjectToBeRemovedOrDeleted: (id)object;
@end

@implementation CODirectory

+ (BOOL) isGroupAtURL: (NSURL *)anURL
{
	if ([anURL isFileURL] == NO)
		return NO;

	BOOL isDir = NO;
	BOOL result = [FM fileExistsAtPath: [anURL path] isDirectory: &isDir];

	return (result && isDir);
}

// NOTE: Shut down compiler warning.
+ (id) objectWithURL: (NSURL *)url
{
	return [super objectWithURL: url];
}

/** Returns the active trash directory.
	The returned directory may vary with the user. */
+ (CODirectory *) trashDirectory
{
	// FIXME: Use the real trash directory, as specified by Freedesktop, by 
	// using the implementation available in Outerspace.
	return [CODirectory objectWithURL: [NSURL fileURLWithPath: @"~"]];
}

static id fsServerDelegate = nil;

+ (id) delegate
{
	return fsServerDelegate;
}

+ (void) setDelegate: (id)delegate
{
	fsServerDelegate = delegate;
}

+ (void) initialize
{

}

- (id) init
{
	SUPERINIT;

	return self;
}

DEALLOC()

/** Tests equality by considering the type and URLs of the receiver and object. */
- (BOOL) isEqual: (id)object
{
	BOOL isSameType = ([object isKindOfClass: [self class]]);
	return (isSameType && [[self URL] isEqual: [object URL]]);
}

/** Checks whether the object can be hold by the recevier by checking type and 
	state. If it isn't thse case, mutation methods won't accept it. */
- (BOOL) isValidObject: (id)object
{
	// NOTE: May make sense to be less rigid...
	return [object isKindOfClass: [COFile class]];
}

/** Returns whether a directory exists at the receiver URL.
	Take note the method returns NO when a file exists at the URL instead of a
	directory. */
- (BOOL) exists
{
	return [[self class] isGroupAtURL: [self URL]];
}

/** Returns whether object belongs to the receiver directory by being stored 
	inside it. 
	Take note that	 this method returns NO if object points to a non-existent 
	file at a subpath of the receiver URL. */
- (BOOL) containsObject: (id)object
{
	return [[self members] containsObject: object];
}

/** Will return NO and won't add the object if the represented directory doesn't 
	exist on the file system. */
- (BOOL) addMember: (id)object
{
	if ([self isValidObject: object] == NO)
		return NO;

	BOOL result = NO;

	if ([object isCopyPromise])
	{
		result = [self addCopiedObject: object];
	}
	else
	{
		result = [self addMovedObject: object];
	}
	[object didAddToGroup: self];

	return result;
}

/** Creates a symbolic link at the URL of the receiver with the name of object 
	and pointing to the URL of this object. */
- (BOOL) addSymbolicLink: (id)object
{
	if ([self isValidObject: object] == NO)
		return NO;
	if ([object isCopyPromise])
	{
		[NSException raise: NSInvalidArgumentException 
		            format: @"Symbolically linked object %@ cannot be a copy promise", object];
	}

	NSString *linkName = [FSPATH(object) lastPathComponent];
	NSString *linkPath = [FSPATH(self) appendPath: linkName];
	return [FM createSymbolicLinkAtPath: linkPath pathContent: FSPATH(object)];
}

/** Creates a hard link at the URL of the receiver with the name of object 
	and pointing to the URL of this object. */
- (BOOL) addHardLink: (id)object
{
	if ([self isValidObject: object] == NO)
		return NO;
	if ([object isCopyPromise])
	{
		[NSException raise: NSInvalidArgumentException 
		            format: @"Hard linked object %@ cannot be a copy promise", object];
	}

	ETLog(@"Remove file %@", FSPATH(object));
	return [FM removeFileAtPath: FSPATH(object) handler: FM_HANDLER];
}

- (BOOL) addMovedObject: (id)object
{
	// NOTE: If we cache the children objects/files at some point, we will have 
	// to remove the moved object from the existing CODirectory instance that 
	// represents the path of its parent. 
	// id parentDir = [CODirectory objectWithURL: [[object URL] parentURL]];
	// [parentDir removeCachedObject: object]; or [parentDir recache]; or 
	// [object didRemoveFromGroup: self];
	NSString *destPath = [FSPATH(self) appendPath: 
		[FSPATH(object) lastPathComponent]];

	ETLog(@"Move file %@ to path %@", FSPATH(object), destPath);
	return [FM movePath: FSPATH(object) toPath: destPath handler: FM_HANDLER];
}

- (BOOL) addCopiedObject: (id)object
{
	NSString *destPath = [FSPATH(self) appendPath: 
		[FSPATH(object) lastPathComponent]];

	ETLog(@"Copy file %@ to path %@", FSPATH(object), destPath );
	return [FM copyPath: FSPATH(object) toPath: destPath handler: FM_HANDLER];
}

/** Create a directory when none exists at the receiver URL. */
- (BOOL) create
{
	return [FM createDirectoryAtPath: FSPATH(self) attributes: nil];
}

- (BOOL) checkObjectToBeRemovedOrDeleted: (id)object
{
	if ([self isValidObject: object] == NO)
		return NO;
	if ([object isCopyPromise])
	{
		[NSException raise: NSInvalidArgumentException 
		            format: @"Removed or deleted object %@ cannot be a copy "
		                    @"promise", object];
	}
	if ([self containsObject: object] == NO)
	{
		[NSException raise: NSInvalidArgumentException 
		            format: @"Object %@ to be removed or deleted cannot be "
		                    @"found inside the directory %@", object, self];
	}	
	return YES;
}

/** Removes the file instance from the receiver, but defers the deletion of the 
	represented file inside the directory until object is released/deallocated. 
	This lazy behavior for the delete filesystem operation makes possible to 
	move files accross directories (or other kind of CoreObject groups) in the 
	following way:
	[artDirectory removeMember: myPoemFile];
	[poetryDirectory addMember: myPoemFile]; */
- (BOOL) removeMember: (id)object;
{
	if ([self checkObjectToBeRemovedOrDeleted: object])
		return NO;

	BOOL result = [[CODirectory trashDirectory] addMember: object];
	[object didRemoveFromGroup: self];

	return result;
}

/** Deletes the file pointed by object if it is located inside the receiver 
	directory.
	After calling this method, -exists will return NO for object. */
- (BOOL) deleteObject: (id)object
{
	if ([self checkObjectToBeRemovedOrDeleted: object])
		return NO;

	// NOTE: If we cache the children objects/files at some point, we will have 
	// to remove the moved object from the existing CODirectory instance that 
	// represents the path of its parent. 

	return [FM removeFileAtPath: FSPATH(object) handler: FM_HANDLER];
}

/** Returns all files and directories located in the receiver directory. 
	This excludes files and directories inside subdirectories. */
- (NSArray *) members
{
	NSMutableArray *files = [NSMutableArray array];
	NSString *dirPath = FSPATH(self);
	// FIXME: Either I don't understand NSDirectoryEnumerator or GNUstep 
	// implementation is broken ;-)
	//NSDirectoryEnumerator *e = [FM enumeratorAtPath: dirPath];
	NSEnumerator *e = [[FM directoryContentsAtPath: dirPath] objectEnumerator];
	NSString *fileName = nil;


	// TODO: Optimize (NSDirectoryEnumerator seems a bit dumb or like a misuse 
	// in the following code).
	while ((fileName = [e nextObject]) != nil)
	{
		NSString *path = [dirPath appendPath: fileName];
		id object = nil;
		BOOL isDir = NO;

		//ETLog(@"Enumerate file %@", path);

		if ([FM fileExistsAtPath: path isDirectory: &isDir])
		{
			if (isDir)
			{
				object = [CODirectory objectWithURL: [NSURL fileURLWithPath: path]];
				//[e skipDescendents];
			}
			else
			{
				object = [COFile objectWithURL: [NSURL fileURLWithPath: path]];
			}
			[files addObject: object];
		}
		else
		{
			ETLog(@"WARNING: Enumerated a non-existent file at path %@", path);
		}
	}

	return files;
}

- (BOOL) isGroup
{
	return YES;
}

/** See -addMember:. */
- (BOOL) addGroup: (id <COGroup>)subgroup
{
	return [self addMember: subgroup];
}

/** See -removeMember:. */
- (BOOL) removeGroup: (id <COGroup>)subgroup
{
	return [self removeMember: subgroup];
}

// FIXME: Implement
- (NSArray *) groups
{
	return nil;
}

// FIXME: Implement
- (NSArray *) allObjects
{
	return nil;
}

// FIXME: Implement
- (NSArray *) allGroups
{
	return nil;
}

- (BOOL) isOpaque
{
	return NO;
}

- (BOOL) isOrdered
{
	return NO;
}

- (BOOL) isEmpty
{
	return ([[self members] count] == 0);
}

- (id) content
{
	return [self members];
}

- (NSArray *) contentArray
{
	return [self content];
}

- (void) insertObject: (id)object atIndex: (unsigned int)index
{
	[self addMember: object];
}

// FIXME: Shouldn't return a boolean.
- (BOOL) removeObject: (id) object
{
	return [self removeMember: object];
}

/* Deprecated (DO NOT USE, WILL BE REMOVED LATER) */

- (BOOL) addObject: (id) object { return [self addMember: object]; }
- (NSArray *) objects { return [self members]; }

@end

#if 0

- (BOOL) addObject: (id) object
{
	if ([self isValidObject: object])
		return NO;

	id parentDir = [CODirectory objectWithURL: [[object URL] parentURL]]
	BOOL result = NO;

#ifdef HARD_LINK_MUTATION
	/* Handles file move by creating a hard link at destination and removing the 
	   hard link at source */
	result = [self addHardLink: object];
	if (result)
	{
		[object willAddToGroup: self];
		result = [parentDir removeMember: object]; /* Delete the previous hard link */
	}
#else
	/* Handles file move with a normal move operation */
	result = [parentDir removeMember: object];
	if (result)
	{
		/* Eventually cancel any pending removal now that a group holds it */
		[object willAddToGroup: self];
		result = [self addMovedObject: object];
	}
#endif

	return result;
}

#endif

