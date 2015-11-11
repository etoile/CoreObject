/*
	Copyright (C) 2013 Quentin Mathe

	Date:  May 2013
	License:  MIT  (see COPYING)
 */

#import <EtoileFoundation/NSString+Etoile.h>
#import "COCommitDescriptor.h"
#import "COJSONSerialization.h"

@implementation COCommitDescriptor

@synthesize identifier = _identifier, type = _type, shortDescription = _shortDescription;

/* Commit descriptors by identifier */
static NSMutableDictionary *descriptorTable = nil;
static NSMutableDictionary *localizationTables = nil;
/* Type descriptions (e.g. 'Object Renaming') by type (e.g. 'renaming') */
static NSMutableDictionary *descriptorTypeTable = nil;

+ (void)loadCommitDescriptorsFromFile: (NSString *)aCommitFile
                              inTable: (NSMutableDictionary *)aDescriptorTable
                            typeTable: (NSMutableDictionary *)aTypeTable
{
	NSParameterAssert(aCommitFile != nil);
#ifdef GNUSTEP
	NSData *JSONData = [NSData dataWithContentsOfFile: aCommitFile];
#else
	// TODO: Error handling
	NSError *dataError = nil;
	NSData *JSONData =
		[NSData dataWithContentsOfFile: aCommitFile options: 0 error: &dataError];
	ETAssert(dataError == nil);
#endif
	NSDictionary *plist = COJSONObjectWithData(JSONData, NULL);

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

+ (void)loadLocalizationFromFile: (NSString *)aStringsFile
                        inTables: (NSMutableDictionary *)someLocalizationTables
{
	NSParameterAssert(aStringsFile != nil);
	
	if (![[NSFileManager defaultManager] fileExistsAtPath: aStringsFile isDirectory: NULL])
		return;

	NSError *error = nil;
	NSString *content = [NSString stringWithContentsOfFile: aStringsFile
	                                          usedEncoding: NULL
	                                                 error: &error];
	ETAssert(error == nil);
	NSDictionary *plist = [content propertyListFromStringsFileFormat];
	NSString *domain = [[aStringsFile lastPathComponent] stringByDeletingPathExtension];
	
	someLocalizationTables[domain] = plist;
}

+ (void)loadCommitDescriptorsInTable: (NSMutableDictionary *)aDescriptorTable
                           typeTable: (NSMutableDictionary *)aTypeTable
                  localizationTables: (NSMutableDictionary *)someLocalizationTables
{
	NSMutableArray *commitsFiles = [NSMutableArray array];
	NSMutableArray *stringsFiles = [NSMutableArray array];
	/* For the test suite on GNUstep, resources are packaged in the test bundle 
	   (it doesn't link the CoreObject framework) */
	NSBundle *coreObjectBundle = [NSBundle bundleForClass: self];
	NSArray *bundles =
		[A([NSBundle mainBundle], coreObjectBundle) arrayByAddingObjectsFromArray: [NSBundle allFrameworks]];

	for (NSBundle *bundle in bundles)
	{
		// FIXME: Once -[NSBundle pathsForResourcesOfType:inDirectory:] searches 
		// language directories correctly on GNUstep, remove this inner loop.
		for (NSString *lang in [bundle localizations])
		{
			NSString *localizedDirectory = [[[bundle resourcePath] stringByAppendingPathComponent: 
				[lang stringByAppendingPathExtension: @"lproj"]] stringByAppendingPathComponent: @"Commits"];
			NSFileManager *fileManager = [NSFileManager defaultManager];
			BOOL isDir = NO;

			if (![fileManager fileExistsAtPath: localizedDirectory isDirectory: &isDir] || !isDir)
				continue;

			NSArray *localizedFiles = [fileManager contentsOfDirectoryAtPath: localizedDirectory error: NULL];
			ETAssert(localizedFiles != nil);
			localizedFiles = [localizedFiles mappedCollectionWithBlock: ^ (NSString *subpath)
			{
				return [localizedDirectory stringByAppendingPathComponent: subpath];
			}];

			[commitsFiles addObjectsFromArray: [localizedFiles pathsMatchingExtensions: A(@"json")]];
			[stringsFiles addObjectsFromArray: [localizedFiles pathsMatchingExtensions: A(@"strings")]];
		}
	}
	
	for (NSString *file in commitsFiles)
	{
		[self loadCommitDescriptorsFromFile: file
		                            inTable: aDescriptorTable
		                          typeTable: aTypeTable];
	}
	for (NSString *file in stringsFiles)
	{
		[self loadLocalizationFromFile: file
		                      inTables: someLocalizationTables];
	}
}

+ (void) initialize
{
	if (self != [COCommitDescriptor class])
		return;

	descriptorTable = [NSMutableDictionary new];
	descriptorTypeTable = [NSMutableDictionary new];
	localizationTables = [NSMutableDictionary new];

	[self loadCommitDescriptorsInTable: descriptorTable
	                         typeTable: descriptorTypeTable
	                localizationTables: localizationTables];
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
	NSString *localizedString = localizationTables[self.domain][aKey];
	localizedString = (localizedString != nil ? localizedString : aFallbackString);
	
	if (formatArgs != nil)
	{
		localizedString = [self stringWithFormat: localizedString
		                           argumentArray: formatArgs];
	}
	return localizedString;
}

/**
 * Registers a commit descriptor based on -[COCommitDescriptor identifier].
 *
 * For a nil argument, raises a NSInvalidArgumentException.
 *
 * See also -identifier and +registeredDescriptorForIdentifier:.
 */
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

- (NSString *)description
{
	return [D([self identifier], kCOCommitMetadataIdentifier,
	          [self typeDescription], kCOCommitMetadataTypeDescription,
	          [self shortDescription], kCOCommitMetadataShortDescription) description];
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

- (NSString *)typeDescription
{
	return [descriptorTypeTable objectForKey: [self type]];
}

- (NSString *)localizedTypeDescription
{
	NSString *localizationKey =
		[NSString stringWithFormat: @"types/%@/TypeDescription", [self type]];
	return [self localizedStringForKey: localizationKey
	                             value: [self typeDescription]
	                         arguments: nil];
}

- (NSArray *)localizedArgumentsFromArguments: (NSArray *)args
{
	return [args mappedCollectionWithBlock: ^(NSString *argument)
	{
		if ([argument hasPrefix: @"_"])
		{
			NSString *key = [argument substringFromIndex: 1];

			return [self localizedStringForKey: key
			                             value: key
			                         arguments: nil];
		}
		else
		{
			return argument;
		}
	}];
}

- (NSString *)localizedShortDescriptionWithArguments: (NSArray *)args
{
	NSString *localizationKey =
		[NSString stringWithFormat: @"descriptors/%@/ShortDescription", [self name]];

	return [self localizedStringForKey: localizationKey
	                             value: [self shortDescription]
	                         arguments: [self localizedArgumentsFromArguments: args]];
}

@end

NSString *kCOCommitMetadataIdentifier = @"kCOCommitMetadataIdentifier";
NSString *kCOCommitMetadataTypeDescription = @"kCOCommitMetadataTypeDescription";
NSString *kCOCommitMetadataShortDescription = @"kCOCommitMetadataShortDescription";
NSString *kCOCommitMetadataShortDescriptionArguments = @"kCOCommitMetadataShortDescriptionArguments";
