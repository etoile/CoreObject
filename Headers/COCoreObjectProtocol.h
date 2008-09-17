/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

/* CoreObject Protocol (Objects) */

@protocol COObject <NSObject, NSCopying>
- (BOOL) isCopyPromise;
/** Returns the model properties of the receiver. 
	Properties should encompass all model attributes and relationships that you 
	want to publish. Your Property-Value Coding implementation will determine
	for each one whether they are readable, writable or both.*/
- (NSArray *) properties;
/** Returns the metadatas of the receiver to be indexed by the metadata server. 
	The set of metadatas may intersect or not the set of properties. */
- (NSDictionary *) metadatas;
/** Returns a unique ID that can be used to recreate a previously known object 
	by passing this value to -initWithUniqueID:.
	The choice of the unique ID scheme is up to the class that conforms to 
	COObject protocol. 
	A common choice is to return the absolute string form of the URL that 
	identifies the receiver object. 
	The FS backend  (COFile and CODirectory) uses a combination of the related 
	filesystem inode and device/volume identifier.
	The Native backend (COObject and COGroup) uses an UUID. */
- (NSString *) uniqueID;
//- (id) initWithUniqueID:
@end

/* Relationships between Objects */

@protocol COGroup <COObject, ETCollection, ETCollectionMutation>

+ (BOOL) isGroupAtURL: (NSURL *)anURL;
+ (id) objectWithURL: (NSURL *)anURL;

/** Must return YES to indicate the receiver is a group. */
- (BOOL) isGroup;

/** Adds an object to the receiver. 
    This method must call -addGroup: if anObject is a COGroup instance, or 
    eventually refuses it and only accepts group addition through -addGroup:. 
    Implementing this last behavior isn't advised though. */
- (BOOL) addObject: (id)anObject;
/** Removes an object from the receiver. 
    This method must call -removeGroup: if anObject is a COGroup instance, or 
    eventually refuses it and only accepts group removal through -removeGroup:. 
    Implementing this last behavior isn't advised though.  */
- (BOOL) removeObject: (id)anObject;
/** Returns objects directly owned by the receiver, that includes every objects 
    and subgroups which are immediate children.
    If you refuse addition and removal of groups in -addObject: and 
    -removeObject:, you must also exclude groups from the returned array. */
- (NSArray *) objects;

/** Adds a subgroup to the receiver.
	The class that implements this method must not call -addObject: directly.
	-addObject: and -addGroup should rather call a common private method like 
	_addObject: if they want to share their implementation.
	In many implementation cases, this method involves no other work than 
	-addObject:. However it is useful when you want to introduce some special 
	handling or semantic for the ownership of subgroups. For example, you could 
	tailor it for custom indexing, storing and caching of relationships or even 
	generate new groups for the insertion of the given subgroup. This last 
	option represents the possibility to compute or generate lazily new 
	relationships based on existing relationships between objects and other 
	conditions. */
- (BOOL) addGroup: (id <COGroup>)aGroup;
/** Removes a subgroup from the receiver. */
- (BOOL) removeGroup: (id <COGroup>)aGroup;
/** Returns subgroups directly owned by the receiver, that includes every groups 
	which are immediate children. */
- (NSArray *) groups;

/** Returns all objects belonging to this group, that includes immediate 
    children and other descendent children, recursively returned by -objects. 
    TODO: Add a depth limit, otherwise this method will often return the whole 
    CoreObject graph. */
- (NSArray *) allObjects;
/** Returns all subgroups belonging to this group, that includes immediate 
    children and other descendent children, recursively returned by 
    -valueForProperty: kCOGroupSubgroupsProperty.
    TODO: Add a depth limit, otherwise this method will often return all the 
    nodes that make up the goreObject graph.  */
- (NSArray *) allGroups;

/** Returns YES when the receiver should be handled and displayed as a COObject 
	instance rather than a COGroup instance. For example, a source file may
	appear as an opaque element in a file manager but as a group of classes, 
	functions, methods and variables in an IDE.
	Each application is in charge of interpreting or ignoring -isOpaque value 
	as it wants within the code that implements the browsing of core object 
	graphs. */
- (BOOL) isOpaque;
@end
