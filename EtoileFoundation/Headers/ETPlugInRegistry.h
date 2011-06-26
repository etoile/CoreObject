/**
	<abstract>Plug-in manager class used to register new plug-ins and obtain 
	already registered plug-ins</abstract>
 
	Copyright (C) 2004 Uli Kusterer
 
	Author:  Uli Kusterer
             Quentin Mathe <quentin.mathe@gmail.com>
	Date:  August 2004
	License:  Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>

/** @group Plug-Ins

Each plug-in is represented by an NSMutableDictionary to which you can add your
own entries as needed. The keys ETPlugInRegistry adds to this dictionary are:

<deflist>
<term>bundle</term>
<desc>NSBundle instance for this plug-in</desc>
<term>identifier</term>
<desc>Unique identifier for this plug-in (bundle identifier in current implementation), see -plugInIdentifierForBundle:</desc>
<term>image</term>
<desc>Icon (NSImage) of the plug-in (for display in toolbars etc.), see -plugInIconPathForBundle:</desc>
<term>name</term>
<desc>Display name of the plug-in (for display in lists, toolbars etc.), see -plugInNameForBundle:</desc>
<term>path</term>
<desc>Full path to the bundle.</desc>
<term>class</term>
<desc>Principal class (type Class) for this bundle, so you can instantiate it</desc>
<term>instance</term>
<desc>If -shouldInstantiatePlugInClass is YES, this contains an instance of the principal class, instantiated using alloc+init</desc>
</deflist>

ETPlugInRegistry is thread-safe. */
@interface ETPlugInRegistry : NSObject
{
	@private
	NSMutableArray *plugIns; /* List of available plug-ins, with dictionaries for each. */
	NSMutableDictionary *plugInPaths; /* Key is file path, value is entry in plug-ins. */
    BOOL shouldInstantiate; /* Instantiate the principal class of each plug-in. */
	NSLock *lock;
}

/** @taskunit Initialization */

+ (id) sharedRegistry;

/** @taskunit Loading Plug-Ins */

- (void) loadPlugInsOfType: (NSString *)ext; 
- (void) loadPlugInsFromPath: (NSString *)folder ofType: (NSString *)ext;
- (NSMutableDictionary *) loadPlugInAtPath: (NSString *)path;

/** @taskunit Accessing Plug-Ins */

- (NSArray *) loadedPlugIns;

/** @taskunit Loading Behavior */

- (BOOL) shouldInstantiatePlugInClass;
- (void) setShouldInstantiatePlugInClass: (BOOL)instantiate;

- (NSArray *) searchPaths;

/** @taskunit Retrieving Plug-In Schema Infos */

- (NSString *) plugInNameForBundle: (NSBundle *)bundle;
- (NSString *) plugInIdentifierForBundle: (NSBundle *)bundle;
- (NSString *) plugInIconPathForBundle: (NSBundle *)bundle;

@end

