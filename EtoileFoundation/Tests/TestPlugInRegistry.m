/*
	Copyright (C) 2004 Uli Kusterer
 
	Author:  Uli Kusterer
             Quentin Mathe <quentin.mathe@gmail.com>
	Date:  August 2004
	License:  Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "ETPlugInRegistry.h"
#import "ETCollection.h"
#import "Macros.h"
#import "EtoileCompatibility.h"

@interface ETPlugInRegistry (Private)
+ (NSString *) applicationSupportDirectoryName;
@end

@interface TestPlugInRegistry : NSObject <UKTest>
{
	ETPlugInRegistry *registry;
}

@end

@implementation TestPlugInRegistry

- (id) init
{
	SUPERINIT
	registry = [[ETPlugInRegistry alloc] init];
	return self;
}

- (void) dealloc
{
	DESTROY(registry);
	[super dealloc];
}

- (NSArray *) libraryDirectories
{
	return NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask, YES);
}

- (NSString *) plugInPath
{
#ifdef GNUSTEP
	NSString *plugInSubpath =  @"../Tests/PlugInExample/PlugInExample.plugin";
#else
	NSString *plugInSubpath =  @"../PlugInExample.plugin";
#endif
	return [[[[NSBundle bundleForClass: [self class]] bundlePath] 
		stringByAppendingPathComponent: plugInSubpath] stringByStandardizingPath];
}

- (void) checkBatchLoadPreconditionsForPath: (NSString *)plugInDir
{
	BOOL isDir;

	UKTrue([[NSFileManager defaultManager] fileExistsAtPath: plugInDir isDirectory: &isDir]);
	UKTrue(isDir);
	UKTrue([[registry loadedPlugIns] isEmpty]);
}

#ifdef TEST_PLUGIN_INSTALLED_IN_APP_SUPPORT
- (void) testLoadPlugInsOfType
{
	NSString *supportDir = [[[self libraryDirectories] firstObject] 
		stringByAppendingPathComponent: [ETPlugInRegistry applicationSupportDirectoryName]];

	[self checkBatchLoadPreconditionsForPath: supportDir];

	[self loadPlugInsOfType: @"plugin"];

	UKTrue([[registry loadedPlugIns] count] > 0);
}
#endif

- (void) checkPlugInLoadingPreconditionsForPath: (NSString *)path
{
	NSBundle *bundle = [NSBundle bundleWithPath: path];
	NSDictionary *info = [bundle infoDictionary];
	BOOL isDir;

	UKTrue([[NSFileManager defaultManager] fileExistsAtPath: path isDirectory: &isDir]);
	UKNotNil(bundle);
	UKNotNil(info);
	UKTrue([registry shouldInstantiatePlugInClass]);
}

- (void) testLoadPluginAtPathWithInstantiate
{
	[self checkPlugInLoadingPreconditionsForPath: [self plugInPath]];

	int initialCount = [[registry loadedPlugIns] count];    
	NSDictionary *plugIn = [registry loadPlugInAtPath: [self plugInPath]];

	UKIntsEqual(initialCount + 1, [[registry loadedPlugIns] count]);

	UKNotNil(plugIn);
	UKObjectKindOf([plugIn objectForKey: @"bundle"], NSBundle);
	// FIXME: UKObjectKindOf([plugIn objectForKey: @"image"], NSImage);
	UKStringsEqual(@"Plug-In Example", [plugIn objectForKey: @"name"]);
	UKStringsEqual([self plugInPath], [plugIn objectForKey: @"path"]);
	UKObjectsEqual(NSClassFromString(@"PlugInExample"), [plugIn objectForKey: @"class"]);
	UKNotNil([plugIn objectForKey: @"instance"]);

	/* Now ensure we don't load the same plug-in twice */

	NSDictionary *samePlugIn = [registry loadPlugInAtPath: [self plugInPath]];

	UKIntsEqual(initialCount + 1, [[registry loadedPlugIns] count]);
	UKObjectsSame(plugIn, samePlugIn);
}

- (void) testLoadPluginAtPathWithoutInstantiate
{
	[self checkPlugInLoadingPreconditionsForPath: [self plugInPath]];

	[registry setShouldInstantiatePlugInClass: NO];

	int initialCount = [[registry loadedPlugIns] count];
	NSDictionary *plugIn = [registry loadPlugInAtPath: [self plugInPath]];

	UKIntsEqual(initialCount + 1, [[registry loadedPlugIns] count]);

	UKNotNil(plugIn);
	UKObjectKindOf([plugIn objectForKey: @"bundle"], NSBundle);
	//FIXME: UKObjectKindOf([plugIn objectForKey: @"image"], NSImage);
	UKStringsEqual(@"Plug-In Example", [plugIn objectForKey: @"name"]);
	UKStringsEqual([self plugInPath], [plugIn objectForKey: @"path"]);
	UKObjectsEqual(NSClassFromString(@"PlugInExample"), [plugIn objectForKey: @"class"]);
	UKNil([plugIn objectForKey: @"instance"]);

	/* Now ensure we don't load the same plug-in twice, and we ignore 
	   'instantiate' change when the plug-in has already been loaded.  */

	[registry setShouldInstantiatePlugInClass: YES];

	NSDictionary *samePlugIn = [registry loadPlugInAtPath: [self plugInPath]];

	UKIntsEqual(initialCount + 1, [[registry loadedPlugIns] count]);
	UKObjectsSame(plugIn, samePlugIn);
	UKNil([plugIn objectForKey: @"instance"]);
}

@end
