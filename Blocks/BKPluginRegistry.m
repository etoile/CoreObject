//
//  BKPluginRegistry.m
//  Blocks
//
//  Created by Jesse Grosjean on 1/5/05.
//  Copyright 2005 Hog Bay Software. All rights reserved.
//  Copyright 2007 Yen-Ju Chen.
//

#import "BKPluginRegistry.h"
#import "BKPlugin.h"
#import "BKExtensionPoint.h"
#import "BKExtension.h"
#import "BKRequirement.h"
#import "BKLog.h"

@interface BKPluginRegistry (BKPrivate)
- (NSMutableArray *)pluginSearchPaths;
- (void)registerPlugin:(BKPlugin *)plugin;
- (void)registerExtensionPointsFor:(BKPlugin *)plugin;
- (void)registerExtensionsFor:(BKPlugin *)plugin;
- (void)validatePluginConnections;
- (NSMutableDictionary *)pluginIDsToPlugins;
- (NSMutableDictionary *)extensionPointIDsToExtensionPoints;
- (NSMutableDictionary *)extensionPointIDsToExtensions;
- (NSMutableDictionary *)extensionPointIDsToLoadedValidOrderedExtensions;
@end

@implementation BKPluginRegistry

#pragma mark class methods

+ (void)initialize {
	if (self == [BKPluginRegistry class]) {
#if 0 // NOT_SUPPORTED
		ASKInitialize();
#endif
	}
}

+ (id)sharedInstance {
    static id sharedInstance = nil;
    if (sharedInstance == nil) {
        sharedInstance = [[self alloc] init];
    }
    return sharedInstance;
}

+ (void)performSelector:(SEL)selector forExtensionPoint:(NSString *)extensionPointID protocol:(Protocol *)protocol {
    BKPluginRegistry *pluginRegistery = [BKPluginRegistry sharedInstance];
    NSEnumerator *enumerator = [[pluginRegistery loadedValidOrderedExtensionsFor:extensionPointID protocol:protocol] objectEnumerator];
    BKExtension *each;
    
    while ((each = [enumerator nextObject])) {
		@try {
			[[each extensionInstance] performSelector:selector];
		} @catch ( NSException *exception ) {
			logErrorWithException(([NSString stringWithFormat:@"exception while processing extension point %@ \n %@", extensionPointID, nil]), exception);
		}
    }
}

#pragma mark init

- (id)init {
    if ((self = [super init])) {
    }
    return self;
}

/*!
	@method
	@discussion Scans for plugin bundles and registers them.
 */
- (void)scanPlugins {
    if (fScannedPlugins) {
		logWarn(@"scan plugins can only be run once.");
		return;
    } else {
		fScannedPlugins = YES;
    }
    
    fPluginIDsToPlugins = [[NSMutableDictionary alloc] init];
    fExtensionPointIDsToExtensionPoints = [[NSMutableDictionary alloc] init];
    fExtensionPointIDsToExtensions = [[NSMutableDictionary alloc] init];
    fExtensionPointIDsToLoadedValidOrderedExtensions = [[NSMutableDictionary alloc] init];
    NSBundle *blocksBundle = [NSBundle bundleForClass:[self class]];
    BKPlugin *blocskPlugin = [[BKPlugin alloc] initWithBundle:blocksBundle];

    [self registerPlugin:blocskPlugin];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableArray *pluginSearchPaths = [self pluginSearchPaths];
    NSString *eachSearchPath;
    
    while ((eachSearchPath = [pluginSearchPaths lastObject])) {
		[pluginSearchPaths removeLastObject];
		
		NSDirectoryEnumerator *directoryEnumerator = [fileManager enumeratorAtPath:eachSearchPath];
		NSString* eachPath;
		
		while ((eachPath = [directoryEnumerator nextObject])) {
			if ([[eachPath pathExtension] caseInsensitiveCompare:@"plugin"] == NSOrderedSame) {
				[directoryEnumerator skipDescendents];
				
				eachPath = [eachSearchPath stringByAppendingPathComponent:eachPath];
				
				NSBundle *bundle = [NSBundle bundleWithPath:eachPath];
				BKPlugin *plugin = [[BKPlugin alloc] initWithBundle:bundle];
				
				if (!plugin) {
					logError(([NSString stringWithFormat:@"failed to create plugin for path: %@", eachPath]));
				} else {
					[self registerPlugin:plugin];
					[pluginSearchPaths addObject:[bundle builtInPlugInsPath]]; // search within plugin for more
				}
			}
		}
    }
    
    [self validatePluginConnections];

    logAssert(fPluginIDsToPlugins != nil && fExtensionPointIDsToExtensionPoints != nil && fExtensionPointIDsToExtensions != nil, @"failed to load plugins into plugin registery");
}

