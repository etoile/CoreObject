/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#ifdef ICONKIT
#import <IconKit/IconKit.h>
#endif
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
- (void) recacheMetadatas;
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

/* Private method reserved to COFile/CODirectory.
   All objects should be otherwise retrieved/instantiated by the mean of 
   +objectWithURL:. */
- (id) initWithURL: (NSURL *)url isCopyPromise: (BOOL)isCopy
{
	SUPERINIT;

	/* Must precede -setURL: which triggers a recache.
	   See also -recacheMetadatas for the capacity choice. */
	ASSIGN(_cachedMetadatas, [NSMutableDictionary dictionaryWithCapacity: 35]);
	[self setURL: url];
	_isCopyPromise = isCopy;

	return self;
}

- (void) dealloc
{
	DESTROY(_url);
	DESTROY(_cachedMetadatas);
	[super dealloc];
}

/** Returns a new instance pointing to the same URL than the receiver but 
declared as a copy promise. 
	
If you add a copy promise to a CODirectory, the file pointed by the URL will 
get copied inside the directory to which you send -addMember:. */
- (id) copyWithZone: (NSZone *)zone
{
	return [[[self class] alloc] initWithURL: [self URL] isCopyPromise: YES];
}

- (NSString *) description
{
	NSString *desc = [super description];
	desc = [[desc stringByAppendingString: @" "] stringByAppendingString: FSPATH(self)];
	return desc;
}

/** Tests equality by considering the type and URLs of the receiver and object. */
- (BOOL) isEqual: (id)object
{
	BOOL isSameType = ([object isKindOfClass: [self class]] && ![object isGroup]);
	return (isSameType && [[self URL] isEqual: [object URL]]);
}

- (unsigned int) hash
{
	// TODO: May be return [[self UUID] hash]; when possible
	return [super hash];
}

/** Returns a unique identifier specific to the FS backend that allows to 
recreate a file object with the same identity than the receiver at a later 
point. In the other words, the new object will reference the same file than the 
receiver.

TODO: Presently, moving a file breaks the ability to recreate a file object 
pointing to it with a previously obtained unique ID. We should return a 
combination of inode + volume/device identifier to better keep track of file 
objects, rather than simply relying on a dumb URL. */
- (NSString *) uniqueID
{
	return [[self URL] absoluteString];
}

/** Returns the local filesystem URL that was used to instantiate the receiver. 

The URL may point to a non-existent file or directory. */
- (NSURL *) URL
{
	return _url;
}

- (void) setURL: (NSURL *)url
{
	if (url == nil)
	{
		[NSException raise: NSInvalidArgumentException format: @"URL must not "
			@"be nil for %@", self];
	}
	if ([url isFileURL] == NO)
	{
		[NSException raise: NSInvalidArgumentException format: @"URL %@ must "
			@"be a file URL for %@", url, self];
	}
	ASSIGN(_url, url);
	[self recacheMetadatas];	
}

/* PVC */

// TODO: Optimize, probably horribly slow. Also not sure we got to expose NSObject 
// properties by default
- (NSArray *) properties
{
	NSArray *properties = [[self metadatas] allKeys];

	properties = [properties arrayByAddingObjectsFromArray: [super properties]];
	/* icon, name, displayName and URL are declared in metadatas */
	properties = [properties arrayByAddingObjectsFromArray: 
		A(@"isCopyPromise", @"exists", @"metadatas", @"uniqueID")];

	return properties;
}

- (id) valueForProperty: (NSString *)key
{
	NSDictionary *metadatas = [self metadatas];
	id value = nil;

	/* The preliminary check for key in metadatas ensures a nil value won't be 
	   replaced by another value if an identically named property is declared by
	   NSObject. */
	if ([[metadatas allKeys] containsObject: key])
	{
		value = [metadatas objectForKey: key];
	}
	else
	{
		value = [super valueForProperty: key];
	}
	//ETLog(@"Found value %@ for %@ in %@", value, key, self);
	
	return value;
}

- (BOOL) setValue: (id)value forProperty: (NSString *)key
{
	BOOL result = [super setValue: value forProperty: key];

	if (result == NO)
		result = [self setMetadatas: D(value, key)];

	return result;
}

/* KVC */

/** Returns a metadata value if possible for the given key, otherwise returns 
the same than -[NSObject valueForKey:]. 

See also -isValidMetadataKey:. */
- (id) valueForKey: (NSString *)key
{
	NSDictionary *metadatas = [self metadatas];
	id value = nil;

	/* The preliminary check for key in metadatas ensures a nil value won't be 
	   replaced by another value if an identically named property is declared by
	   NSObject. */
	if ([self isValidMetadataKey: key])
	{
		value = [metadatas objectForKey: key];
	}
	else
	{
		value = [super valueForKey: key];
	}

	return value;
}

