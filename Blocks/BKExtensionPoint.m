//
//  BKExtensionPoint.m
//  Blocks
//
//  Created by Jesse Grosjean on 1/5/05.
//  Copyright 2005 Hog Bay Software. All rights reserved.
//

#import "BKExtensionPoint.h"
#import "BKPluginRegistry.h"
#import "BKPlugin.h"
#import "BKLog.h"


@implementation BKExtensionPoint

#pragma mark init

- (id)initWithPlugin:(BKPlugin *)plugin identifier:(NSString *)identifier protocolName:(NSString *)protocolName {
    if ((self = [super init])) {
		fPlugin = plugin;
		fIdentifier = [identifier retain];
		fProtocolName = [protocolName retain];
		
		logAssert(fPlugin != nil, @"plugin can't be nil");
		logAssert(fIdentifier != nil, @"extension point identifier can't be nil");
		logAssert(fProtocolName != nil, @"protocol name can't be nil");
    }
    return self;
}

#pragma mark dealloc

- (void)dealloc {
    [fIdentifier release];
    [fProtocolName release];
    [super dealloc];
}

#pragma mark accessors

- (NSString *)description {
    return [NSString stringWithFormat:@"id: %@", [self identifier]];
}

- (BKPlugin *)plugin {
    return fPlugin;
}

- (NSString *)identifier {
    return fIdentifier;
}

- (NSString *)protocolName {
    return fProtocolName;
}

- (NSArray *)extensions {
    return [[BKPluginRegistry sharedInstance] extensionsFor:[self identifier]];
}

@end
