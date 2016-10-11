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

    [aTypeTable addEntriesFromDictionary: plist[@"types"]];

    NSDictionary *descriptors = plist[@"descriptors"];

    for (NSString *name in descriptors)
    {
        NSDictionary *plist = descriptors[name];
        NSString *identifier = [aCommitFile.lastPathComponent.stringByDeletingPathExtension stringByAppendingPathExtension: name];
        COCommitDescriptor *descriptor =
            [[COCommitDescriptor alloc] initWithIdentifier: identifier
                                              propertyList: plist];

        ETAssert([identifier hasPrefix: [descriptor domain]]);
        ETAssert([descriptor typeDescription] != nil);
        ETAssert([descriptor shortDescription] != nil);

        aDescriptorTable[identifier] = descriptor;
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
    NSString *domain = aStringsFile.lastPathComponent.stringByDeletingPathExtension;

    someLocalizationTables[domain] = plist;
}

static NSString *languageDirectoryForLocalization(NSString *localization, NSBundle *bundle)
{
    NSString *lang = localization;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir = NO;

    if ([localization isEqualToString: bundle.developmentLocalization])
    {
        NSString *baseDirectory = [bundle.resourcePath
            stringByAppendingPathComponent: [@"Base" stringByAppendingPathExtension: @"lproj"]];

        if ([fileManager fileExistsAtPath: baseDirectory isDirectory: &isDir] && isDir)
        {
            lang = @"Base";
        }
    }
    return [bundle.resourcePath stringByAppendingPathComponent:
        [lang stringByAppendingPathExtension: @"lproj"]];
}

/**
 * See Language and Locale IDs in Apple Internalization Guide.
 */
static void validateMainBundlePreferredLocalizations()
{
    for (NSString *localization in [NSBundle mainBundle].preferredLocalizations)
    {
        const BOOL isTwoLettersISOCode = (localization.length == 2);
        const BOOL isThreeLettersISOCode = (localization.length == 3);
        const BOOL isCompoundLanguageID = (localization.length >= 4
            && ([localization characterAtIndex: 2] == '-' || [localization characterAtIndex: 3] == '-'));
        
        NSCAssert(isTwoLettersISOCode || isThreeLettersISOCode || isCompoundLanguageID,
            @"-[NSBundle mainBundle].preferredLocalizations must not include full languages names, "
                "check CFBundleDevelopmentRegion is set to a valid language ID in the Info.plist");
    }
}