/** Sets a metadata value if possible for the given key, otherwise does the 
same than -[NSObject setValue:forKey:]. 

See also -isValidMetadataKey:. */
- (void) setValue: (id)value forKey: (NSString *)key
{
	if ([self isValidMetadataKey: key])
	{
		[self setMetadatas: D(value, key)];
	}
	else
	{
		[self setValue: value forKey: key];
	}
}

/** Returns whether a particular metadata is supported by the receiver. */
- (BOOL) isValidMetadataKey: (NSString *)key
{
	return [[[self metadatas] allKeys] containsObject: key];
}

- (void) recacheMetadatas
{
	ETAssert(nil != _cachedMetadatas);
	[_cachedMetadatas removeAllObjects];

	[_cachedMetadatas setObject: [self icon] forKey: @"icon"];
	[_cachedMetadatas setObject: [self name] forKey: @"name"];
	[_cachedMetadatas setObject: [self displayName] forKey: @"displayName"];
	[_cachedMetadatas setObject: [self URL] forKey: @"URL"];

	NSDictionary *attributes = [FM fileAttributesAtPath: FSPATH(self) traverseLink: NO];
	BOOL fileNotFound = (nil == attributes);
	if (fileNotFound)
	{
		return;
	}

	[_cachedMetadatas addEntriesFromDictionary: attributes]; // ~28 entries

	ETAssert([_cachedMetadatas count] > 4);

	[_cachedMetadatas setObject: [attributes fileModificationDate] 
	              forKey: kCOModificationDateProperty];
	[_cachedMetadatas setObject: [attributes fileCreationDate]
	              forKey: kCOCreationDateProperty];
	[_cachedMetadatas setObject: [attributes objectForKey: NSFileSize]
	              forKey: kCOSizeProperty];
	[_cachedMetadatas setObject: [attributes fileType]
	              forKey: kCOTypeNameProperty];
}

/** Returns the filesystem attributes of the receiver. */
- (NSDictionary *) metadatas
{
	ETAssert(nil != _cachedMetadatas);
	return _cachedMetadatas;
}

/* Private method. Use -setValue:forProperty: to edit metadatas. */
- (BOOL) setMetadatas: (NSDictionary *)metadatas
{
	BOOL result = [FM changeFileAttributes: metadatas atPath: FSPATH(self)];
	[self recacheMetadatas];
	return result;
}

/** Returns the name (the last path component) of the receiver. */
- (NSString *) name
{
	return [[self URL] lastPathComponent];
}

/** Renames the receiver with the given name.

If the file exits, it is renamed, otherwise only the URL is updated. */
- (void) setName: (NSString *)aName
{
	// TODO: Not safe enough... e.g. ' ', '/ ' or '//'
	if ([FSPATH(self) isEqual: @"/"])
		return;

	NSURL *url = [[[self URL] parentURL] URLByAppendingPath: aName];

	if ([self exists])
	{
		[FM movePath: FSPATH(self) toPath: [url path] handler: FM_HANDLER];
	}
	[self setURL: url];
}

/** Returns the user-friendly name to be displayed for the receiver in UI. */
- (NSString *) displayName
{
	return [FM displayNameAtPath: FSPATH(self)];
}

/** Sets the name of the receiver.<br />
If needed, the given name is converted back to its true representation by 
restoring what was lost in the name to display name conversion. 
e.g. the file name localization or extension.

See also -setName:. */
- (void) setDisplayName: (NSString *)aName
{
	[self setName: aName];
}

/** Returns the icon bound to the receiver. */
- (NSImage *) icon
{
	// TODO: Not enabled for now; we shoudn't depend on either AppKit or IconKit 
	// in the FS backend, hence the code probably needs to load IconKit as a 
	// bundle by checking whether the current process is linked to AppKit or not.
	// Move -icon a COFile category in EtoileUI.
#ifdef ICONKIT
	return [[IKIcon iconForURL: [self URL]] image];
#else
	return [[NSWorkspace sharedWorkspace] iconForFile: FSPATH(self)];
#endif
}

- (void) didRemoveFromGroup: (id)group
{

}

/** Adjusts the URL of the receiver and turns a copy promise into a normal 
object usually once the copy has been handled by -[CODirectory addMember:].

You must not call this method unless you write a COGroup conforming class. */
- (void) didAddToGroup: (id)group
{
	NSURL *destURL = [[group URL] URLByAppendingPath: [FSPATH(self) lastPathComponent]];
	_isCopyPromise = NO;
	[self setURL: destURL];
}

/** Returns whether a file exists at the receiver URL. */
- (BOOL) exists
{
	BOOL isDir = NO;
	BOOL exists = [FM fileExistsAtPath: FSPATH(self) isDirectory: &isDir];
	return (exists && isDir == NO);
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

/* Query */

- (BOOL) matchesPredicate: (NSPredicate *)aPredicate
{
	// TODO: Implement
	return NO;
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
