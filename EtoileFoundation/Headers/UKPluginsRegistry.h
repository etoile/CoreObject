/*
	UKPluginsRegistry.h
 
	Plugins manager class used to register new plugins and obtain already
    registered plugins
 
	Copyright (C) 2004 Uli Kusterer
 
	Author:  Uli Kusterer
             Quentin Mathe <qmathe@club-internet.fr>
	Date:  August 2004
 
	This library is free software; you can redistribute it and/or
	modify it under the terms of the GNU Lesser General Public
	License as published by the Free Software Foundation; either
	version 2.1 of the License, or (at your option) any later version.
 
	This library is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
	Lesser General Public License for more details.
 
	You should have received a copy of the GNU Lesser General Public
	License along with this library; if not, write to the Free Software
	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#import <Foundation/Foundation.h>


@interface UKPluginsRegistry : NSObject
{
	NSMutableArray          *plugins;		/* List of available plugins, with dictionaries for each. */
	NSMutableDictionary     *pluginPaths;	/* Key is file path, value is entry in plugins. */
    BOOL                    instantiate;    /* Instantiate the principal class of each plugin. */
}

+ (id) sharedRegistry;

- (void) loadPluginsOfType: (NSString *)ext;  /* Usually you only need to call this. */
- (void) loadPluginsFromPath: (NSString *)folder ofType: (NSString *)ext;
- (NSMutableDictionary *) loadPluginForPath: (NSString *)path; /* Returns dictionary for loaded plugin. */

- (NSArray *) loadedPlugins;  /* Array of plugin dictionaries. */

- (BOOL) instantiate;
- (void) setInstantiate: (BOOL)n;

@end

/*
    Each plugin is represented by an NSMutableDictionary to which you can add your
    own entries as needed. The keys UKPluginRegistry adds to this dictionary are:
    
    bundle      - NSBundle instance for this plugin.
    identifier  - Unique identifier for this plugin (bundle identifier in current implementation)
    image       - Icon (NSImage) of the plugin (for display in toolbars etc.)
    name        - Display name of the plugin (for display in lists, toolbars etc.)
    path        - Full path to the bundle.
    class       - NSValue containing pointer to the principal class (type Class)
                  for this bundle, so you can instantiate it.
    instance    - If instantiate == YES, this contains an instance of the principal
                  class, instantiated using alloc+init.
 */