+ (void)loadCommitDescriptorsInTable: (NSMutableDictionary *)aDescriptorTable
                           typeTable: (NSMutableDictionary *)aTypeTable
                  localizationTables: (NSMutableDictionary *)someLocalizationTables
{
    NSMutableSet *commitsFiles = [NSMutableSet new];
    NSMutableSet *stringsFiles = [NSMutableSet new];
    /* For the test suite on GNUstep, resources are packaged in the test bundle 
       (it doesn't link the CoreObject framework) */
    NSBundle *coreObjectBundle = [NSBundle bundleForClass: self];
    NSArray *bundles =
        [@[[NSBundle mainBundle],
           coreObjectBundle] arrayByAddingObjectsFromArray: [NSBundle allFrameworks]];
    
    validateMainBundlePreferredLocalizations();

    for (NSBundle *bundle in bundles)
    {
        // FIXME: Once -[NSBundle pathsForResourcesOfType:inDirectory:] searches
        // language directories correctly on GNUstep, remove the inner loop below.

        /* Collect localized files according to the preferred localizations of
           the app or test runner tool (the main bundle in both cases) */
        for (NSString *localization in [NSBundle mainBundle].preferredLocalizations)
        {
            NSString *languageDirectory = languageDirectoryForLocalization(localization, bundle);
            NSString *localizedDirectory = [languageDirectory stringByAppendingPathComponent: @"Commits"];
            NSFileManager *fileManager = [NSFileManager defaultManager];
            BOOL isDir = NO;

            if (![fileManager fileExistsAtPath: localizedDirectory isDirectory: &isDir] || !isDir)
                continue;

            NSArray *localizedFiles = [fileManager contentsOfDirectoryAtPath: localizedDirectory
                                                                       error: NULL];
            ETAssert(localizedFiles != nil);
            localizedFiles = [localizedFiles mappedCollectionWithBlock: ^(NSString *subpath)
            {
                return [localizedDirectory stringByAppendingPathComponent: subpath];
            }];

            [commitsFiles addObjectsFromArray: [localizedFiles pathsMatchingExtensions: @[@"json"]]];
            [stringsFiles addObjectsFromArray: [localizedFiles pathsMatchingExtensions: @[@"strings"]]];
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

+ (void)initialize
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
+ (void)registerDescriptor: (COCommitDescriptor *)aDescriptor
{
    NILARG_EXCEPTION_TEST(aDescriptor);
    INVALIDARG_EXCEPTION_TEST(aDescriptor, [aDescriptor domain] != nil);
    INVALIDARG_EXCEPTION_TEST(aDescriptor,
                              [[aDescriptor domain] isEqual: [aDescriptor identifier]]);

    descriptorTable[aDescriptor.identifier] = aDescriptor;
}

+ (COCommitDescriptor *)registeredDescriptorForIdentifier: (NSString *)anIdentifier
{
    NILARG_EXCEPTION_TEST(anIdentifier);

    return descriptorTable[anIdentifier];
}

- (instancetype)initWithIdentifier: (NSString *)anId
                      propertyList: (NSDictionary *)plist
{
    SUPERINIT;
    _identifier = anId;
    _type = plist[@"type"];
    _shortDescription = plist[@"shortDescription"];
    return self;
}

- (NSString *)description
{
    return @{kCOCommitMetadataIdentifier: self.identifier,
             kCOCommitMetadataTypeDescription: self.typeDescription,
             kCOCommitMetadataShortDescription: self.shortDescription}.description;
}

- (NSString *)domain
{
    /* Turn 'org.etoile-project.ObjectManager.rename/shortDescription'  
       into 'org.etoile-project.ObjectManager' */

    /* Trim property suffix if present (e.g. /shortDescription) */

    NSArray *components = [self.identifier componentsSeparatedByString: @"/"];
    ETAssert(components.count == 1 || components.count == 2);
    NSString *idMinusProperty = components.firstObject;

    /* Trim operation suffix (e.g. .rename) */

    NSArray *subcomponents = [idMinusProperty componentsSeparatedByString: @"."];
    NSRange domainRange = NSMakeRange(0, subcomponents.count - 1);
    NSString *domain =
        [[subcomponents subarrayWithRange: domainRange] componentsJoinedByString: @"."];

    return domain;
}

- (NSString *)name
{
    return [self.identifier componentsSeparatedByString: @"."].lastObject;
}

- (NSString *)typeDescription
{
    return descriptorTypeTable[self.type];
}

- (NSString *)localizedTypeDescription
{
    NSString *localizationKey =
        [NSString stringWithFormat: @"types/%@/TypeDescription", self.type];
    return [self localizedStringForKey: localizationKey
                                 value: self.typeDescription
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
        [NSString stringWithFormat: @"descriptors/%@/ShortDescription", self.name];

    return [self localizedStringForKey: localizationKey
                                 value: self.shortDescription
                             arguments: [self localizedArgumentsFromArguments: args]];
}

+ (NSString *)localizedShortDescriptionFromMetadata: (NSDictionary *)metadata
{
    NSString *identifier = metadata[kCOCommitMetadataIdentifier];
    COCommitDescriptor *descriptor =
        identifier != nil ? [self registeredDescriptorForIdentifier: identifier] : nil;
    NSString *operationIdentifier = metadata[kCOCommitMetadataUndoType];
    NSString *description = nil;

    if (descriptor == nil)
    {
        description = metadata[kCOCommitMetadataShortDescription];
    }
    else
    {
        description = [descriptor localizedShortDescriptionWithArguments:
            metadata[kCOCommitMetadataShortDescriptionArguments]];
    }

    if (operationIdentifier != nil)
    {
        COCommitDescriptor *operationDescriptor =
            [COCommitDescriptor registeredDescriptorForIdentifier: operationIdentifier];
        NSString *validDescription = description != nil ? description : @"";

        return [operationDescriptor localizedShortDescriptionWithArguments: @[validDescription]];
    }
    else
    {
        return description;
    }
}

@end

NSString *const kCOCommitMetadataIdentifier = @"kCOCommitMetadataIdentifier";
NSString *const kCOCommitMetadataTypeDescription = @"kCOCommitMetadataTypeDescription";
NSString *const kCOCommitMetadataShortDescription = @"kCOCommitMetadataShortDescription";
NSString *const kCOCommitMetadataShortDescriptionArguments = @"kCOCommitMetadataShortDescriptionArguments";
NSString *const kCOCommitMetadataUndoBaseUUID = @"kCOCommitMetadataUndoBaseUUID";
NSString *const kCOCommitMetadataUndoType = @"kCOCommitMetadataUndoType";
NSString *const kCOCommitMetadataUndoInitialBaseInversed = @"kCOCommitMetadataUndoInitialBaseInversed";
