//
//  BKRequirement.m
//  Blocks
//
//  Created by Jesse Grosjean on 1/27/05.
//  Copyright 2005 Hog Bay Software. All rights reserved.
//

#import "BKRequirement.h"
#import "BKPluginRegistry.h"
#import "BKPlugin.h"
#import "BKLog.h"


@implementation BKRequirement

#pragma mark init

- (id)initWithIdentifier:(NSString *)identifier version:(NSString *)version optional:(BOOL)optional {
	if ((self = [super init])) {
		fBundleIdentifier = [identifier retain];
		fBundleVersion = [version retain];
		fOptional = optional;
	}
	return self;
}

#pragma mark dealloc

- (void)dealloc {
	[fBundleIdentifier release];
	[fBundleVersion release];
	[super dealloc];
}

#pragma mark accessors

- (NSString *)description {
    return [NSString stringWithFormat:@"bundleIdentifier: %@ optional: %i", [self bundleIdentifier], [self optional]];
}

- (BKPlugin *)requiredPlugin {
	return [[BKPluginRegistry sharedInstance] pluginFor:[self bundleIdentifier]];
}

- (NSBundle *)requiredBundle {
	return [NSBundle bundleWithIdentifier:[self bundleIdentifier]];
}

- (NSString *)bundleIdentifier {
	return fBundleIdentifier;
}

- (NSString *)bundleVersion {
	return fBundleVersion;
}

- (BOOL)optional {
	return fOptional;
}

#pragma mark loading

- (BOOL)isLoaded {
	BKPlugin *plugin = [self requiredPlugin];
	if (plugin) return [plugin isLoaded];
	NSBundle *bundle = [self requiredBundle];
	if (bundle) return [bundle isLoaded];
	return NO;
}

- (BOOL)load {
	BKPlugin *plugin = [self requiredPlugin];
	if (plugin) return [plugin load];
	NSBundle *bundle = [self requiredBundle];
	if (bundle) return [bundle load];
	return NO;
}

@end
