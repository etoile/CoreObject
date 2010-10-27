/*
	Mirror-based reflection API for Etoile.
 
	Copyright (C) 2009 Eric Wasylishen
 
	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  June 2009
	License: Modified BSD (see COPYING)
 */

#ifdef GNUSTEP
#import <GNUstepBase/GSObjCRuntime.h>
#endif
#import "ETInstanceVariableMirror.h"
#import "ETUTI.h"
#import "Macros.h"
#import "NSObject+Model.h"
#import "EtoileCompatibility.h"


@implementation ETInstanceVariableMirror

- (id) initWithIvar: (Ivar)ivar ownerMirror: (id <ETMirror>)aMirror
{
	SUPERINIT;
	_ivar = ivar;
	// NOTE: For now our owner doesn't retain us, thereby _ownerMirror is not 
	// a weak reference.
	ASSIGN(_ownerMirror, aMirror);
	return self;
}

+ (id) mirrorWithIvar: (Ivar)ivar ownerMirror: (id <ETMirror>)aMirror
{
	return [[[ETInstanceVariableMirror alloc] initWithIvar: ivar
	                                           ownerMirror: aMirror] autorelease];
}

DEALLOC(DESTROY(_ownerMirror))

- (NSString *) name
{
	return [NSString stringWithUTF8String: ivar_getName(_ivar)];
}

- (NSArray *) properties
{
	return [[super properties] arrayByAddingObjectsFromArray: A(@"ownerMirror", 
		@"name", @"type", @"typeName", @"typeEncoding", @"isObjectType", @"value")];
}

- (ETUTI *) type
{
	// FIXME: map ivar type to a UTI
	return [ETUTI typeWithClass: [NSObject class]];
}

- (NSString *) description
{
	return [NSString stringWithFormat:
			@"ETInstanceVariableMirror %@", [self name]];
}

- (id <ETMirror>) ownerMirror;
{
	return _ownerMirror;
}

- (id <ETObjectMirror>) ownerObjectMirror;
{
	id ownerMirror = [self ownerMirror];

	if ([ownerMirror conformsToProtocol: @protocol(ETObjectMirror)] == NO)
	{
		return nil;
	}

	return ownerMirror;
}


- (NSString *) typeName
{
	const char *ivarType = [self typeEncoding];

	if (ivarType[0] == '@')
	{
		id value = [self value];
		
		if (value != nil)
			return NSStringFromClass([value class]);
	}

	return [NSString stringWithUTF8String: ivarType];
}

- (const char *) typeEncoding
{
	return ivar_getTypeEncoding(_ivar);
}

- (BOOL) isObjectType
{
	const char *ivarType = [self typeEncoding];
	return (ivarType[0] == '@');
}

// TODO: Rewrite to support that on Apple runtime too, we probably need 
// something like GSObjCGetVal() in ObjC2 framework.
- (id) value
{
	id ownerObjectMirror = [self ownerObjectMirror];
	if (nil == ownerObjectMirror)
	{
		return nil;
	}

#ifdef GNUSTEP
	const char *ivarType = ivar_getTypeEncoding(_ivar);

	/* Check the encoding types supported by GSObjCGetVal() and defined in 
	   objc-api.h, otherwise this function raises an exception when the type is 
	   not supported. */
	switch (ivarType[0])
	{
		case _C_STRUCT_B:
			if (strcmp(@encode(NSPoint), ivarType) != 0
			 && strcmp(@encode(NSRect), ivarType) != 0
			 && strcmp(@encode(NSSize), ivarType) != 0
			 && strcmp(@encode(NSRange), ivarType) != 0)
			{
				return nil; /* Unsupported struct type */
			}
		case _C_ID:
		case _C_CLASS:
		case _C_CHR:
		case _C_UCHR:
		case _C_SHT:
		case _C_USHT:
		case _C_INT:
		case _C_UINT:
		case _C_LNG:
		case _C_ULNG:
		case _C_LNG_LNG:
		case _C_ULNG_LNG:
		case _C_FLT:
		case _C_DBL:
		case _C_VOID:

			return GSObjCGetVal([ownerObjectMirror representedObject], 
				ivar_getName(_ivar), NULL, ivarType, 0, ivar_getOffset(_ivar));

		default: /* Unsupported type */
			return nil;
	}
#else
	const char *ivarType = ivar_getTypeEncoding(_ivar);

	// TODO: More type support
	switch (ivarType[0])
	{
		case '@':
			return object_getIvar([ownerObjectMirror representedObject] , _ivar);
		default: /* Unsupported type */
			return nil;
	}
#endif
}

// TODO: Rewrite to support that on Apple runtime too, we probably need 
// something like GSObjCSetVal() in ObjC2 framework.
- (void) setValue: (id)value
{
	id ownerObjectMirror = [self ownerObjectMirror];
	if (nil == ownerObjectMirror)
	{
		return;
	}

#ifdef GNUSTEP
	const char *ivarType = ivar_getTypeEncoding(_ivar);

	/* Check the encoding types supported by GSObjCSetVal() and defined in 
	   objc-api.h, otherwise this function raises an exception when the type is 
	   not supported. */
	switch (ivarType[0])
	{
		case _C_STRUCT_B:
			if (strcmp(@encode(NSPoint), ivarType) != 0
			 && strcmp(@encode(NSRect), ivarType) != 0
			 && strcmp(@encode(NSSize), ivarType) != 0
			 && strcmp(@encode(NSRange), ivarType) != 0)
			{
				return; /* Unsupported struct type */
			}
		case _C_ID:
		case _C_CLASS:
		case _C_CHR:
		case _C_UCHR:
		case _C_SHT:
		case _C_USHT:
		case _C_INT:
		case _C_UINT:
		case _C_LNG:
		case _C_ULNG:
		case _C_LNG_LNG:
		case _C_ULNG_LNG:
		case _C_FLT:
		case _C_DBL:
		case _C_VOID:

			GSObjCSetVal([ownerObjectMirror representedObject], ivar_getName(_ivar), 
				value, NULL, ivarType, 0, ivar_getOffset(_ivar));
	}
#endif
}

- (id) cachedValueMirrorForValue: (id)aValue
{
	if (nil == aValue)
	{
		ASSIGN(_cachedValueMirror, nil);
		return nil;
	}

	BOOL isCachedValueMirrorInvalid = (nil == _cachedValueMirror 
		|| [_cachedValueMirror representedObject] != aValue);

	if (isCachedValueMirrorInvalid)
	{
		ASSIGN(_cachedValueMirror, [ETReflection reflectObject: aValue]);
	}

	return _cachedValueMirror;
}

- (id <ETObjectMirror>) valueMirror
{
	if ([self isObjectType] == NO)
	{
		return nil;
	}

	/* Will return nil when there is no object owner mirror, see -value. */
	return [self cachedValueMirrorForValue: [self value]];
}

@end
