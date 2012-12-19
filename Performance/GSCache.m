/* -*-objc-*- */

/** Implementation of GSCache for GNUStep
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

#import	<Foundation/NSArray.h>
#import	<Foundation/NSAutoreleasePool.h>
#import	<Foundation/NSData.h>
#import	<Foundation/NSDate.h>
#import	<Foundation/NSDebug.h>
#import	<Foundation/NSDictionary.h>
#import	<Foundation/NSEnumerator.h>
#import	<Foundation/NSException.h>
#import	<Foundation/NSHashTable.h>
#import	<Foundation/NSLock.h>
#import	<Foundation/NSMapTable.h>
#import	<Foundation/NSNotification.h>
#import	<Foundation/NSSet.h>
#import	<Foundation/NSString.h>
#import	<Foundation/NSThread.h>
#import	<Foundation/NSValue.h>

#import	"GSCache.h"
#import	"GSTicker.h"

#if !defined(GNUSTEP)
#include <objc/objc-class.h>
#if (MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4)
#define class_getInstanceSize(isa)  ((struct objc_class *)isa)->instance_size
#endif
#endif

@interface	GSCache (Threading)
+ (void) _becomeThreaded: (NSNotification*)n;
- (void) _createLock;
@end

@interface	GSCacheItem : NSObject
{
@public
  GSCacheItem	*next;
  GSCacheItem	*prev;
  unsigned	life;
  unsigned	warn;
  unsigned	when;
  unsigned	size;
  id	        key;
  id		object;
}
+ (GSCacheItem*) newWithObject: (id)anObject forKey: (id)aKey;
@end

@implementation	GSCacheItem
+ (GSCacheItem*) newWithObject: (id)anObject forKey: (id)aKey
{
  GSCacheItem	*i;

  i = (GSCacheItem*)NSAllocateObject(self, 0, NSDefaultMallocZone());
  i->object = [anObject retain];
  i->key = [aKey copy];
  return i;
}
- (void) dealloc
{
  [key release];
  [object release];
  [super dealloc];
}
@end


@implementation	GSCache

static NSHashTable		*allCaches = 0;
static NSRecursiveLock	*allCachesLock = nil;
static int		itemOffset = 0;

typedef struct {
  id		delegate;
  void		(*refresh)(id, SEL, id, id, unsigned, unsigned);
  BOOL		(*replace)(id, SEL, id, id, unsigned, unsigned);
  unsigned	currentObjects;
  unsigned	currentSize;
  unsigned	lifetime;
  unsigned	maxObjects;
  unsigned	maxSize;
  unsigned	hits;
  unsigned	misses;
  NSMapTable	*contents;
  GSCacheItem	*first;
  NSString	*name;
  NSMutableSet	*exclude;
  NSRecursiveLock	*lock;
} Item;
#define	my	((Item*)((void*)self + itemOffset))

/*
 * Add item to linked list starting at *first
 */
static void appendItem(GSCacheItem *item, GSCacheItem **first)
{
  if (*first == nil)
    {
      item->next = item->prev = item;
      *first = item;
    }
  else
    {
      (*first)->prev->next = item;
      item->prev = (*first)->prev;
      (*first)->prev = item;
      item->next = *first;
    }
}

/*
 * Remove item from linked list starting at *first
 */
static void removeItem(GSCacheItem *item, GSCacheItem **first)
{
  if (*first == item)
    {
      if (item->next == item)
	{
	  *first = nil; 
	}
      else
	{
	  *first = item->next;
	}
    }
  item->next->prev = item->prev;
  item->prev->next = item->next;
  item->prev = item->next = item;
}

+ (NSArray*) allInstances
{
  NSArray	*a;

  [allCachesLock lock];
  a = NSAllHashTableObjects(allCaches);
  [allCachesLock unlock];
  return a;
}

+ (id) alloc
{
  return [self allocWithZone: NSDefaultMallocZone()];
}

+ (id) allocWithZone: (NSZone*)z
{
  GSCache	*c;

  c = (GSCache*)NSAllocateObject(self, sizeof(Item), z);
  return c;
}

+ (NSString*) description
{
  NSMutableString	*ms;
  NSHashEnumerator	e;
  GSCache		*c;

  ms = [NSMutableString stringWithString: [super description]];
  [allCachesLock lock];
  e = NSEnumerateHashTable(allCaches);
  while ((c = (GSCache*)NSNextHashEnumeratorItem(&e)) != nil)
    {
      [ms appendFormat: @"\n%@", [c description]];
    }
  NSEndHashTableEnumeration(&e);
  [allCachesLock unlock];
  return ms;
}

