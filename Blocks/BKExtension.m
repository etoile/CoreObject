//
//  BKExtension.m
//  Blocks
//
//  Created by Jesse Grosjean on 1/5/05.
//  Copyright 2005 Hog Bay Software. All rights reserved.
//

#import "BKExtension.h"
#import "BKPluginRegistry.h"
#import "BKPlugin.h"
#import "BKExtensionPoint.h"
#import "BKLog.h"


@implementation BKExtension

#pragma mark init

- (id)initWithPlugin:(BKPlugin *)plugin extensionPointID:(NSString *)extensionPointID extensionClassName:(NSString *)extensionClassName {
    if ((self = [super init])) {
		fPlugin = plugin;
		fExtensionPointID = [extensionPointID retain];
		fExtensionClassName = [extensionClassName retain];
		
		logAssert(fPlugin != nil, @"plugin can't be nil");
		logAssert(fExtensionPointID != nil, @"extension point id can't be nil");
		logAssert(fExtensionClassName != nil, @"class name can't be nil");
    }
    return self;
}

#pragma mark dealloc

- (void)dealloc {
    [fExtensionPointID release];
    [fExtensionClassName release];
    [fExtensionInstance release];
    [super dealloc];
}

#pragma mark accessors

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ point: %@ class: %@>", [self className], [self extensionPointID], [self extensionClassName]];
}

- (BKPlugin *)plugin {
    return fPlugin;
}

- (NSString *)extensionPointID {
    return fExtensionPointID;
}

- (BKExtensionPoint *)extensionPoint {
    BKExtensionPoint *extensionPoint = [[BKPluginRegistry sharedInstance] extensionPointFor:[self extensionPointID]];
    logAssert(extensionPoint != nil, @"failed to find extension point for id");
    return extensionPoint;
}

- (NSString *)extensionClassName {
    return fExtensionClassName;
}

- (Class)extensionClass {
    if (!fExtensionClass) {
		@try {
			if ([[self plugin] load]) {
				fExtensionClass = NSClassFromString([self extensionClassName]);
			}
			
			if (!fExtensionClass) {
				logError(([NSString stringWithFormat:@"Failed to load extension class %@", [self extensionClassName]]));
			} else {
				logInfo(([NSString stringWithFormat:@"Loaded extension class %@", [self extensionClassName]]));
			}
		} @catch (NSException *e) {
			logErrorWithException(([NSString stringWithFormat:@"threw exception %@ while loading class of extension %@", e, self]), e);
		}
    }
    
    return fExtensionClass;
}

- (id)extensionInstance {
    if (!fExtensionInstance) {
		fExtensionInstance = [[self extensionNewInstance] retain];
    }
    return fExtensionInstance;
}

- (id)extensionNewInstance {
	id newExtensionInstance = nil;
	
	@try {
		newExtensionInstance = [[[[self extensionClass] alloc] init] autorelease];
	} @catch (NSException *e) {
		logErrorWithException(([NSString stringWithFormat:@"threw exception %@ while loading instance of extension %@", e, self]), e);
		[newExtensionInstance release];
		newExtensionInstance = nil;
	}
	
	if (!newExtensionInstance) {
		logError(([NSString stringWithFormat:@"Failed to load extension instance of class %@", [self extensionClassName]]));
	} else {
		logInfo(([NSString stringWithFormat:@"Loaded extension instance %@", newExtensionInstance]));
	}
	
	return newExtensionInstance;
}

#pragma mark declaration order

- (NSComparisonResult)compareDeclarationOrder:(BKExtension *)extension {
	BKPlugin *plugin1 = [self plugin];
	BKPlugin *plugin2 = [extension plugin];
	
	if (plugin1 == plugin2) {
		int index1 = [[plugin1 extensions] indexOfObject:self];
		int index2 = [[plugin2 extensions] indexOfObject:extension];
		
		if (index1 < index2) {
			return NSOrderedAscending;
		} else if (index1 > index2) {
			return NSOrderedDescending;
		} else {
			return NSOrderedSame;
		}
	} else {
		int loadSequenceNumber1 = [plugin1 loadSequenceNumber];
		int loadSequenceNumber2 = [plugin2 loadSequenceNumber];
		
		if (loadSequenceNumber1 < loadSequenceNumber2) {
			return NSOrderedAscending;
		} else if (loadSequenceNumber1 > loadSequenceNumber2) {
			return NSOrderedDescending;
		} else {
			return NSOrderedSame;
		}
	}
}

@end
