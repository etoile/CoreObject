//
//  BKPluginRegistry.h
//  Blocks
//
//  Created by Jesse Grosjean on 1/5/05.
//  Copyright 2005 Hog Bay Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class BKPlugin;
@class BKExtensionPoint;

/*!
	@class BKPluginRegistry
	@discussion The BKPluginRegistry is responsible for finding and loading plugins. 
*/
@interface BKPluginRegistry : NSObject {
    NSMutableDictionary *fPluginIDsToPlugins;
    NSMutableDictionary *fExtensionPointIDsToExtensionPoints;
    NSMutableDictionary *fExtensionPointIDsToExtensions;
    NSMutableDictionary *fExtensionPointIDsToLoadedValidOrderedExtensions;
    BOOL fScannedPlugins;
}

#pragma mark class methods

+ (id)sharedInstance;
+ (void)performSelector:(SEL)selector forExtensionPoint:(NSString *)extensionPointID protocol:(Protocol *)protocol;

#pragma mark init

- (void)scanPlugins;
- (void)loadMainExtension;

#pragma mark accessors

- (NSArray *)plugins;
- (BKPlugin *)mainPlugin;
- (NSArray *)extensionPoints;
- (NSArray *)extensions;

#pragma mark lookup

- (BKPlugin *)pluginFor:(NSString *)pluginID;
- (BKExtensionPoint *)extensionPointFor:(NSString *)extensionPointID;
- (NSArray *)extensionsFor:(NSString *)extensionPointID;
- (NSArray *)loadedValidOrderedExtensionsFor:(NSString *)extensionPointID protocol:(Protocol *)protocol;

@end
