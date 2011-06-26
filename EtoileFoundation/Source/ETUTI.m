/*
        Copyright (C) 2009 Eric Wasylishen

        Author:  Eric Wasylishen <ewasylishen@gmail.com>
        Date:  January 2009
	License:  Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>
#import "ETUTI.h"
#import "ETCollection.h"
#import "Macros.h"
#import "NSObject+Etoile.h"
#import "EtoileCompatibility.h"

/*
 * Maps type identifier strings to the corresponding ETUTI instance
 */
static NSMutableDictionary *UTIInstances; 

/*
 * Returns the last component of a UTI string (e.g @"audio" from @"public.audio")
 */
static NSString *ETUTILastComponent(NSString *aTypeString);

static NSString *ETObjCClassUTIPrefix = @"org.etoile-project.objc.class.";
NSString * const kETUTITagClassMIMEType = @"public.mime-type";
NSString * const kETUTITagClassFileExtension = @"public.filename-extension";


@interface ETUTI (Private)
- (ETUTI *) initWithString: (NSString *)aString
               description: (NSString *)aDescription
                  typeTags: (NSDictionary *)tags;
- (void) setSupertypesFromStrings: (NSArray *)supertypeStrings;
+ (id) propertyListWithPath: (NSString *)path;
+ (void) registerUTIDefinitions: (NSArray *)UTIDictionaries;
+ (void) registerClassBindings: (NSArray *)classBindings;
@end


@implementation ETUTI

+ (void) initialize
{
	if (self == [ETUTI class])
	{
		UTIInstances = [[NSMutableDictionary alloc] init];

		/* EtoileFoundation Bundle */

		NSBundle *bundle = [NSBundle bundleForClass: [ETUTI class]];
		NSString *path = [bundle pathForResource: @"UTIDefinitions" 
		                                  ofType: @"plist"];
		[ETUTI registerUTIDefinitions: [ETUTI propertyListWithPath: path]];
	
		path = [bundle pathForResource: @"UTIClassBindings" 
		                        ofType: @"plist"];
		[ETUTI registerClassBindings: [ETUTI propertyListWithPath: path]];

		/* Main Bundle (e.g. application document types) */

		path = [[NSBundle mainBundle] pathForResource: @"UTIDefinitions"
		                                       ofType: @"plist"];
		[ETUTI registerUTIDefinitions: [ETUTI propertyListWithPath: path]];

		path = [[NSBundle mainBundle] pathForResource: @"UTIClassBindings"
		                                       ofType: @"plist"];
		[ETUTI registerClassBindings: [ETUTI propertyListWithPath: path]];
	}
}

+ (ETUTI *) typeWithString: (NSString *)aString
{
	ETUTI *cached = [UTIInstances objectForKey: aString];

	if (cached == nil && [aString hasPrefix: ETObjCClassUTIPrefix]
		&& NSClassFromString(ETUTILastComponent(aString)) != Nil)
	{
		return [ETUTI registerTypeWithString: aString
		                         description: @"Objective-C Class"
		                    supertypeStrings: nil
		                            typeTags: nil];
	}
	return cached;
}

+ (ETUTI *) typeWithPath: (NSString *)aPath
{
        return [ETUTI typeWithFileExtension: [aPath pathExtension]];
}

+ (ETUTI *) typeWithFileExtension: (NSString *)anExtension
{
	//FIXME: just returns the first UTI it finds matching the extension
	FOREACH(UTIInstances, aType, ETUTI *)
	{
		FOREACH([aType fileExtensions], ext, NSString *)
		{
			if ([ext isEqual: anExtension])
			{
				return aType;
			}
		}
	}
	return nil;
}

+ (ETUTI *) typeWithMIMEType: (NSString *)aMIME
{
        //FIXME: just returns the first UTI it finds matching the MIME type
        FOREACH(UTIInstances, aType, ETUTI *)
        {
                FOREACH([aType MIMETypes], mime, NSString *)
                {
                        if ([mime isEqual: aMIME])
			{
                                return aType;
			}
                }
        }
        return nil;
}

+ (ETUTI *) typeWithClass: (Class)aClass
{
	return [ETUTI typeWithString:
		[ETObjCClassUTIPrefix stringByAppendingString: NSStringFromClass(aClass)]];
}