- (void)loadMainExtension {
    NSArray *mainExtensions = [self extensionsFor:@"org.etoile-project.organizekit.main"];
    BKExtension *mainExtension = [mainExtensions lastObject];
    
    if ([mainExtensions count] > 1) {
		logWarn(([NSString stringWithFormat:@"found more then one plugin (%@) with a main extension point, loading only one from plugin %@", mainExtensions, [mainExtension plugin]]));
    } else if ([mainExtensions count] == 0) {
		logWarn((@"failed to find any plugin with a main extension point"));
    }
    
    [mainExtension extensionInstance];
}

#pragma mark dealloc

- (void)dealloc {
    [fPluginIDsToPlugins release];
    [fExtensionPointIDsToExtensionPoints release];
    [fExtensionPointIDsToExtensions release];
	[fExtensionPointIDsToLoadedValidOrderedExtensions release];
    [super dealloc];
}

#pragma mark accessors

- (NSArray *)plugins {
	NSSortDescriptor *sortDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"loadSequenceNumber" ascending:YES] autorelease];
    return [[[self pluginIDsToPlugins] allValues] sortedArrayUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
}

- (BKPlugin *)mainPlugin {
    NSArray *mainExtensions = [self extensionsFor:@"org.etoile-project.organizekit.main"];
    BKExtension *mainExtension = [mainExtensions lastObject];
	return [mainExtension plugin];
}

- (NSArray *)extensionPoints {
    return [[self extensionPointIDsToExtensionPoints] allValues];
}

- (NSArray *)extensions {
    NSMutableArray *extensions = [NSMutableArray array];
    NSEnumerator *enumerator = [[self plugins] objectEnumerator];
    BKPlugin *each;
    
    while ((each = [enumerator nextObject])) {
		[extensions addObjectsFromArray:[each extensions]];
    }
    
    return extensions;
}

#pragma mark lookup

- (BKPlugin *)pluginFor:(NSString *)pluginID {
    return [[self pluginIDsToPlugins] objectForKey:pluginID];
}

- (BKExtensionPoint *)extensionPointFor:(NSString *)extensionPointID {
    return [[self extensionPointIDsToExtensionPoints] objectForKey:extensionPointID];
}

- (NSArray *)extensionsFor:(NSString *)extensionPointID {
    return [[self extensionPointIDsToExtensions] objectForKey:extensionPointID];
}

- (NSArray *)loadedValidOrderedExtensionsFor:(NSString *)extensionPointID protocol:(Protocol *)protocol {
	NSMutableArray *loadedValidOrderedExtensions = [[self extensionPointIDsToLoadedValidOrderedExtensions] objectForKey:extensionPointID];
	
	if (!loadedValidOrderedExtensions) {
		NSEnumerator *enumerator = [[self extensionsFor:extensionPointID] objectEnumerator];
		BKExtension *each;

		loadedValidOrderedExtensions = [NSMutableArray array];
		[[self extensionPointIDsToLoadedValidOrderedExtensions] setObject:loadedValidOrderedExtensions forKey:extensionPointID];

		while ((each = [enumerator nextObject])) {
			if ([[each plugin] enabled]) {
				Class extensionClass = [each extensionClass];
				if ([extensionClass conformsToProtocol:protocol]) {
					[loadedValidOrderedExtensions addObject:each];
				} else {
					logError(([NSString stringWithFormat:@"extension %@ doesn't conform to protocol, skipping", each]));
				}
			}
		}

		[loadedValidOrderedExtensions sortedArrayUsingSelector:@selector(compareDeclarationOrder:)];
	}
	
	return loadedValidOrderedExtensions;
}

#pragma mark private

- (NSMutableArray *)pluginSearchPaths {
    NSMutableArray *pluginSearchPaths = [NSMutableArray array];
    NSString *applicationSupportSubpath = [NSString stringWithFormat:@"Application Support/%@/PlugIns", [[NSProcessInfo processInfo] processName]];
    NSEnumerator *searchPathEnumerator = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask - NSSystemDomainMask, YES) objectEnumerator];
    NSString *eachSearchPath;
    
    while((eachSearchPath = [searchPathEnumerator nextObject])) {
		[pluginSearchPaths addObject:[eachSearchPath stringByAppendingPathComponent:applicationSupportSubpath]];
    }
    
	NSEnumerator *bundleEnumerator = [[NSBundle allBundles] objectEnumerator];
	NSBundle *eachBundle;
	
	while ((eachBundle = [bundleEnumerator nextObject])) {
		[pluginSearchPaths addObject:[eachBundle builtInPlugInsPath]];
	}
	
    return pluginSearchPaths;
}

