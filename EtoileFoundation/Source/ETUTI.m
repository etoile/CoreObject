/*
        ETUTI.m
        
        Copyright (C) 2009 Eric Wasylishen
 
        Author:  Eric Wasylishen <ewasylishen@gmail.com>
        Date:  January 2009
 
        Redistribution and use in source and binary forms, with or without
        modification, are permitted provided that the following conditions are met:

        * Redistributions of source code must retain the above copyright notice,
          this list of conditions and the following disclaimer.
        * Redistributions in binary form must reproduce the above copyright notice,
          this list of conditions and the following disclaimer in the documentation
          and/or other materials provided with the distribution.
        * Neither the name of the Etoile project nor the names of its contributors
          may be used to endorse or promote products derived from this software
          without specific prior written permission.

        THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
        AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
        IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
        ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
        LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
        CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
        SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
        INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
        CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
        ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
        THE POSSIBILITY OF SUCH DAMAGE.
*/

#import <Foundation/Foundation.h>
#import "Macros.h"
#import "NSObject+Etoile.h"
#import "ETUTI.h"
#import "EtoileCompatibility.h"

/**
 * Maps type identifier strings to the corresponding ETUTI instance
 */
static NSMutableDictionary *ETUTIInstances; 

/**
 * Returns the last component of a UTI string (e.g @"audio" from @"public.audio")
 */
static NSString *ETUTILastComponent(NSString *aTypeString);

static NSString *ETObjCClassUTIPrefix = @"org.etoile-project.objc.class.";
static NSString *ETMIMEUTI = @"public.mime-type";
static NSString *ETFileUTI = @"public.filename-extension";


@interface ETUTI (Private)
- (ETUTI *) initWithString: (NSString *)aString
               description: (NSString *)aDescription
                  typeTags: (NSDictionary *)tags;
- (void) setSupertypesFromStrings: (NSArray *)supertypeStrings;
+ (id) propertyListWithPath: (NSString *)path;
+ (void) initializeWithUTIDictionaries: (NSArray *)UTIDictionaries;
+ (void) initializeClassBindings: (NSArray *)classBindings;
@end


@implementation ETUTI

+ (void) initialize
{
	if (self == [ETUTI class])
	{
		NSString *path = [[NSBundle bundleForClass: [ETUTI class]]
		                      pathForResource: @"UTIDefinitions"
		                               ofType: @"plist"];
		NSArray *array = (NSArray *)[ETUTI propertyListWithPath: path];
		[ETUTI initializeWithUTIDictionaries: array];
	
		NSString *bindingsPlist = [[NSBundle bundleForClass: [ETUTI class]]
		                      pathForResource: @"UTIClassBindings"
		                               ofType: @"plist"];
		NSArray *bindings = (NSArray *)[ETUTI propertyListWithPath: bindingsPlist];
		[ETUTI initializeClassBindings: bindings];
	}
}

+ (ETUTI *) typeWithString: (NSString *)aString
{
	ETUTI *cached = [ETUTIInstances objectForKey: aString];

	if (cached == nil && [aString hasPrefix: ETObjCClassUTIPrefix]
		&& NSClassFromString(ETUTILastComponent(aString)) != Nil)
	{
		return [ETUTI registerTypeWithString: aString
		                         description: @"Objective-C Class"
		                    supertypeStrings: nil];
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
	FOREACH(ETUTIInstances, aType, ETUTI *)
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
        FOREACH(ETUTIInstances, aType, ETUTI *)
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
{
	ETUTI *aType = [[ETUTI alloc] initWithString: aString
	                                description: description
	                                   typeTags: nil];
	[aType setSupertypesFromStrings: supertypeNames];
	[ETUTIInstances setObject: aType forKey: aString];
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
	return (NSArray *)[typeTags objectForKey: ETFileUTI];
}

- (NSArray *) MIMETypes
{
	return (NSArray *)[typeTags objectForKey: ETMIMEUTI];
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
	NSEnumerator *utiEnumerator = [ETUTIInstances objectEnumerator];
	FOREACHE(ETUTIInstances, type, ETUTI *, utiEnumerator)
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
	FOREACH([ETUTIInstances allValues], type, ETUTI *)
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
	NSData *data = [NSData dataWithContentsOfFile: path];
	return [NSPropertyListSerialization propertyListFromData:data
	                                        mutabilityOption:NSPropertyListImmutable
	                                                  format:NULL
	                                        errorDescription:NULL];
}

+ (void) initializeWithUTIDictionaries: (NSArray *)UTIDictionaries
{
	NSMutableArray *UTIStrings = [[NSMutableArray alloc] init];
	NSMutableArray *ETUTIInstancesArray = [[NSMutableArray alloc] init];
	FOREACH(UTIDictionaries, aTypeDict, NSDictionary *)
	{
		[UTIStrings addObject: [aTypeDict valueForKey: @"UTTypeIdentifier"]];
		ETUTI *aType = [[ETUTI alloc] initWithString: (NSString *)[aTypeDict valueForKey: @"UTTypeIdentifier"]
		                                 description: (NSString *)[aTypeDict valueForKey: @"UTTypeDescription"]
		                                    typeTags: (NSDictionary *)[aTypeDict valueForKey: @"UTTypeTagSpecification"]];
		[ETUTIInstancesArray addObject: aType];
		[aType release];
	}
	
	ETUTIInstances = [[NSMutableDictionary alloc] initWithObjects: ETUTIInstancesArray
	                                                      forKeys: UTIStrings];
	
	[UTIStrings release];
	[ETUTIInstancesArray release];
	FOREACH(UTIDictionaries, aTypeDict2, NSDictionary *)
	{
		[[ETUTIInstances objectForKey: [aTypeDict2 valueForKey: @"UTTypeIdentifier"]]
		     setSupertypesFromStrings: (NSArray *)[aTypeDict2 valueForKey: @"UTTypeConformsTo"]];
	}
}

+ (void) initializeClassBindings: (NSArray *)classBindings
{
	FOREACH(classBindings, classBinding, NSDictionary *)
	{
		NSString *className = [classBinding valueForKey: @"UTClassName"];
		NSArray *supertypeNames = [classBinding valueForKey: @"UTTypeConformsTo"];
		[ETUTI registerTypeWithString: [ETObjCClassUTIPrefix stringByAppendingString: className]
		                  description: @"Objective-C Class"
		             supertypeStrings: supertypeNames];

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
