/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "COFile.h"
#import "COObject.h"
#import "CODirectory.h"
#import "GNUstep.h"

#define FM [NSFileManager defaultManager]
#define FM_HANDLER [CODirectory delegate]
#define FSPATH(x) [[x URL] path]

@interface COFile (Private)
- (id) initWithURL: (NSURL *)url isCopyPromise: (BOOL)isCopy;
- (void) setURL: (NSURL *)url;
- (BOOL) setMetadatas: (NSDictionary *)metadatas;
@end


@implementation COFile

/** Creates a new file instance that points to url. 
	The URL must be a local filesystem URL that starts with file:// scheme, 
	otherwise an NSInvalidArgumentException will be raised.
	The URL is allowed to point to a non-existent file or directory. 
	An exception is raised if url is nil. */
+ (id) objectWithURL: (NSURL *)url
{
	return AUTORELEASE([[self alloc] initWithURL: url isCopyPromise: NO]);
}

/* Private method reserved to COFile/CODirectory
   All objects should be otherwise retrieved/instantiated by the mean of 
   +objectWithURL:. */
- (id) initWithURL: (NSURL *)url isCopyPromise: (BOOL)isCopy
{
	SUPERINIT;

	[self setURL: url];
	_isCopyPromise = isCopy;

	return self;
}

DEALLOC(DESTROY(_url))

/** Returns a new instance pointing to the same URL than the receiver but 
	declared as a copy promise. 
	If you add a copy promise to a CODirectory, the file pointed by the URL 
	will get copied inside the directory to which you send -addObject:. */
- (id) copyWithZone: (NSZone)zone
{
	return [[[self class] alloc] initWithURL: [self URL] isCopyPromise: YES];
}

- (NSString *) description
{
	NSString *desc = [super description];

	desc = [[desc append: @" "] append: FSPATH(self)];
	//return [[self properties] description];

	return desc;
}

/** Tests equality by considering the type and URLs of the receiver and object. */
- (BOOL) isEqual: (id)object
{
	BOOL isSameType = ([object isKindOfClass: [self class]] && ![object isGroup]);
	return (isSameType && [[self URL] isEqual: [object URL]]);
}

- (unsigned long) hash
{
	// TODO: May be return [[self UUID] hash]; when possible
	return [super hash];
}

/** Returns the local filesystem URL that was used to instantiate the receiver. 
	The URL may point to a non-existent file or directory. */
- (NSURL *) URL
{
	return AUTORELEASE([_url copy]);
}

- (void) setURL: (NSURL *)url
{
	if (url == nil)
	{
		[NSException raise: NSInvalidArgumentException format: @"URL must not "
			@"be nil for %@", self];
	}
	ASSIGN(_url, url);
}

- (NSArray *) properties
{
	return [super properties];
}

- (id) valueForProperty: (NSString *)key
{
	id value = [[self metadatas] objectForKey: key];
	
	if (value == nil)
		value = [super valueForKey: key];
	
	return value;
}

- (BOOL) setValue: (id)value forProperty: (NSString *)key
{
	BOOL result = [super setValue: value forProperty: key];

	if (result == NO)
		result = [self setMetadatas: D(value, key)];

	return result;
}

/** Returns the filesystem attributes of the receiver. */
- (NSDictionary *) metadatas
{
	NSMutableDictionary *metadatas = [NSMutableDictionary dictionary];

	// FIXME: Must include icon, name and displayName
	[metadatas addEntriesFromDictionary: 
		[FM fileAttributesAtPath: FSPATH(self) traverseLink: NO]];
	return metadatas;
}

/* Private method. Use -setValue:forProperty: to edit metadatas. */
- (BOOL) setMetadatas: (NSDictionary *)metadatas
{
	return [FM changeFileAttributes: metadatas atPath: FSPATH(self)];
}

/** Returns the name (the last path component) of the receiver. */
- (NSString *) name
{
	return [[self URL] lastPathComponent];
}

/** Returns the user-friendly name to be displayed for the receiver in UI. */
- (NSString *) displayName
{
	return [FM displayNameAtPath: FSPATH(self)];
}

/** Returns the icon bound to the receiver. */
- (NSImage *) icon
{
	// FIXME: Use IconKit instead of NSWorkspace
	return [[NSWorkspace sharedWorkspace] iconForFile: FSPATH(self)];
}

- (void) didRemoveFromGroup: (id)group
{

}

/** Adjusts the URL of the receiver and turns a copy promise into a normal 
	object usually once the copy has been handled by -[CODirectory addObject:].
	You must not call this method unless you write a COGroup conforming class. */
- (void) didAddToGroup: (id)group
{
	NSURL *destURL = [[group URL] appendPath: [FSPATH(self) lastPathComponent]];
	_isCopyPromise = NO;
	[self setURL: destURL];
}

/** Returns whether a file exists at the receiver URL. */
- (BOOL) exists
{
	return [FM fileExistsAtPath: FSPATH(self) isDirectory: NULL];
}

/** Creates a blank file if none exists at the receiver URL. */
- (BOOL) create
{
	return [FM createFileAtPath: FSPATH(self) contents: nil attributes: nil];
}

/** Deletes the file or the directory if its exists at the receiver URL. */
- (BOOL) delete
{
	return [FM removeFileAtPath: FSPATH(self) handler: FM_HANDLER];
}

/** Returns whether the receiver is a copy promise that is going to be copied 
	to another URL when added to a CODirectory instance. */
- (BOOL) isCopyPromise
{
	return _isCopyPromise;
}

@end

#if 0
/** Returns whether the receiver can be deleted at any points from now. If YES, 
	the represented file will be deleted when the receiver will be deallocated,
	otherwise the file on disk won't be touched. */
- (BOOL) isWaitingForDelete
{
	return _isRemoved;
}
#endif
