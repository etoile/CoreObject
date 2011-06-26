/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

/** @group UUID

An implementation of the <uref url="http://en.wikipedia.org/wiki/Universally_unique_identifier">
Universally Unique Identifier</uref> standard. 

When an ETUUID is instantiated, the underlying UUID is generated with the 
version 4 (aka random) generation scheme.<br /> 
Take note the random scheme used on Linux and BSD platforms is based on a 
strong random number, unlike other platforms where a simpler random scheme is 
used. Which means collisions can occur on these platforms if you try to 
generate ETUUID in a tight loop.

You can use -isEqual: to check the equality between two ETUUID instances.

ETUUID does not have a designated initializer. */
@interface ETUUID : NSObject <NSCopying>
{
	@private
	unsigned char uuid[16];
}

/** @taskunit Initialization */

/**
 * Returns a new autoreleased UUID object initialized with a random 128-bit 
 * binary value.
 */
+ (id) UUID;
/**
 * Returns an autoreleased UUID object for the given UUID string representation. 
 */
+ (id) UUIDWithString: (NSString *)aString;

/**
 * Initializes the UUID object with a 128-bit binary value.
 */
- (id) initWithUUID: (const unsigned char *)aUUID;
/**
 * Initializes the UUID object from a string representation.
 */
- (id) initWithString: (NSString *)aString;
/** 
 * Initializes a UUID object by generating a random 128-bit binary value. 
 */
- (id) init;

/** @taskunit Alternative Representations */

/** 
 * Returns a string representation of the receiver.
 */
- (NSString *) stringValue;
/**
 * Returns a 128-bit binary value representation of the receiver.
 */
- (const unsigned char *) UUIDValue;

@end

#define ETUUIDSize (36 * sizeof(char))

/** @group UUID

UUID related additions to NSString. */
@interface NSString (ETUUID)
/**
 * Returns an autoreleased UUID string representation (see ETUUID).
 */
+ (NSString *) UUIDString;
@end

/** @group UUID

Conveniency methods to easily read and write UUIDs in the default database. */
@interface NSUserDefaults (ETUUID)
/**
 * Returns an autoreleased UUID object if the value for aKey is an UUID string 
 * representation, otherwise returns nil.
 * Also returns nil if aKey doesn't exist.
 */
- (ETUUID *) UUIDForKey: (NSString *)aKey;
/**
 * Sets the value as the string representation of aUUID for aKey.
 */
- (void) setUUID: (ETUUID *)aUUID forKey: (NSString *)aKey;
@end
