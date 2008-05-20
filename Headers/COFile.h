/*
   Copyright (C) 2008 Quentin Mathé <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import "COObject.h"


@interface COFile : NSObject <COObject>
{
	NSURL *_url;
	BOOL _isCopyPromise;
}

+ (id) objectWithURL: (NSURL *)url;

- (NSString *) uniqueID;
- (NSURL *) URL;
- (NSArray *) properties;
- (NSDictionary *) metadatas;
- (NSString *) name;
- (NSString *) displayName;
- (NSImage *) icon;
//- (NSData *) content;
//- (NSString *) textContent;

- (BOOL) exists;
- (BOOL) create;
- (BOOL) delete;
//- (BOOL) moveToTrash;

- (BOOL) isCopyPromise;

/* Use reserved to COGroup conforming classes */
- (void) didRemoveFromGroup: (id)group;
- (void) didAddToGroup: (id)group;

@end