- (void)registerPlugin:(BKPlugin *)plugin {
    if ([fPluginIDsToPlugins objectForKey:[plugin identifier]] != nil) {
		logWarn(([NSString stringWithFormat:@"plugin id %@ not unique, replacing old with new", [plugin identifier]]));
    }
	
    [fPluginIDsToPlugins setObject:plugin forKey:[plugin identifier]];
    
    [self registerExtensionPointsFor:plugin];
    [self registerExtensionsFor:plugin];
}

- (void)registerExtensionPointsFor:(BKPlugin *)plugin {
    NSEnumerator *extensionPointsEnumerator = [[plugin extensionPoints] objectEnumerator];
    BKExtensionPoint *eachExtensionPoint;
    
    while ((eachExtensionPoint = [extensionPointsEnumerator nextObject])) {
		if ([fExtensionPointIDsToExtensionPoints objectForKey:[eachExtensionPoint identifier]]) {
			logWarn(([NSString stringWithFormat:@"extension point id %@ not unique, replacing old with new", [eachExtensionPoint identifier]]));
		}
		[fExtensionPointIDsToExtensionPoints setObject:eachExtensionPoint forKey:[eachExtensionPoint identifier]];
    }
}

- (void)registerExtensionsFor:(BKPlugin *)plugin {
    NSEnumerator *extensionsEnumerator = [[plugin extensions] objectEnumerator];
    BKExtension *eachExtension;
    
    while ((eachExtension = [extensionsEnumerator nextObject])) {
		NSString *extensionPointID = [eachExtension extensionPointID];
		
		NSMutableArray *extensions = [fExtensionPointIDsToExtensions objectForKey:extensionPointID];
		if (!extensions) {
			extensions = [NSMutableArray array];
			[fExtensionPointIDsToExtensions setObject:extensions forKey:extensionPointID];
		}
		
		[extensions addObject:eachExtension];
    }
}

- (void)validatePluginConnections {
    NSEnumerator *pluginEnumerator = [[self plugins] objectEnumerator];
    BKPlugin *eachPlugin;
    
    while ((eachPlugin = [pluginEnumerator nextObject])) {
		NSEnumerator *requirementsEnumerator = [[eachPlugin requirements] objectEnumerator];
		BKRequirement *eachRequirement;
		
		while ((eachRequirement = [requirementsEnumerator nextObject])) {
			if (![eachRequirement optional]) {
				if (![NSBundle bundleWithIdentifier:[eachRequirement bundleIdentifier]]) {
					logWarn(([NSString stringWithFormat:@"requirement bundle %@ not found for plugin %@", eachRequirement, eachPlugin]));
				}
			}
		}
    }
    
    NSEnumerator *extensionsEnumerator = [[self extensions] objectEnumerator];
    BKExtension *eachExtension;
    
    while ((eachExtension = [extensionsEnumerator nextObject])) {
		NSString *eachExtensionID = [eachExtension extensionPointID];
		BKExtensionPoint *extensionPoint = [self extensionPointFor:eachExtensionID];
		if (!extensionPoint) {
			logWarn(([NSString stringWithFormat:@"no extension point found for plugin %@'s extension %@", [eachExtension plugin], eachExtension]));
		}
    }
}

- (NSMutableDictionary *)pluginIDsToPlugins {
    if (!fPluginIDsToPlugins) {
		[self scanPlugins];
    }
    return fPluginIDsToPlugins;
}

- (NSMutableDictionary *)extensionPointIDsToExtensionPoints {
    if (!fExtensionPointIDsToExtensionPoints) {
		[self scanPlugins];
    }
    return fExtensionPointIDsToExtensionPoints;
}

- (NSMutableDictionary *)extensionPointIDsToExtensions {
    if (!fExtensionPointIDsToExtensions) {
		[self scanPlugins];
    }
    return fExtensionPointIDsToExtensions;
}

- (NSMutableDictionary *)extensionPointIDsToLoadedValidOrderedExtensions {
    if (!fExtensionPointIDsToLoadedValidOrderedExtensions) {
		[self scanPlugins];
    }
    return fExtensionPointIDsToLoadedValidOrderedExtensions;
}

@end
