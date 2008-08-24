/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "CODeserializer.h"
#import "COSerializer.h"
#import "NSObject+CoreObject.h"
#import "COObject.h"

/* CoreObject Deserializer */

/* The default CoreObject Deserializer, in future storage specific code could be 
   extracted in a subclass called COFSDeserializer. It would make possible to 
   write a deserializer like COZFSDeserializer. */
@implementation ETDeserializer (CODeserializer)

+ (id) defaultCoreObjectDeserializer
{
	return [self defaultCoreObjectDeserializerWithURL: 
		[ETSerializer defaultLibraryURL]];
}

+ (id) defaultCoreObjectDeserializerWithURL: (NSURL *)aURL
{
	return [[ETSerializer defaultCoreObjectSerializerWithURL: aURL] deserializer];
}

+ (id) deserializeObjectWithURL: (NSURL *)aURL
{
	// FIXME: Move this quick-and-dirty check of the URL parameter into 
	// EtoileSerialize once the initialization code of the serialization 
	// backends is improved. We should also check that the directory is an 
	/// object bundle (put this in ETSerialObjectBundle).
	if ([aURL isFileURL] == NO 
	 || [FM fileExistsAtPath: [aURL path] isDirectory: NULL] == NO)
	{
		return nil;
	}

	// NOTE: By reading ETSerializerTest.m example, no local autorelease pool 
	// seems to be necessary for deserialization. 
	//CREATE_AUTORELEASE_POOL(pool);

	id deserializer = [self defaultCoreObjectDeserializerWithURL: aURL];
	[deserializer setBranch: @"root"];
	[deserializer setVersion: 0];
	id newInstance = [deserializer restoreObjectGraph];

	//DESTROY(pool);

	return newInstance;
}

/**
 * Find the address of an named instance variable for an object.  This searches
 * through the list of instance variables in the class structure's ivars field.
 * Since this is a simple array, this search completes in O(n) time.  This can
 * not be improved upon without maintaining an external map of names to
 * instance variables.
 */
inline static void * addressForIVarName(id anObject, char * aName, int hint)
{
	//Find a real iVar
	Class class = anObject->class_pointer;
	while(class != Nil && class != class->super_class)
	{
		struct objc_ivar_list* ivarlist = class->ivars;
		if(ivarlist != NULL) 
		{
			for(int i=0 ; i<ivarlist->ivar_count ; i++)
			{
				char * name = (char*)ivarlist->ivar_list[i].ivar_name;
				if(strcmp(aName, name) == 0)
				{
					return ((char*)anObject + (ivarlist->ivar_list[i].ivar_offset));
				}
			}
		}
		//If the instance variable is not from this class, check the superclass.
		class = class->super_class;
	}
	return NULL;
}

/** Handle the deserialization of the core object identified by anUUID. */
- (void) loadUUID: (char *)aUUID withName: (char *)aName
{
	ETDebugLog(@"Load CoreObject %s to name %s", aUUID, aName);

	ETUUID *uuid = [[ETUUID alloc] initWithUUID: (unsigned char *)aUUID];
	id otherManagedObject = nil;

	// TODO: Uses the object server here to locate the object anywhere on disk 
	// and requests insertion of the deserialized object into the current object 
	// context if no other object contexts already own it. 
	// Modify once we have proper library support and see also 
	// -[COSerializer serializationURLForObject:]
#if 1
	NSURL *url = [[ETSerializer defaultLibraryURL] URLByAppendingPath: [uuid stringValue]];

	otherManagedObject = [ETDeserializer deserializeObjectWithURL: url];
#else
	/* The object server takes care of the translation of the UUID into an URL
	   with the help of the metadata server, deserializes it and caches it. */
	//otherManagedObject = [[COObjectServer defaultServer] objectForUUID: uuid
	//	ifNewInsertIntoObjectContext: [object objectContext]];
#endif

	if(![object deserialize:aName fromPointer:aUUID version:classVersion])
	{
		ETDebugLog(@"Set managed object %@ with uuid %s at name %s", 
			otherManagedObject, aUUID, aName);
		// FIXME: We doesn't handle uuids in nested types for now. Will be fixed 
		// by moving this code back into EtoileSerialize and using OFFSET_OF_IVAR
		// rather than just addressForIVarName
		//char *address = OFFSET_OF_IVAR(object, aName, loadedIVar++, sizeof(id));
		loadedIVar++;
		char *address = addressForIVarName(object, aName, 0);
		if(address != NULL)
		{
			*(id *)address = otherManagedObject;
		}
		else
		{
			*(id*)address = nil;
		}
	}
}

@end
