/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "COCollection.h"
#import "GNUstep.h"

NSString *collectionExtension = @"collection";
NSString *collectionStore = @"_collection.store"; /* For property list */

@implementation COCollection
/* Private */

/* Return NO if there is anything wrong */
- (BOOL) _removeEmptySubDirectory: (NSString *) path
{
	if ([path hasPrefix: [self location]] == NO)
	{
		NSLog(@"Internal Error: try to remove path outside collection - %@", path);
		return NO;
	}
	NSString *currentPath = path;
	while (1)
	{
		BOOL isDir = NO;
		if ([_fm fileExistsAtPath: currentPath isDirectory: &isDir])
		{
			if (isDir == NO)
			{
				NSLog(@"Internal Error: try to remove non-directory path %@", currentPath);
				return NO;
			}
			else
			{
				NSArray *contents = [_fm directoryContentsAtPath: currentPath];
				if (contents == nil)
				{
					NSLog(@"Internal Error: cannot get contents of directory %@", currentPath);
					return NO;
				}
				else if ([contents count] == 0)
				{
					if ([_fm removeFileAtPath: currentPath handler: nil] == NO)
					{
						NSLog(@"Internal Error: cannot remove directory %@", currentPath);
						return NO;
					}
				}
				else
				{
					/* Directory is not empty. Abort */
					break;
				}
			}
		}
		else
		{
			NSLog(@"Internal Error: try to remove non-existing path  %@", currentPath);
			return NO;
		}
		currentPath = [currentPath stringByDeletingLastPathComponent];
		if ([[self location] isEqualToString: currentPath])
		{
			break;
		}
	}
	return YES;
}

/* Return YES when directory is ready to use. Otherwise, NO */
- (BOOL) _checkAndCreateDirectory: (NSString *) path
{
	int i;
	NSString *currentPath;
	NSArray *array;

	array = [[path stringByExpandingTildeInPath] pathComponents];;
	currentPath = [array objectAtIndex: 0];

	for(i = 1; i < [array count]; i++)
	{
		BOOL dir, result;
      
		currentPath = [currentPath
			stringByAppendingPathComponent: [array objectAtIndex: i]];

		result = [_fm fileExistsAtPath: currentPath isDirectory: &dir];
		if((result == YES) && (dir == NO))
		{
			/* Path exist, but not a directory */
			return NO;
		}

		if(result == NO)
		{
			/* Path does not exist, create one */
			result = [_fm createDirectoryAtPath: currentPath attributes: nil];
		}

		if(result == NO)
		{
			/* Cannot create directory */
			return NO;
		}
	}

//	NSLog(@"Succesfully create dir %@", currentPath);
	return YES;
}

- (void) _receiveAddObjectNotification: (NSNotification *) not
{
//	NSLog(@"%@", NSStringFromSelector(_cmd));
	/* Check to see whether this is a parent */
	COFileObject *object = [[not userInfo] objectForKey: kCOGroupChild];
	if (object == nil)
	{
		NSLog(@"Internal Error: no object from kCOGroupAddObjectNotification");
		return;
	}
	if ([object isKindOfClass: [COFileObject class]] == NO)
	{
		/* Not a file object. Nothing to do */
		return;
	}
	if ([[object parentGroups] containsObject: self])
	{
		/* An object is added to this. */
		NSString *origPath = [object path];
		NSString *newPath = [[self location] stringByAppendingPathComponent: [self pathForFileObject: object]];
		if ([origPath isEqualToString: newPath])
		{
			/* Nothing to do */
			return;
		}
		else if ([origPath hasPrefix: [self location]])
		{
			/* The file is already in collection. Do nothing. */
			return;
		}
		else
		{
			/* The file is outside collection. Do copy */
//			NSLog(@"Copy from %@ to %@", origPath, newPath);
			NSString *dir = [newPath stringByDeletingLastPathComponent];
			if ([self _checkAndCreateDirectory: dir] == NO)
			{
				NSLog(@"Internal Error: Cannot create %@ to store files", dir);
				return;
			}
			if ([_fm copyPath: origPath toPath: newPath handler: nil])
			{
				[object setPath: newPath];
			}
		}
	}
}

- (void) _receiveRemoveObjectNotification: (NSNotification *) not
{
//	NSLog(@"%@", NSStringFromSelector(_cmd));
	/* Check to see whether this is a parent */
	COFileObject *object = [[not userInfo] objectForKey: kCOGroupChild];
	if (object == nil)
	{
		NSLog(@"Internal Error: no object from kCOGroupAddObjectNotification");
		return;
	}
	if ([object isKindOfClass: [COFileObject class]] == NO)
	{
		/* Not a file object. Nothing to do */
		return;
	}
	NSArray *parents = [object parentGroups];
	BOOL removeFile = NO;
	if ((parents == nil) || ([parents count] == 0))
	{
		/* This object is not under this collection. 
		   Remove its file if it is under this collection */
		removeFile = YES;
	}
	else if ([parents containsObject: self])
	{
		/* Object is still under this colleciton. Do nothing */
	}
	else
	{
		/* Object file is not under collection. 
		   Remove its file from collection if it is under this collection. */
		removeFile = YES;
	}
	if (removeFile)
	{
		NSString *p = [object path];
//		NSLog(@"Remove %@", p);
		if ([_fm removeFileAtPath: p handler: nil] == NO)
		{
			NSLog(@"Internal Error: Cannot remove %@", p);
		}
		else
		{
			/* Remove empty directory */
			[self _removeEmptySubDirectory: [p stringByDeletingLastPathComponent]];
			[object setPath: nil];
		}
	}
}