+ (void) initialize
{
  if (allCaches == 0)
    {
      itemOffset = class_getInstanceSize(self);
      allCaches
	= NSCreateHashTable(NSNonRetainedObjectHashCallBacks, 0);
      if ([NSThread isMultiThreaded] == YES)
	{
	  [self _becomeThreaded: nil];
	}
      else
	{
	  /* If and when we become multi-threaded, the +_becomeThreaded:
	   * method will remove us as an observer and will create a lock
	   * for the table of all caches, then ask each cache to create
	   * its own lock.
	   */
	  [[NSNotificationCenter defaultCenter]
	    addObserver: self
	    selector: @selector(_becomeThreaded:)
	    name: NSWillBecomeMultiThreadedNotification
	    object: nil];
	}
      GSTickerTimeNow();
    }
}

- (unsigned) currentObjects
{
  return my->currentObjects;
}

- (unsigned) currentSize
{
  return my->currentSize;
}

- (void) dealloc
{
  [allCachesLock lock];
  NSHashRemove(allCaches, (void*)self);
  [allCachesLock unlock];
  if (my->contents != 0)
    {
      [self shrinkObjects: 0 andSize: 0];
      NSFreeMapTable(my->contents);
    }
  [my->exclude release];
  [my->name release];
  [my->lock release];
  [super dealloc];
}

- (id) delegate
{
  return my->delegate;
}

- (NSString*) description
{
  NSString	*n;

  [my->lock lock];
  n = my->name;
  if (n == nil)
    {
      n = [super description];
    }
  n = [NSString stringWithFormat:
    @"  %@\n"
    @"    Items: %u(%u)\n"
    @"    Size:  %u(%u)\n"
    @"    Life:  %u\n"
    @"    Hit:   %u\n"
    @"    Miss: %u\n",
    n,
    my->currentObjects, my->maxObjects,
    my->currentSize, my->maxSize,
    my->lifetime,
    my->hits,
    my->misses];
  [my->lock unlock];
  return n;
}

- (id) init
{
  if (nil != (self = [super init]))
    {
      if ([NSThread isMultiThreaded] == YES)
	{
	  [self _createLock];
	}
      my->contents = NSCreateMapTable(NSObjectMapKeyCallBacks,
	NSObjectMapValueCallBacks, 0);
      [allCachesLock lock];
      NSHashInsert(allCaches, (void*)self);
      [allCachesLock unlock];
    }
  return self;
}

- (unsigned) lifetime
{
  return my->lifetime;
}

- (unsigned) maxObjects
{
  return my->maxObjects;
}

- (unsigned) maxSize
{
  return my->maxSize;
}

- (NSString*) name
{
  NSString	*n;

  [my->lock lock];
  n = [my->name retain];
  [my->lock unlock];
  return [n autorelease];
}

- (id) objectForKey: (id)aKey
{
  id		object;
  GSCacheItem	*item;
  unsigned	when = GSTickerTimeTick();

  [my->lock lock];
  item = (GSCacheItem*)NSMapGet(my->contents, aKey);
  if (item == nil)
    {
      my->misses++;
      [my->lock unlock];
      return nil;
    }
  if (item->when > 0 && item->when < when)
    {
      BOOL	keep = NO;

      if (0 != my->replace)
	{
	  GSCacheItem	*orig = [item retain];

	  [my->lock unlock];
	  NS_DURING
	    {
	      keep = (*(my->replace))(my->delegate,
		@selector(shouldKeepItem:withKey:lifetime:after:),
		item->object,
		aKey,
		item->life,
		when - item->when);
	    }
	  NS_HANDLER
	    {
	      [my->lock unlock];
	      [localException raise];
	    }
	  NS_ENDHANDLER
	  [my->lock lock];
	  if (keep == YES)
	    {
	      GSCacheItem	*current;

	      /* Refetch in case delegate changed it.
	       */
	      current = (GSCacheItem*)NSMapGet(my->contents, aKey);
	      if (current == nil)
		{
		  /* Delegate must have deleted the item even though
		   * it returned YES to say we should keep it ...
		   * we count this as a miss.
		   */
		  my->misses++;
		  [my->lock unlock];
		  [orig release];
		  return nil;
		}
	      else if (orig == current)
		{
		  /* Delegate told us to keep the original item so we
		   * update its expiry time.
		   */
		  item->when = when + item->life;
		  item->warn = when + item->life / 2;
		}
	      else
		{
		  /* Delegate replaced the item with another and told
		   * us to keep that one.
		   */
		  item = current;
		}
	    }
	  [orig release];
	}

      if (keep == NO)
	{
	  removeItem(item, &my->first);
	  my->currentObjects--;
	  if (my->maxSize > 0)
	    {
	      my->currentSize -= item->size;
	    }
	  NSMapRemove(my->contents, (void*)item->key);
	  my->misses++;
	  [my->lock unlock];
	  return nil;	// Lifetime expired.
	}
    }
  else if (item->warn > 0 && item->warn < when)
    {
      item->warn = 0;	// Don't warn again.
      if (0 != my->refresh)
	{
	  GSCacheItem	*orig = [item retain];
	  GSCacheItem	*current;

	  [my->lock unlock];
	  NS_DURING
	    {
	      (*(my->refresh))(my->delegate,
		@selector(mayRefreshItem:withKey:lifetime:after:),
		item->object,
		aKey,
		item->life,
		when - item->when);
	    }
	  NS_HANDLER
	    {
	      [my->lock unlock];
	      [localException raise];
	    }
	  NS_ENDHANDLER
	  [my->lock lock];

	  /* Refetch in case delegate changed it.
	   */
	  current = (GSCacheItem*)NSMapGet(my->contents, aKey);
	  if (current == nil)
	    {
	      /* Delegate must have deleted the item!
	       * So we count this as a miss.
	       */
	      my->misses++;
	      [my->lock unlock];
	      [orig release];
	      return nil;
	    }
	  else
	    {
	      item = current;
	    }
	  [orig release];
	}
    }

  // Least recently used ... move to end of list.
  removeItem(item, &my->first);
  appendItem(item, &my->first);
  my->hits++;
  object = [item->object retain];
  [my->lock unlock];
  return [object autorelease];
}

