//
//  BKPlugin.h
//  Blocks
//
//  Created by Jesse Grosjean on 1/5/05.
//  Copyright 2005 Hog Bay Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface BKPlugin : NSObject {
    NSBundle *fBundle;
    NSDictionary *fAttributes;
    NSMutableArray *fRequirements;
    NSMutableArray *fExtensionPoints;
    NSMutableArray *fExtensions;
	int fLoadSequenceNumber;
}

#pragma mark init

- (id)initWithBundle:(NSBundle *)bundle;

#pragma mark accessors

- (NSBundle *)bundle;
- (NSString *)name;
- (NSString *)identifier;
- (NSString *)version;
- (NSString *)providerName;
- (NSArray *)requirements;
- (NSArray *)extensionPoints;
- (NSArray *)extensions;
- (NSString *)xmlPath;
- (NSString *)protocolsPath;
- (BOOL)enabled;

#pragma mark loading

- (BOOL)scanPluginXML;
- (int)loadSequenceNumber;
- (BOOL)isLoaded;
- (BOOL)load;

@end