+ (ETUTI *) registerTypeWithString: (NSString *)aString
                       description: (NSString *)description
                  supertypeStrings: (NSArray *)supertypeNames
                          typeTags: (NSDictionary *)tags                                                                                                                                                                         
{
	ETUTI *aType = [[ETUTI alloc] initWithString: aString
	                                 description: description
	                                    typeTags: tags];
	[aType setSupertypesFromStrings: supertypeNames];
	[UTIInstances setObject: aType forKey: aString];
	return [aType autorelease];
}

+ (ETUTI *) transientTypeWithSupertypeStrings: (NSArray *)supertypeNames
{
	ETUTI *result = [[ETUTI alloc] initWithString: nil description: nil typeTags: nil];
	[result setSupertypesFromStrings: supertypeNames];
	return [result autorelease];
}

+ (ETUTI *) transientTypeWithSupertypes: (NSArray *)supertypes
{
	ETUTI *result = [[ETUTI alloc] initWithString: nil description: nil typeTags: nil];
	result->supertypes = [[NSArray alloc] initWithArray: supertypes];
	return [result autorelease];
}


- (NSString *) stringValue
{
	return string;
}

- (Class) classValue
{
	if (NO == [string hasPrefix: @"org.etoile-project.objc.class."])
	{
		return Nil;
	}
	NSUInteger prefixLength = 30;
	ETAssert([string length] > prefixLength);

	return NSClassFromString([string pathExtension]);
}

- (NSString *) typeDescription
{
	return description;
}

- (NSString *) description /* NSObject */
{
	return [self stringValue];
}

- (NSArray *) fileExtensions
{
	return (NSArray *)[typeTags objectForKey: kETUTITagClassFileExtension];
}

- (NSArray *) MIMETypes
{
	return (NSArray *)[typeTags objectForKey: kETUTITagClassMIMEType];
}

- (NSArray *) supertypes
{
	NSMutableArray *result = [NSMutableArray arrayWithArray: supertypes];	// supertypes could be nil.

	if ([[self stringValue] hasPrefix:ETObjCClassUTIPrefix])
	{
		NSString *selfClassName = ETUTILastComponent([self stringValue]);
		Class class = NSClassFromString(selfClassName);

		// This is a hack to work around the fact that NSClassFromString will
		// sometimes return a private subclass of the requested class.
		// (for example, NSClassFromString(@"NSImage") == [CLImage class])
		while (![NSStringFromClass(class) isEqualToString: selfClassName])
		{
			class = [class superclass];
		}

		Class superclass = [class superclass];

		if (superclass != Nil)
		{
			[result addObject: [ETUTI typeWithClass: superclass]];
		}
	}
	return result;
}

- (NSArray *) allSupertypes
{
	NSMutableSet *resultSet = [NSMutableSet setWithCapacity: 32];
	FOREACH([self supertypes], supertype, ETUTI *)
	{
		[resultSet addObject: supertype];
		[resultSet addObjectsFromArray: [supertype allSupertypes]];
	}
	return [resultSet allObjects];
}

- (NSArray *) subtypes
{
	NSMutableArray *result = [NSMutableArray array];
	NSEnumerator *utiEnumerator = [UTIInstances objectEnumerator];
	FOREACHE(UTIInstances, type, ETUTI *, utiEnumerator)
	{
		if ([type->supertypes containsObject: self])
			[result addObject: type];
	}
	//FIXME: handle the case where self is an objc class UTI
	return result;
}

- (NSArray *) allSubtypes
{
	NSMutableArray *result = [NSMutableArray array];
	FOREACH([UTIInstances allValues], type, ETUTI *)
	{
		if ([type conformsToType: self] && type != self)
			[result addObject: type];
	}
	//FIXME: handle the case where self is an objc class UTI
	return result;
}

- (BOOL) conformsToType: (ETUTI *)aType
{
	if (aType == self)
	{
		return YES;
	}
	FOREACH([self supertypes], supertype, ETUTI *)
	{
		if (supertype == self)
		{
			[NSException raise: NSInternalInconsistencyException
			            format: @"UTI %@ is a supertype of itself", self];
		}
		if ([supertype conformsToType: aType])
		{
			return YES;
		}
	}
	return NO;
}