- (void) purge
{
  if (my->contents != 0)
    {
      unsigned		when = GSTickerTimeTick();
      NSMapEnumerator	e;
      GSCacheItem	*i;
      id		k;

      [my->lock lock];
      e = NSEnumerateMapTable(my->contents);
      while (NSNextMapEnumeratorPair(&e, (void**)&k, (void**)&i) != 0)
	{
	  if (i->when > 0 && i->when < when)
	    {
	      removeItem(i, &my->first);
	      my->currentObjects--;
	      if (my->maxSize > 0)
		{
		  my->currentSize -= i->size;
		}
	      NSMapRemove(my->contents, (void*)i->key);
	    }
	}
      NSEndMapTableEnumeration(&e);
      [my->lock unlock];
    }
}

- (oneway void) release
{
  /* We lock the table while checking, to prevent
   * another thread from grabbing this object while we are
   * checking it.
   * If we are going to deallocate the object, we first remove
   * it from the table so that no other thread will find it
   * and try to use it while it is being deallocated.
   */
  [allCachesLock lock];
  if (NSDecrementExtraRefCountWasZero(self))
    {
      NSHashRemove(allCaches, (void*)self);
      [allCachesLock unlock];
      [self dealloc];
    }
  else
    {
      [allCachesLock unlock];
    }
}

- (void) setDelegate: (id)anObject
{
  [my->lock lock];
  my->delegate = anObject;
  if ([my->delegate respondsToSelector:
    @selector(shouldKeepItem:withKey:lifetime:after:)])
    {
      my->replace = (BOOL (*)(id,SEL,id,id,unsigned,unsigned))
	[my->delegate methodForSelector:
	@selector(shouldKeepItem:withKey:lifetime:after:)];
    }
  else
    {
      my->replace = 0;
    }
  if ([my->delegate respondsToSelector:
    @selector(mayRefreshItem:withKey:lifetime:after:)])
    {
      my->refresh = (void (*)(id,SEL,id,id,unsigned,unsigned))
	[my->delegate methodForSelector:
	@selector(mayRefreshItem:withKey:lifetime:after:)];
    }
  else
    {
      my->refresh = 0;
    }
  [my->lock unlock];
}

- (void) setLifetime: (unsigned)max
{
  my->lifetime = max;
}

- (void) setMaxObjects: (unsigned)max
{
  [my->lock lock];
  my->maxObjects = max;
  if (my->currentObjects > my->maxObjects)
    {
      [self shrinkObjects: my->maxObjects
		  andSize: my->maxSize];
    }
  [my->lock unlock];
}

