/** 
   Copyright (C) 2005 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date:	October 2005
   
   This file is part of the Performance Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   $Date$ $Revision$
   */ 

#ifndef	INCLUDED_GSCache_H
#define	INCLUDED_GSCache_H

#import	<Foundation/NSObject.h>

@class	NSArray;
@class	NSDate;
@class	NSDate;
@class	NSMutableSet;
@class	NSString;

/**
 * The GSCache class is used to maintain a cache of objects in memory
 * for relatively rapid access.<br />
 * Typical usage might be to keep the results of a database query around
 * for a while in order to re-use them ... for instance when application
 * configuration is obtained from a database which might be updated while
 * the application is running.<br />
 * When the cache is full, old objects are removed to make room for new
 * ones on a least-recently-used basis.<br />
 * Cache sizes may be limited by the number of objects in the cache,
 * or by the memory used by the cache, or both.  Calculation of the
 * size of items in the cache is relatively expensive, so caches are
 * only limited by number of objects in the default case.<br />
 * Objects stored in the cache may be given a limited lifetime,
 * in which case an attempt to fetch an <em>expired</em> object
 * from the cache will cause it to be removed from the cache instead
 * (subject to control by the delegate).<br />
 * Cache keys may be objects of any type as long as they are copyable
 * (and the copied keys are immutable) and implement the -hash and
 * -isEqual: methods such that any two keys can be tested for equality
 *  and used as dictionary keys.<br />
 * NB.  GSCache currently does not support subclassing ... use it as is
 * or extend it via categories, but do not try to add instance variables.
 */
@interface	GSCache : NSObject
{
}

/**
 * Return all the current cache instances... useful if you want to do
 * something to all cache instances in your process.
 */
+ (NSArray*) allInstances;

/**
 * Return a report on all GSCache instances ... calls the [GSCache-description]
 * method of the individual cache instances to get a report on each one.
 */
+ (NSString*) description;

/**
 * Return the count of objects currently in the cache.
 */
- (unsigned) currentObjects;

/**
 * Return the total size of the objects currently in the cache.
 */
- (unsigned) currentSize;

/**
 * Return the delegate object previously set using the -setDelegate: method.
 */
- (id) delegate;

/**
 * Returns a string describing the status of the receiver for debug/reporting.
 */
- (NSString*) description;

/**
 * Return the default lifetime for items set in the cache.<br />
 * A value of zero means that items are not purged based on lifetime.
 */
- (unsigned) lifetime;

/**
 * Return the maximum number of items in the cache.<br />
 * A value of zero means there is no limit.
 */
- (unsigned) maxObjects;

/**
 * Return the maximum tital size of items in the cache.<br />
 * A value of zero means there is no limit.
 */
- (unsigned) maxSize;

/**
 * Return the name of this instance (as set using -setName:)
 */
- (NSString*) name;

/**
 * Return the cached value for the specified key, or nil if there
 * is no value in the cache.
 */
- (id) objectForKey: (id)aKey;

/**
 * Remove all items whose lifetimes have passed
 * (if lifetimes are in use for the cache).<br />
 */
- (void) purge;

/**
 * Sets the delegate for the receiver.<br />
 * The delegate object is not retained.<br />
 * If a delegate it set, it will be sent the messages in the
 * (GSCacheDelegate) protocol (if it implements them ... which
 * it does not need to do).
 */
- (void) setDelegate: (id)anObject;

/**
 * Sets the lifetime (seconds) for items added to the cache.  If this
 * is set to zero then items are not removed from the cache based on
 * lifetimes when the cache is full and an object is added, though
 * <em>expired</em> items are still removed when an attempt to retrieve
 * them is made.
 */
- (void) setLifetime: (unsigned)max;

/**
 * Sets the maximum number of objects in the cache.  If this is non-zero
 * then an attempt to set an object in a full cache will result in the
 * least recently used item in the cache being removed.
 */
- (void) setMaxObjects: (unsigned)max;

/**
 * Sets the maximum total size for objects in the cache.  If this is non-zero
 * then an attempt to set an object whose size would exceed the cache limit
 * will result in the least recently used items in the cache being removed.
 */
- (void) setMaxSize: (unsigned)max;

/**
 * Sets the name of this instance.
 */
- (void) setName: (NSString*)name;

/**
 * Sets (or replaces)the cached value for the specified key.<br />
 * The value of anObject may be nil to remove any cached object
 * for aKey.
 */
- (void) setObject: (id)anObject forKey: (id)aKey;

/**
 * Sets (or replaces)the cached value for the specified key, giving
 * the value the specified lifetime (in seconds).  A lifetime of zero
 * means that the item is not limited by lifetime.<br />
 * The value of anObject may be nil to remove any cached object
 * for aKey.
 */
- (void) setObject: (id)anObject
	    forKey: (id)aKey
	  lifetime: (unsigned)lifetime;

