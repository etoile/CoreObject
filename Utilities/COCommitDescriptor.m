/*
	Copyright (C) 2013 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  May 2013
	License:  Modified BSD  (see COPYING)

 */

#import <EtoileFoundation/NSString+Etoile.h>
#import "COCommitDescriptor.h"

@implementation COCommitDescriptor

@synthesize identifier = _identifier, type = _type, shortDescription = _shortDescription;

/* Commit descriptors by identifier */
static NSMutableDictionary *descriptorTable = nil;
static NSMutableDictionary *localizationTable = nil;
/* Type descriptions (e.g. 'Object Renaming') by type (e.g. 'renaming') */
static NSMutableDictionary *descriptorTypeTable = nil;

+ (void)loadCommitDescriptorsFromFile: (NSString *)aCommitFile
                              inTable: (NSMutableDictionary *)aDescriptorTable
                            typeTable: (NSMutableDictionary *)aTypeTable
{
	NSParameterAssert(aCommitFile != nil);
	// TODO: Error handling
	NSError *dataError = nil;
	NSData *JSONData =
		[NSData dataWithContentsOfFile: aCommitFile options: 0 error: &dataError];
	ETAssert(dataError == nil);
	NSError *JSONError = nil;
	NSDictionary *plist =
		[NSJSONSerialization JSONObjectWithData: JSONData options: 0 error: &JSONError];
	ETAssert(JSONError == nil);

	[aTypeTable addEntriesFromDictionary: [plist objectForKey: @"types"]];

	NSDictionary *descriptors = [plist objectForKey: @"descriptors"];

	for (NSString *name in descriptors)
	{
		NSDictionary *plist = [descriptors objectForKey: name];
		NSString *identifier = [[[aCommitFile lastPathComponent]
			stringByDeletingPathExtension] stringByAppendingPathExtension: name];
		COCommitDescriptor *descriptor =
			[[COCommitDescriptor alloc] initWithIdentifier: identifier
		                                      propertyList: plist];
		
		ETAssert([identifier hasPrefix: [descriptor domain]]);
		ETAssert([descriptor typeDescription] != nil);
		ETAssert([descriptor shortDescription] != nil);

		[aDescriptorTable setObject: descriptor forKey: identifier];
	}
}

+ (void)loadCommitDescriptorsInTable: (NSMutableDictionary *)aDescriptorTable
                           typeTable: (NSMutableDictionary *)aTypeTable
{
	NSArray *commitsFiles =
		[[NSBundle mainBundle] pathsForResourcesOfType: @"json" inDirectory: @"Commits"];
	
	
	for (NSString *file in commitsFiles)
	{
		[self loadCommitDescriptorsFromFile: file
		                            inTable: aDescriptorTable
		                          typeTable: aTypeTable];
	}
}

+ (void) initialize
{
	if (self != [COCommitDescriptor class])
		return;

	descriptorTable = [NSMutableDictionary new];
	descriptorTypeTable = [NSMutableDictionary new];
	localizationTable = [NSMutableDictionary new];

	[self loadCommitDescriptorsInTable: descriptorTable
	                         typeTable: descriptorTypeTable];
}

// NOTE: va_list structure is not portable, so no hope to synthesize it. Still
// figuring a better solution than the code below would be nice.
- (id)stringWithFormat: (NSString *)format argumentArray: (NSArray *)args
{
	NSString *formattedString = format;

	for (NSString *arg in args)
	{
		NSRange range = [formattedString rangeOfString: @"%@"];

		if (range.length == 0)
		{
			[NSException raise: NSInternalInconsistencyException
						format: @"Format string %@ doesn't match the argument count in %@",
			                    format, args];
		}
		
		formattedString = [formattedString stringByReplacingCharactersInRange: range
															       withString: arg];
	}
	return formattedString;
}