- (void) setMaxSize: (unsigned)max
{
  [my->lock lock];
  if (max > 0 && my->maxSize == 0)
    {
      NSMapEnumerator	e = NSEnumerateMapTable(my->contents);
      GSCacheItem	*i;
      id		k;
      unsigned		size = 0;

      if (my->exclude == nil)
	{
	  my->exclude = [NSMutableSet new];
	}
      while (NSNextMapEnumeratorPair(&e, (void**)&k, (void**)&i) != 0)
	{
	  if (i->size == 0)
	    {
	      [my->exclude removeAllObjects];
	      i->size = [i->object sizeInBytes: my->exclude];
	    }
	  if (i->size > max)
	    {
	      /*
	       * Item in cache is too big for new size limit ...
	       * Remove it.
	       */
	      removeItem(i, &my->first);
	      NSMapRemove(my->contents, (void*)i->key);
	      my->currentObjects--;
	      continue;
	    }
	  size += i->size;
	}
      NSEndMapTableEnumeration(&e);
      my->currentSize = size;
    }
  else if (max == 0)
    {
      my->currentSize = 0;
    }
  my->maxSize = max;
  if (my->currentSize > my->maxSize)
    {
      [self shrinkObjects: my->maxObjects
		  andSize: my->maxSize];
    }
  [my->lock unlock];
}

- (void) setName: (NSString*)name
{
  [my->lock lock];
  [name retain];
  [my->name release];
  my->name = name;
  [my->lock unlock];
}

- (void) setObject: (id)anObject forKey: (id)aKey
{
  [self setObject: anObject forKey: aKey lifetime: my->lifetime];
}

- (void) setObject: (id)anObject
	    forKey: (id)aKey
	  lifetime: (unsigned)lifetime
{
  GSCacheItem	*item;
  unsigned	maxObjects;
  unsigned	maxSize;
  unsigned	addObjects = (anObject == nil ? 0 : 1);
  unsigned	addSize = 0;

  [my->lock lock];
  maxObjects = my->maxObjects;
  maxSize = my->maxSize;
  item = (GSCacheItem*)NSMapGet(my->contents, aKey);
  if (item != nil)
    {
      removeItem(item, &my->first);
      my->currentObjects--;
      if (my->maxSize > 0)
	{
	  my->currentSize -= item->size;
	}
      NSMapRemove(my->contents, (void*)aKey);
    }

  if (addObjects > 0 && (maxSize > 0 || maxObjects > 0))
    {
      if (maxSize > 0)
	{
	  if (my->exclude == nil)
	    {
	      my->exclude = [NSMutableSet new];
	    }
	  [my->exclude removeAllObjects];
	  addSize = [anObject sizeInBytes: my->exclude];
	  if (addSize > maxSize)
	    {
	      addObjects = 0;	// Object too big to cache.
	    }
	}
    }

  if (addObjects > 0)
    {
      /*
       * Make room for new object.
       */
      [self shrinkObjects: maxObjects - addObjects
		  andSize: maxSize - addSize];
      item = [GSCacheItem newWithObject: anObject forKey: aKey];
      if (lifetime > 0)
	{
	  unsigned	tick = GSTickerTimeTick();

	  item->when = tick + lifetime;
	  item->warn = tick + lifetime / 2;
	}
      item->life = lifetime;
      item->size = addSize;
      NSMapInsert(my->contents, (void*)item->key, (void*)item);
      appendItem(item, &my->first);
      my->currentObjects += addObjects;
      my->currentSize += addSize;
      [item release];
    }
  [my->lock unlock];
}

- (void) setObject: (id)anObject
            forKey: (id)aKey
	     until: (NSDate*)expires
{
  NSTimeInterval	 i;

  i = (expires == nil) ? 0.0 : [expires timeIntervalSinceReferenceDate];
  i -= GSTickerTimeNow();
  if (i <= 0.0)
    {
      [self setObject: nil forKey: aKey];	// Already expired
    }
  else
    {
      unsigned	limit;

      if (i > 2415919103.0)
        {
	  limit = 0;	// Limit in far future.
	}
      else
	{
	  limit = (unsigned)i;
	}
      [self setObject: anObject
	       forKey: aKey
	     lifetime: limit];
    }
}

