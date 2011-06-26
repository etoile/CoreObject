/*
	Copyright (C) 2004 Uli Kusterer
 
	Author:  Uli Kusterer
             Quentin Mathe <quentin.mathe@gmail.com>
	Date:  August 2004
	License:  Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>
#import "ETPlugInRegistry.h"
#import "ETCollection+HOM.h"
#import "Macros.h"
#import "EtoileCompatibility.h"

static NSFileManager *fm = nil;
static ETPlugInRegistry *sharedPluginRegistry = nil;

@implementation ETPlugInRegistry

+ (NSString *) applicationSupportDirectoryName
{
#ifdef GNUSTEP
	return @"ApplicationSupport";
#else
	return @"Application Support";
#endif
}

+ (void) initialize
{
	if ([self class] != [ETPlugInRegistry class])
		return;

	fm = [NSFileManager defaultManager];
	sharedPluginRegistry = [[ETPlugInRegistry alloc] init];
}

/** Returns UKPluginsRegistry shared instance (singleton). */
+ (id) sharedRegistry
{
	return sharedPluginRegistry;
}

/** <init />
Initializes and returns a new registry.

You should use +sharedRegistry rather than -init, unless you plan to use 
multiple registries at the same time, or implement a subclass that creates its 
own singleton. */
- (id) init
{
	SUPERINIT
	plugIns = [[NSMutableArray alloc] init];
	plugInPaths = [[NSMutableDictionary alloc] init];
    shouldInstantiate = YES;
	lock = [[NSLock alloc] init];
	return self;
}

- (void) dealloc
{
	[plugIns release];
	[plugInPaths release];
	[lock release];
	[super dealloc];
}

// TODO: Implement UTI check support for type parameter.
/** Locates and loads plug-in bundles with extension <var>ext</var> in the
application-dedicated directory inside the Application Support directory.

If the application's name (taken from NSExecutable in the plist package) is 
'Typewriter', then Library/ApplicationSupport/Typewriter will be searched. 
This search will be repeated in each library per domain (user, system etc.).<br />
This method takes in account the naming variation of the system directories 
between GNUstep and Mac OS X (e.g. Application Support vs ApplicationSupport).<br />
See -searchPaths.

If the executable is a tool rather than an application, does nothing.

Normally this is the only method you need to call to load a plug-in.

Raises an NSInvalidArgumentException if ext is nil. */
- (void) loadPlugInsOfType: (NSString *)ext
{
	NILARG_EXCEPTION_TEST(ext);

	FOREACH([self searchPaths], path, NSString *)
	{
		[self loadPlugInsFromPath: path ofType: ext];
	}
	[self loadPlugInsFromPath: [[NSBundle mainBundle] builtInPlugInsPath] ofType: ext];
}

// TODO: Implement UTI check support for type parameter.
/** Finds plug-ins within <var>folder</var> path which are identified by an 
extension matching <var>ext</var>. Finally loads these plug-ins by calling 
-loadPlugInAtPath:.

Raises an NSInvalidArgumentException if folder or ext is nil.*/
- (void) loadPlugInsFromPath: (NSString *)folder ofType: (NSString *)ext
{
	NILARG_EXCEPTION_TEST(folder);
	NILARG_EXCEPTION_TEST(ext);

	NSDirectoryEnumerator *e = [fm enumeratorAtPath: folder];
	NSString *fileName = nil;

	while ((fileName = [e nextObject]) != nil )
	{
		[e skipDescendents];

		BOOL isHidden = ([fileName characterAtIndex: 0] == '.');
		BOOL isRequestedType = [[fileName pathExtension] isEqualToString: ext];

		if (isHidden || isRequestedType == NO)
			continue;

		NS_DURING

			[self loadPlugInAtPath: [folder stringByAppendingPathComponent: fileName]];
            
		NS_HANDLER

			NSLog(@"WARNING: Failed to load plug-ins at path %@ - %@", 
				folder, localException);

		NS_ENDHANDLER
	}
}

/* EtoileUI overrides this private method with a category to implement the 
image loading that requires the AppKit. */
- (id) loadIconForPath: (NSString *)aString
{
	return nil;
}

/** Returns the paths where plug-ins should be searched by -loadPlugInsOfType:.

If the executable is a tool rather than an application, returns an empty array.

TODO: Allow to customize search paths. */
- (NSArray *) searchPaths
{
	NSBundle *bundle = [NSBundle mainBundle];
    NSArray *basePaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask, YES);
	NSString *appName = [[bundle infoDictionary] objectForKey: @"NSExecutable"];
    if (appName == nil)
	{
        appName = [[bundle infoDictionary] objectForKey: @"CFBundleExecutable"];
	}
	/* The main bundle corresponds surely to a tool */
	if (appName == nil)
	{
		return [NSArray array];
	}
	NSString *plugInDir = [[[[self class] applicationSupportDirectoryName] 
		stringByAppendingPathComponent: appName] 
        stringByAppendingPathComponent: @"PlugIns"];

	return (id)[[basePaths mappedCollection] stringByAppendingPathComponent: plugInDir];
}