- (NSString *)localizedStringForKey: (NSString *)aKey
                              value: (NSString *)aFallbackString
                          arguments: (NSArray *)formatArgs
{
	NSString *localizedString = [localizationTable objectForKey: aKey];
	localizedString = (localizedString != nil ? localizedString : aFallbackString);
	
	if (formatArgs != nil)
	{
		localizedString = [self stringWithFormat: localizedString
		                           argumentArray: formatArgs];
	}
	return localizedString;
}

+ (void) registerDescriptor: (COCommitDescriptor *)aDescriptor
{
	NILARG_EXCEPTION_TEST(aDescriptor);
	INVALIDARG_EXCEPTION_TEST(aDescriptor, [aDescriptor domain] != nil);
	INVALIDARG_EXCEPTION_TEST(aDescriptor, [[aDescriptor domain] isEqual: [aDescriptor identifier]]);

	[descriptorTable setObject: aDescriptor forKey: [aDescriptor identifier]];
}

+ (COCommitDescriptor *) registeredDescriptorForIdentifier: (NSString *)anIdentifier
{
	NILARG_EXCEPTION_TEST(anIdentifier);

	return [descriptorTable objectForKey: anIdentifier];
}

- (id)initWithIdentifier: (NSString *)anId
            propertyList: (NSDictionary *)plist
{
	SUPERINIT;
	_identifier = anId;
	_type = [plist objectForKey: @"type"];
	_shortDescription = [plist objectForKey: @"shortDescription"];
	return self;
}
											
- (NSString *)domain
{
	/* Turn 'org.etoile-project.ObjectManager.rename/shortDescription'  
	   into 'org.etoile-project.ObjectManager' */

	/* Trim property suffix if present (e.g. /shortDescription) */

	NSArray *components = [[self identifier] componentsSeparatedByString: @"/"];
	ETAssert([components count] == 1 || [components count] == 2);
	NSString *idMinusProperty = [components firstObject];

	/* Trim operation suffix (e.g. .rename) */

	NSArray *subcomponents = [idMinusProperty componentsSeparatedByString: @"."];
	NSRange domainRange = NSMakeRange(0, [subcomponents count] - 1);
	NSString *domain =
		[[subcomponents subarrayWithRange: domainRange] componentsJoinedByString: @"."];
	
	return domain;
}

- (NSString *)name
{
	return [[[self identifier] componentsSeparatedByString: @"."] lastObject];
}

- (void) setType: (NSString *)aType
{
	NILARG_EXCEPTION_TEST(aType);
	_type = aType;
}

- (NSString *)typeDescription
{
	return [descriptorTypeTable objectForKey: [self type]];
}

- (NSString *)localizedTypeDescription
{
	NSString *localizationKey =
		[NSString stringWithFormat: @"types/%@/TypeDescription", [self type]];
	return [self localizedStringForKey: localizationKey
	                             value: [self shortDescription]
	                         arguments: nil];
}

- (void) setShortDescription: (NSString *)aDescription
{
	NILARG_EXCEPTION_TEST(aDescription);
	_shortDescription = aDescription;
}

- (NSString *)localizedShortDescriptionWithArguments: (NSArray *)args
{
	NSString *localizationKey =
		[NSString stringWithFormat: @"descriptors/%@/ShortDescription", [self name]];
	return [self localizedStringForKey: localizationKey
	                             value: [self shortDescription]
	                         arguments: args];
}

- (NSDictionary *)persistentMetadata
{
	return D([self identifier], kCOCommitMetadataIdentifier,
	         [self typeDescription], kCOCommitMetadataTypeDescription,
	         [self shortDescription], kCOCommitMetadataShortDescription);
}

@end

NSString *kCOCommitMetadataIdentifier = @"kCOCommitMetadataIdentifier";
NSString *kCOCommitMetadataTypeDescription = @"kCOCommitMetadataTypeDescription";
NSString *kCOCommitMetadataShortDescription = @"kCOCommitMetadataShortDescription";
NSString *kCOCommitMetadataShortDescriptionArguments = @"kCOCommitMetadataShortDescriptionArguments";