- (void) shrinkObjects: (unsigned)objects andSize: (unsigned)size 
{
  unsigned	newSize;
  unsigned	newObjects;

  [my->lock lock];
  newSize = [self currentSize];
  newObjects = [self currentObjects];
  if (newObjects > objects || (my->maxSize > 0 && newSize > size))
    {
      [self purge];
      newSize = [self currentSize];
      newObjects = [self currentObjects];
      while (newObjects > objects || (my->maxSize > 0 && newSize > size))
	{
	  GSCacheItem	*item;

	  item = my->first;
	  removeItem(item, &my->first);
	  newObjects--;
	  if (my->maxSize > 0)
	    {
	      newSize -= item->size;
	    }
	  NSMapRemove(my->contents, (void*)item->key);
	}
      my->currentObjects = newObjects;
      my->currentSize = newSize;
    }
  [my->lock unlock];
}
@end
@implementation	GSCache (Threading)
+ (void) _becomeThreaded: (NSNotification*)n
{
  NSHashEnumerator	e;
  GSCache		*c;

  [[NSNotificationCenter defaultCenter] removeObserver: self
    name: NSWillBecomeMultiThreadedNotification object: nil];
  allCachesLock = [NSRecursiveLock new];
  e = NSEnumerateHashTable(allCaches);
  while ((c = (GSCache*)NSNextHashEnumeratorItem(&e)) != nil)
    {
      [c _createLock];
    }
  NSEndHashTableEnumeration(&e);
}
- (void) _createLock
{
  my->lock = [NSRecursiveLock new];
}
@end

@implementation	NSArray (GSCacheSizeInBytes)
- (unsigned) sizeInBytes: (NSMutableSet*)exclude
{
  unsigned	size = [super sizeInBytes: exclude];

  if (size > 0)
    {
      unsigned	count = [self count];

      size += count*sizeof(void*);
      while (count-- > 0)
	{
	  size += [[self objectAtIndex: count] sizeInBytes: exclude];
	}
    }
  return size;
}
@end

@implementation	NSData (GSCacheSizeInBytes)
- (unsigned) sizeInBytes: (NSMutableSet*)exclude
{
  unsigned	size = [super sizeInBytes: exclude];

  if (size > 0)
    {
      size += [self length];
    }
  return size;
}
@end

@implementation	NSDictionary (GSCacheSizeInBytes)
- (unsigned) sizeInBytes: (NSMutableSet*)exclude
{
  unsigned	size = [super sizeInBytes: exclude];

  if (size > 0)
    {
      unsigned	count = [self count];

      size += 3 * sizeof(void*) * count;
      if (count > 0)
        {
	  NSAutoreleasePool	*pool = [NSAutoreleasePool new];
	  NSEnumerator		*enumerator = [self keyEnumerator];
	  NSObject		*k;

	  while ((k = [enumerator nextObject]) != nil)
	    {
	      NSObject	*o = [self objectForKey: k];

	      size += [k sizeInBytes: exclude] + [o sizeInBytes: exclude];
	    }
	  [pool release];
	}
    }
  return size;
}
@end

@implementation	NSObject (GSCacheSizeInBytes)
- (unsigned) sizeInBytes: (NSMutableSet*)exclude
{
  if ([exclude member: self] != nil)
    {
      return 0;
    }
  [exclude addObject: self];

  return class_getInstanceSize(isa); 
}
@end

@implementation	NSSet (GSCacheSizeInBytes)
- (unsigned) sizeInBytes: (NSMutableSet*)exclude
{
  unsigned	size = [super sizeInBytes: exclude];

  if (size > 0)
    {
      unsigned	count = [self count];

      size += 3 * sizeof(void*) * count;
      if (count > 0)
        {
	  NSAutoreleasePool	*pool = [NSAutoreleasePool new];
	  NSEnumerator		*enumerator = [self objectEnumerator];
	  NSObject		*o;

	  while ((o = [enumerator nextObject]) != nil)
	    {
	      size += [o sizeInBytes: exclude];
	    }
	  [pool release];
	}
    }
  return size;
}
@end

@implementation	NSString (GSCacheSizeInBytes)
- (unsigned) sizeInBytes: (NSMutableSet*)exclude
{
  if ([exclude member: self] != nil)
    {
      return 0;
    }
  else
    {
      return [super sizeInBytes: exclude] + sizeof(unichar) * [self length];
    }
}
@end

#if	defined(GNUSTEP_BASE_LIBRARY)

#import	<GNUstepBase/GSMime.h>

@implementation	GSMimeDocument (GSCacheSizeInBytes)
- (unsigned) sizeInBytes: (NSMutableSet*)exclude
{
  unsigned	size = [super sizeInBytes: exclude];

  if (size > 0)
    {
      size += [content sizeInBytes: exclude] + [headers sizeInBytes: exclude];
    }
  return size;
}
@end

@implementation	GSMimeHeader (GSCacheSizeInBytes)
- (unsigned) sizeInBytes: (NSMutableSet*)exclude
{
  unsigned	size = [super sizeInBytes: exclude];

  if (size > 0)
    {
      size += [name sizeInBytes: exclude]
        + [value sizeInBytes: exclude]
        + [objects sizeInBytes: exclude]
        + [params sizeInBytes: exclude];
    }
  return size;
}
@end

#endif

