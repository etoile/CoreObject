//
//  BKExtensionPoint.h
//  Blocks
//
//  Created by Jesse Grosjean on 1/5/05.
//  Copyright 2005 Hog Bay Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class BKPlugin;

@interface BKExtensionPoint : NSObject {
    BKPlugin *fPlugin;
    NSString *fIdentifier;
    NSString *fProtocolName;
}

#pragma mark init

- (id)initWithPlugin:(BKPlugin *)plugin identifier:(NSString *)identifier protocolName:(NSString *)protocolName;

#pragma mark accessors

- (BKPlugin *)plugin;
- (NSString *)identifier;
- (NSString *)protocolName;
- (NSArray *)extensions;

@end
