/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>

/** All classes whose instances can be managed by CoreObject must conform to 
	this protocol. An object becomes a managed core object when it gets 
	referenced by an UUID in the metadata server.
	CoreObject provides two classes that adopt this protocol COProxy and 
	COObject related subclasses.*/
@protocol COManagedObject
- (NSString *) UUID;
- (id) localStore;
// TODO: We need to discuss the terminology here and differentiate between 
// metadatas (or persistent properties) and metadatas to be indexed (or 
// indexable persistent properties). 
- (NSDictionary *) metadatas;
@end

/* NSObject extensions */

@interface NSObject (CoreObject)

- (BOOL) isCoreObject;
- (BOOL) isManagedCoreObject;

@end