/** Returns the plug-in name from the given bundle info dictionary.

Valid <em>name</em> keys in the plug-in property list are:

<list>
<item>CFBundleName</item>
<item>NSPrefPaneIconLabel</item>
<item>ApplicationName</item>
<item>NSExecutable</item>
</list>

If there is no valid key, returns <em>Unknown</em>. */
- (NSString *) plugInNameForBundle: (NSBundle *)bundle
{
	NSString *name = [[bundle infoDictionary] objectForKey: @"CFBundleName"];

	if (name == nil)
	{
		name = [[bundle infoDictionary] objectForKey: @"NSPrefPaneIconLabel"];
	}
	if (name == nil)
	{
		name = [[bundle infoDictionary] objectForKey: @"ApplicationName"];
	}
	if (name == nil)
	{
		name = [[bundle infoDictionary] objectForKey: @"NSExecutable"];
	}
	if (name == nil)
	{
		name = @"Unknown";
	}

	return name;
}

/** Returns the plug-in identifier from the given bundle info dictionary.

Valid <em>identifier</em> keys in the plug-in property list are:

<list>
<item>CFBundleIdentifier</item>
</list>

If there is no valid key, returns the bundle path. */
- (NSString *) plugInIdentifierForBundle: (NSBundle *)bundle
{
	NSString *identifier = [bundle bundleIdentifier];
	
	if (identifier == nil)
	{
		NSLog(@"WARNING: Plug-in %@ has no identifier, path will be used %@ in this role.", 
			identifier, [bundle bundlePath]);

		identifier = [bundle bundlePath];
	}

	return identifier;
}

/** Returns the plug-in icon path from the given bundle info dictionary.

Valid <em>image</em> path keys in the plug-in property list are:

<list>
<item>CFBundleIcon</item>
<item>NSPrefPaneIconFile</item>
<item>NSIcon</item>
<item>NSApplicationIcon</item>
</list>

If there is no valid key, returns nil. */
- (NSString *) plugInIconPathForBundle: (NSBundle *)bundle
{
	NSString *iconPath = [[bundle infoDictionary] objectForKey: @"CFBundleIcon"];

	if (iconPath == nil)
	{
		[[bundle infoDictionary] objectForKey: @"NSPrefPaneIconFile"];;
	}
	if (iconPath == nil)
	{
		iconPath = [[bundle infoDictionary] objectForKey: @"NSIcon"];
	}
	if (iconPath == nil)
	{
		iconPath = [[bundle infoDictionary] objectForKey: @"ApplicationIcon"];
	}

	return iconPath;
}

/** Loads the plug-in bundle located at <var>path</var>.

If the plug-in has already been loaded, immediately returns the same plug-in 
than previously .

Every property list values associated to the plug-in schema, detailed in 
ETPlugInRegistry class description, are put in a dictionary which represents a 
plug-in object; eventual validity errors may be reported each time a value is 
read in NSBundle description values returned by -infoDictionary.

Raises an NSInvalidArgumentException if path is nil. */
- (NSMutableDictionary *) loadPlugInAtPath: (NSString *)path
{
	[lock lock];

	NILARG_EXCEPTION_TEST(path);

	NSMutableDictionary *info = [plugInPaths objectForKey: path];

    // TODO: Implement plug-in schema conformance test in a dedicated method. 
	// We would be able to call it in subclasses to validate plug-ins in a 
	// specific method e.g. -validatePreferencePane.
	// If useful, a custom plug-in schema could be provided with the bundle plist.

	if (info != nil)
		return info;

	NSBundle *bundle = [NSBundle bundleWithPath: path];
	NSString *name = [self plugInNameForBundle: bundle];
	NSString *identifier = [self plugInIdentifierForBundle: bundle];
	NSString *iconPath = [self plugInIconPathForBundle: bundle];
	id image = [self loadIconForPath: iconPath];
	
	/* When image loading has failed, we set its value to null object in
	   in order to be able to create info dictionary without glitches a
	   'nil' value would produce (like subsequent elements being ignored). */
	if (image == nil)
	{
		image = [NSNull null];
	}

	info = [NSMutableDictionary dictionaryWithObjectsAndKeys: bundle, @"bundle", 
		identifier, @"identifier", image, @"image", name, @"name", path, @"path", 
		[bundle principalClass], @"class", nil];

	if ([self shouldInstantiatePlugInClass])
	{
		if ([bundle principalClass] == Nil)
		{
			[NSException raise: @"ETInvalidPlugInException"
			            format: @""];
		}
		id obj = [[[[bundle principalClass] alloc] init] autorelease];
		
		[info setObject: obj forKey: @"instance"];
	}
	[plugIns addObject: info];
	[plugInPaths setObject: info forKey: path];

	[lock unlock];

	return info;
}

/** Returns the currently registered plug-ins (loaded by the way).

An empty array is returned when no plug-ins have been registered. */
- (NSArray *) loadedPlugIns
{
	return plugIns;
}

/** Returns whether plug-in class should be instantiated at loading time by 
the registry.

By default, returns YES.

Read -setShouldInstantiatePlugInClass: documentation to learn more. */
- (BOOL)  shouldInstantiatePlugInClass
{
    return shouldInstantiate;
}

/** Sets to YES if you want to have plug-in main class automatically 
instantiated when they are loaded, otherwise it's your responsability to 
retrieve the plug-in class and instantiate it. This is especially useful if 
a custom initializer is required to make the instantiation. For example:

<example>
Class plugInClass = [[registry loadPlugInAtPath: path] objectForKey: @"class"];
CustomObject *mainObject = [[plugInClass alloc] initWithCity: @"Somewhere"];
</example> */
- (void) setShouldInstantiatePlugInClass: (BOOL)instantiate
{
    shouldInstantiate = instantiate;
}

@end