- (void) _receiveAddSubgroupNotification: (NSNotification *) not
{
//	NSLog(@"%@", NSStringFromSelector(_cmd));
}

- (void) _receiveRemoveSubgroupNotification: (NSNotification *) not
{
//	NSLog(@"%@", NSStringFromSelector(_cmd));
}

/* End of Private */

- (id) initWithLocation: (NSString *) path
{
	NSString *error = nil;
  	NSPropertyListFormat format = 0;
	ASSIGN(_location, [path stringByStandardizingPath]);
	/* Check extension */
	if ([[_location pathExtension] isEqualToString: collectionExtension] == NO)
	{
		NSLog(@"Error: not a collection at %@", _location);
		[self dealloc];
		return nil;
	}

	/* Check file existing */
	BOOL isDir = NO;
	_fm = [NSFileManager defaultManager];
	if ([_fm fileExistsAtPath: _location isDirectory: &isDir])
	{
		if (isDir == NO)
		{
			/* Path exist, but not a directory */
			NSLog(@"Error: not valid collection at %@", _location);
			[self dealloc];
			return nil;
		}
		else
		{
			/* Read the property list */
			NSString *p = [_location stringByAppendingPathComponent: collectionStore];
		  	NSData *data = [NSData dataWithContentsOfFile: p];
			if (data == nil)
			{
				NSLog(@"Error: Cannot get collection data at %@", p);
				/* We pretend to be empty collection */
			}
			else
			{
			  	id pl = [NSPropertyListSerialization propertyListFromData: data
	                               mutabilityOption: NSPropertyListImmutable
	                                         format: &format
	                               errorDescription: &error];
				if (pl == nil)
				{
					NSLog(@"Error: %@ (%@ %@)", error, self, NSStringFromSelector(_cmd));
					[self dealloc];
					return nil;
				}
				self = [self initWithPropertyList: pl];
			}
		}
	}
	else
	{
		/* Path does not exist, create one */
		if ([self _checkAndCreateDirectory: _location] == NO)
		{
			NSLog(@"Error: Cannot create directory at %@", _location);
			[self dealloc];
			return nil;
		}
		else
		{
			self = [self init];
		}
	}

	/* We start to listen after it is initialized */
	[_nc addObserver: self
	     selector: @selector(_receiveAddObjectNotification:)
	     name: kCOGroupAddObjectNotification
	     object: nil];
	[_nc addObserver: self
	     selector: @selector(_receiveRemoveObjectNotification:)
	     name: kCOGroupRemoveObjectNotification
	     object: nil];
	[_nc addObserver: self
	     selector: @selector(_receiveAddSubgroupNotification:)
	     name: kCOGroupAddSubgroupNotification
	     object: nil];
	[_nc addObserver: self
	     selector: @selector(_receiveRemoveSubgroupNotification:)
	     name: kCOGroupRemoveSubgroupNotification
	     object: nil];

	return self;
}

- (BOOL) save
{
	NSString *error = nil;
	id plist = [self propertyList];
	NSData *data = [NSPropertyListSerialization dataFromPropertyList: plist
	                                format: NSPropertyListXMLFormat_v1_0
	                                            errorDescription: &error];
	if (data == nil)
	{
		NSLog(@"Internal Error: Cannot save collection %@ (%@)", self, error);
		return NO;
	}

	/* Write to disk */
	NSString *p = [[self location] stringByAppendingPathComponent: collectionStore];
	return [data writeToFile: p atomically: YES];
}

- (NSString *) pathForFileObject: (COFileObject *) fileObject
{
	if ([fileObject isKindOfClass: [COFileObject class]])
	{
		/* Let's check the creation date */
		NSDate *date = [fileObject valueForProperty: kCOCreationDateProperty];
		NSString *p = [date descriptionWithCalendarFormat: @"%Y/%m/" timeZone: nil locale: nil];
		p = [p stringByAppendingPathComponent: [[fileObject path] lastPathComponent]];
		return p;
	}
	return nil;
}

- (void) setAutoOrganizingProperties: (NSArray *) properties
{
	ASSIGN(_autoProperties, properties);
}

- (NSArray *) autoOrganizingProperties: (NSArray *) properties
{
	return _autoProperties;
}

- (void) dealloc
{
	DESTROY(_location);
	[super dealloc];
}

- (NSString *) location;
{
	return _location;
}

/* Serialization (EtoileSerialize)
   TODO: this code is copied/pasted in COFileObject.m, figure out a way to 
   share it. */

- (BOOL) serialize: (char *)aVariable using: (ETSerializer *)aSerializer
{
	if ([super serialize: aVariable using: aSerializer])
		return YES;

	if (strcmp(aVariable, "_fm") == 0)
	{
		return YES; /* Should not be automatically serialized (manual) */
	}

	return NO; /* Serializer handles the ivar */
}

- (void) finishedDeserializing
{
	[super finishedDeserializing];
	_fm = [NSFileManager defaultManager];
}

@end