/**
 * Sets (or replaces)the cached value for the specified key, giving
 * the value the specified expiry date.  Calls -setObject:forKey:lifetime:
 * to do the real work ... this is just a convenience method to
 * handle working out the lifetime in seconds.<br />
 * If expires is nil or not in the future, this method simply removes the
 * cache entry for aKey.  If it is many years in the future, the item is
 * set in the cache so that it is not limited by lifetime.
 */
- (void) setObject: (id)anObject
	    forKey: (id)aKey
	     until: (NSDate*)expires;

/**
 * Called by -setObject:forKey:lifetime: to make space for a new
 * object in the cache (also when the cache is resized).<br />
 * This will, if a lifetime is set (see the -setLifetime: method)
 * first purge all <em>expired</em> objects from the cache, then
 * (if necessary) remove objects from the cache until the number
 * of objects and size of cache meet the limits specified.<br />
 * If the objects argument is zero then all objects are removed from
 * the cache.<br />
 * The size argument is used <em>only</em> if a maximum size is set
 * for the cache.
 */
- (void) shrinkObjects: (unsigned)objects andSize: (unsigned)size; 
@end

/**
 * This protocol defines the messages which may be sent to a delegate
 * of a GSCache object.  The messages are only sent if the delegate
 * actually implements them, so a delegate does not need to actually
 * conform to the protocol.
 */
@protocol	GSCacheDelegate

/**
 * Alerts the delegate to the fact that anObject, which was cached
 * using aKey and will expire delay seconds in the future has been
 * looked up now, and needs to be refreshed if it is not to expire
 * from the cache.<br />
 * This is called the first time an attempt is made to access the
 * cached value for aKey and the object is found in the cache but
 * more than half its lifetime has expired.<br />
 * The delegate method (if implemented) may replace the item in the
 * cache immediately, or do it later asynchronously, or may simply
 * take no action.
 */
- (void) mayRefreshItem: (id)anObject
		withKey: (id)aKey
	       lifetime: (unsigned)lifetime
		  after: (unsigned)delay;
/**
 * Asks the delegate to decide whether anObject, which was cached
 * using aKey and expired delay seconds ago should still be retained
 * in the cache.<br />
 * This is called when an attempt is made to access the cached value
 * for aKey and the object is found in the cache but it is no longer
 * valid (has expired).<br />
 * If the method returns YES, then anObject will not be removed as it
 * normally would.  This allows the delegate to change the cached item
 * or refresh it.<br />
 * For instance, the delegate could replace the object
 * in the cache before returning YES in order to update the cached value
 * when its lifetime has expired.<br />
 * Another possibility would be for the delegate to return YES (in order
 * to continue using the existing object) and queue an asynchronous
 * database query to update the cache later.  In this case the expiry
 * time of the item will be reset relative to the current time, based
 * upon its original lifetime.
 */
- (BOOL) shouldKeepItem: (id)anObject
		withKey: (id)aKey
	       lifetime: (unsigned)lifetime
		  after: (unsigned)delay;

@end

/**
 * <p>This category declares the -sizeInBytes: method which is used by
 * [GSCache] to ask objects for their size when adding them to a cache
 * which has a limited size in bytes.
 * </p>
 * <p>The [NSObject] implementation of this method is intended to
 * provide a rough estimnate of object size which subclasses may refine
 * in order to provide more accurate sizing information.<br />
 * Subclasses should call the superclass implementation and use the
 * resulting size information (if it is zero then the object is in the
 * exclude set and the subclass implementation should also return zero)
 * as a starting point on which to add the sizes of any objects contained.
 * </p>
 * For example:
 * <example>
 * - (unsigned) sizeInBytes: (NSMutableSet*)exclude
 * {
 *   unsigned size = [super sizeInBytes: exclude];
 *   if (size > 0)
 *     {
 *       size += [myInstanceVariable sizeInBytes: exclude];
 *     }
 *   return size;
 * }
 * </example>
 * <p>The performance library contains implementations giving reasonable size
 * estimates for several common classes:
 * </p>
 * <list>
 *   <item>NSArray</item>
 *   <item>NSData</item>
 *   <item>NSDictionary</item>
 *   <item>NSSet</item>
 *   <item>NSString</item>
 *   <item>GSMimeDocument (if built with the GNUstep base library)</item>
 * </list>
 * <p>The default ([NSObject]) implementation provides a reasonable size
 * for any class whose instance variables do not include other objects
 * or pointers to memory allocated on the heap.
 * </p>
 */
@interface	NSObject (GSCacheSizeInBytes)
/**
 * If the receiver is a member of the exclude set, this method simply
 * returns zero.  Otherwise, the receiver adds itsself to the exclude
 * set and returns its own size in bytes (the size of the memory used
 * to hold all the instance variables defined for the receiver's class
 * including all superclasses).
 */
- (unsigned) sizeInBytes: (NSMutableSet*)exclude;
@end

#endif

