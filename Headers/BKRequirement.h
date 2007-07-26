//
//  BKRequirement.h
//  Blocks
//
//  Created by Jesse Grosjean on 1/27/05.
//  Copyright 2005 Hog Bay Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class BKPlugin;

// Imports define the requirements for a plugin to load. If a plugins imports are not satisfied then the plugins code will not load. Optional imports constrain the load order of plugins. A plugins optional imports will always be loaded before the plugin of they exist.
@interface BKRequirement : NSObject {
	NSString *fBundleIdentifier;
	NSString *fBundleVersion;
	BOOL fOptional;
}

#pragma mark init

- (id)initWithIdentifier:(NSString *)identifier version:(NSString *)version optional:(BOOL)optional;

#pragma mark accessors

- (BKPlugin *)requiredPlugin;
- (NSBundle *)requiredBundle;
- (NSString *)bundleIdentifier;
- (NSString *)bundleVersion;
- (BOOL)optional;

#pragma mark loading

- (BOOL)isLoaded;
- (BOOL)load;

@end
