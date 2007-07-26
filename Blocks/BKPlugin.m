//
//  BKPlugin.m
//  Blocks
//
//  Created by Jesse Grosjean on 1/5/05.
//  Copyright 2005 Hog Bay Software. All rights reserved.
//

#import "BKPlugin.h"
#import "BKExtensionPoint.h"
#import "BKExtension.h"
#import "BKRequirement.h"
#import "BKLog.h"


@implementation BKPlugin

#pragma mark init

static int BKPluginLoadSequenceNumbers = 0;

- (id)initWithBundle:(NSBundle *)bundle {
    if ((self = [super init])) {
		fBundle = [bundle retain];
		
		if ([bundle isLoaded]) {
			fLoadSequenceNumber = BKPluginLoadSequenceNumbers++;
		} else {
			fLoadSequenceNumber = NSNotFound;
		}
		
		if (![self scanPluginXML]) {
			logError(([NSString stringWithFormat:@"failed scanPluginXML for bundle %@", [fBundle bundleIdentifier]]));
			[self release];
			return nil;
		}
    }
    return self;
}

#pragma mark dealloc

- (void)dealloc {
    [fBundle release];
    [fAttributes release];
    [fRequirements release];
    [fExtensionPoints release];
    [fExtensions release];
    [super dealloc];
}

#pragma mark accessors

- (NSString *)description {
    return [NSString stringWithFormat:@"id: %@ loadSequence: %i", [self identifier], [self loadSequenceNumber]];
}

- (NSBundle *)bundle {
    return fBundle;
}

- (NSString *)name {
    return [fAttributes objectForKey:@"name"];
}

- (NSString *)identifier {
    return [fAttributes objectForKey:@"id"];
}

- (NSString *)version  {
    return [fAttributes objectForKey:@"version"];
}

- (NSString *)providerName {
    return [fAttributes objectForKey:@"provider-name"];
}

- (NSArray *)requirements {
    return fRequirements;
}

- (NSArray *)extensionPoints {
    return fExtensionPoints;
}

- (NSArray *)extensions {
    return fExtensions;
}

- (NSString *)xmlPath {
	return [[self bundle] pathForResource:@"plugin" ofType:@"xml"];
}

- (NSString *)protocolsPath {
	return [[self bundle] pathForResource:[[[[self bundle] executablePath] lastPathComponent] stringByAppendingString:@"Protocols"] ofType:@"h"];
}

- (BOOL)enabled {
	return YES; // XXX should alwasy return no if application is not registered and plugin is not in application wrapper.
}

#pragma mark loading

- (BOOL)scanPluginXML {
    logAssert(fAttributes == nil && fRequirements == nil && fExtensionPoints == nil && fExtensions == nil, @"you can only loadPluginXML once");
    
    fRequirements = [[NSMutableArray alloc] init];
    fExtensionPoints = [[NSMutableArray alloc] init];
    fExtensions = [[NSMutableArray alloc] init];
    
    NSString *pluginXMLPath = [self xmlPath];
    
    if (!pluginXMLPath) {
		logError(([NSString stringWithFormat:@"failed to find plugin.xml resource for bundle %@", fBundle]));
		return NO;
    }
    
    NSXMLParser *xmlParser = [[[NSXMLParser alloc] initWithData:[NSData dataWithContentsOfFile:pluginXMLPath]] autorelease];
    
    [xmlParser setDelegate:self];
    
	if ([xmlParser parse]) {
		if (![[self identifier] isEqualToString:[fBundle bundleIdentifier]]) {
			logError(([NSString stringWithFormat:@"plugin id %@ doesn't match bundle id %@", [self identifier], [fBundle bundleIdentifier]]));
			return NO;
		}
	} else {
		logError(([NSString stringWithFormat:@"failed to parse plugin.xml file %@", pluginXMLPath]));
		return NO;
	}
	
    return YES;
}

- (int)loadSequenceNumber {
	return fLoadSequenceNumber;
}

- (BOOL)isLoaded {
	return [fBundle isLoaded];
}

- (BOOL)load {
    if (![fBundle isLoaded]) {
		if (![self enabled]) {
			logError(([NSString stringWithFormat:@"Failed to load plugin %@ because it isn't enabled.", [self identifier]]));
			return NO;
		}
		
		NSEnumerator *enumerator = [[self requirements] objectEnumerator];
		BKRequirement *eachImport;
		
		while ((eachImport = [enumerator nextObject])) {
			if (![eachImport isLoaded]) {
				if ([eachImport load]) {
					logInfo(([NSString stringWithFormat:@"Loaded code for requirement %@ by plugin %@", eachImport, [self identifier]]));
				} else {
					if ([eachImport optional]) {
						logError(([NSString stringWithFormat:@"Failed to load code for optioinal requirement %@ by plugin %@", eachImport, [self identifier]]));
					} else {
						logError(([NSString stringWithFormat:@"Failed to load code for requirement %@ by plugin %@", eachImport, [self identifier]]));
						logError(([NSString stringWithFormat:@"Failed to load code for plugin with identifier %@", [self identifier]]));
						return NO;
					}
				}
			}
		}
		
		if (![fBundle load]) {
			logError(([NSString stringWithFormat:@"Failed to load bundle with identifier %@", [self identifier]]));
			return NO;
		} else {
			fLoadSequenceNumber = BKPluginLoadSequenceNumbers++;
			logInfo(([NSString stringWithFormat:@"Loaded bundle with identifier %@", [self identifier]]));
		}
    }
    
    return YES;
}

#pragma mark xml parser delegate methods

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict {
    if ([elementName isEqual:@"plugin"]) {
		fAttributes = [attributeDict copy];
    } else if ([elementName isEqual:@"requirement"]) {
		[fRequirements addObject:[[[BKRequirement alloc] initWithIdentifier:[attributeDict objectForKey:@"bundle"]
														  version:[attributeDict objectForKey:@"version"]
														 optional:[[attributeDict objectForKey:@"optional"] isEqual:@"true"]] autorelease]];
    } else if ([elementName isEqual:@"extension-point"]) {
		[fExtensionPoints addObject:[[[BKExtensionPoint alloc] initWithPlugin:self
																   identifier:[NSString stringWithFormat:@"%@.%@", [self identifier], [attributeDict objectForKey:@"id"]]
																 protocolName:[attributeDict objectForKey:@"protocol"]] autorelease]];
    } else if ([elementName isEqual:@"extension"]) {
		[fExtensions addObject:[[[BKExtension alloc] initWithPlugin:self 
												   extensionPointID:[attributeDict objectForKey:@"point"]
												 extensionClassName:[attributeDict objectForKey:@"class"]] autorelease]];
    }
}

@end
