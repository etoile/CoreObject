#import "COObject.h"

@interface COMutableArrayProxy : NSMutableArray
{
	COObject *_obj;
	NSString *_property;
}

- (id) initWithObject: (COObject*)obj property: (NSString*)property;

/* Primitive methods required to create a NSMutableArray subclass */
- (NSUInteger)count;
- (id)objectAtIndex: (NSUInteger)index;
- (void)insertObject: (id)object atIndex: (NSUInteger)index;
- (void)removeObjectAtIndex: (NSUInteger)index;
- (void)addObject: (id)object;
- (void)removeLastObject;
- (void)replaceObjectAtIndex: (NSUInteger)index withObject: (id)object;

@end

@interface COMutableSetProxy : NSMutableSet
{
	COObject *_obj;
	NSString *_property;
}

- (id) initWithObject: (COObject*)obj property: (NSString*)property;

/* Primitive methods */
- (NSUInteger)count;
- (id)member: (id)object;
- (NSEnumerator *)objectEnumerator;
- (void)addObject: (id)object;
- (void)removeObject: (id)object;

@end



@implementation COObject (KVC)

- (id) valueForKey: (NSString *)key
{
	return [self valueForProperty: key];
}

- (void) setValue: (id)value forKey: (NSString*)key
{
	[self setValue: value forProperty: key];
}

- (NSMutableArray*) mutableArrayValueForKey: (NSString *)key
{
	return [[[COMutableArrayProxy alloc] initWithObject: self property: key] autorelease];
}

- (NSMutableSet*) mutableSetValueForKey: (NSString *)key
{
	return [[[COMutableSetProxy alloc] initWithObject: self property: key] autorelease];
}

@end


@implementation COMutableArrayProxy

- (id) initWithObject: (COObject*)obj property: (NSString*)property
{
	self = [super init];
	ASSIGN(_obj, obj);
	ASSIGN(_property, property);
	return self;
}
- (void) dealloc
{
	[_obj release];
	[_property release];
}

- (NSMutableArray*) targetMutableArray
{
	return [_obj _mutableValueForProperty: _property];
}
- (void) notifyObjectContext
{
	[_obj setModified];
}

/* Primitive methods required to create a NSMutableArray subclass */

- (NSUInteger)count
{
	return [[self targetMutableArray] count];
}
- (id)objectAtIndex: (NSUInteger)index
{
	return [[self targetMutableArray] objectAtIndex: index];
}
- (void)insertObject: (id)object atIndex: (NSUInteger)index
{
	[[self targetMutableArray] insertObject: object atIndex: index];
	[self notifyObjectContext];
}
- (void)removeObjectAtIndex: (NSUInteger)index
{
	[[self targetMutableArray] removeObjectAtIndex: index];
	[self notifyObjectContext];
}
- (void)addObject: (id)object
{
	[[self targetMutableArray] addObject: object];
	[self notifyObjectContext];
}
- (void)removeLastObject
{
	[[self targetMutableArray] removeLastObject];
	[self notifyObjectContext];
}
- (void)replaceObjectAtIndex: (NSUInteger)index withObject: (id)object
{
	[[self targetMutableArray] replaceObjectAtIndex: index withObject: object];
	[self notifyObjectContext];
}

@end



@implementation COMutableSetProxy


- (id) initWithObject: (COObject*)obj property: (NSString*)property
{
	self = [super init];
	ASSIGN(_obj, obj);
	ASSIGN(_property, property);
	return self;
}
- (void) dealloc
{
	[_obj release];
	[_property release];
}

- (NSMutableSet*) targetMutableSet
{
	return [_obj _mutableValueForProperty: _property];
}
- (void) notifyObjectContext
{
	[_obj setModified];
}

/* Primitive methods required to create a NSMutableArray subclass */

- (NSUInteger)count
{
	return [[self targetMutableSet] count];
}
- (id)member: (id)object
{
	return [[self targetMutableSet] member: object];
}
- (NSEnumerator *)objectEnumerator
{
	return [[self targetMutableSet] objectEnumerator];
}
- (void)addObject: (id)object
{
	[[self targetMutableSet] addObject: object];
	[self notifyObjectContext];
}
- (void)removeObject: (id)object
{
	[[self targetMutableSet] removeObject: object];
	[self notifyObjectContext];
}

@end