- (id) copyWithZone: (NSZone *)aZone
{
	return RETAIN(self);	
}

@end


@implementation ETUTI (Private)

- (ETUTI *) initWithString: (NSString *)aString
               description: (NSString *)aDescription
                  typeTags: (NSDictionary *)tags
{
	SUPERINIT
	ASSIGN(string, aString);
	ASSIGN(description, aDescription);
	ASSIGN(typeTags, tags);
	return self;
}

- (id) init
{
	return nil;
}

- (void) dealloc
{
	[string release];
	[description release];
	[supertypes release];
	[typeTags release];
	[super dealloc];
}

- (void) setSupertypesFromStrings: (NSArray *)supertypeStrings
{
	[supertypes release];
	supertypes = [[NSMutableArray alloc] init];
	FOREACH(supertypeStrings, supertypeString, NSString *)
	{
		ETUTI *supertype = [ETUTI typeWithString: supertypeString];
		if (supertype == nil)
		{
			[NSException raise: NSInvalidArgumentException
			            format: @"Attempted to use non-existant UTI %@ as a supertype", supertypeString];
		}
		[(NSMutableArray *)supertypes addObject: supertype];
	}
}

+ (id) propertyListWithPath: (NSString *)path
{
	if (path == nil)
		return nil;

	NSData *data = [NSData dataWithContentsOfFile: path];
	return [NSPropertyListSerialization propertyListFromData: data
	                                        mutabilityOption: NSPropertyListImmutable
	                                                  format: NULL
	                                        errorDescription: NULL];
}

+ (void) registerUTIDefinitions: (NSArray *)UTIDictionaries
{
	if (UTIDictionaries == nil)
		return;

	NSMutableArray *duplicateIdentifiers = [NSMutableArray array];

	FOREACH(UTIDictionaries, aTypeDict, NSDictionary *)
	{
		NSString *typeIdentifier = [aTypeDict valueForKey: @"UTTypeIdentifier"];
		BOOL isRegistered = ([UTIInstances objectForKey: typeIdentifier] != nil);

		if (isRegistered)
		{
			[duplicateIdentifiers addObject: typeIdentifier];
			continue;
		}
		
		ETUTI *aType = [[ETUTI alloc] initWithString: typeIdentifier                               
		                                 description: [aTypeDict valueForKey: @"UTTypeDescription"]
		                                    typeTags: [aTypeDict valueForKey: @"UTTypeTagSpecification"]];
		[UTIInstances setObject: aType forKey: typeIdentifier];
		[aType release];
	}

	if ([duplicateIdentifiers isEmpty] == NO)
	{
		NSLog(@"WARNING: Failed to register UTIs %@. These identifiers are "
			"already in use.", duplicateIdentifiers);
	}

	FOREACH(UTIDictionaries, aTypeDict2, NSDictionary *)
	{
		[[UTIInstances objectForKey: [aTypeDict2 valueForKey: @"UTTypeIdentifier"]]
			setSupertypesFromStrings: [aTypeDict2 valueForKey: @"UTTypeConformsTo"]];
	}
}

+ (void) registerClassBindings: (NSArray *)classBindings
{
	if (classBindings == nil)
		return;

	FOREACH(classBindings, classBinding, NSDictionary *)
	{
		NSString *className = [classBinding valueForKey: @"UTClassName"];
		NSArray *supertypeNames = [classBinding valueForKey: @"UTTypeConformsTo"];
		[ETUTI registerTypeWithString: [ETObjCClassUTIPrefix stringByAppendingString: className]
		                  description: @"Objective-C Class"
		             supertypeStrings: supertypeNames
		                     typeTags: nil];

	}
}

@end


NSString *ETUTILastComponent(NSString *aTypeString)
{
	NSRange lastPeriod = [aTypeString rangeOfString:@"." options:NSBackwardsSearch];
	if (lastPeriod.location != NSNotFound)
        {
                return [aTypeString substringFromIndex: (lastPeriod.location + 1)];
        }
	return @"";
}
