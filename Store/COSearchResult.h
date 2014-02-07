/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  July 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>

@class ETUUID;

@interface COSearchResult : NSObject

@property (nonatomic, readwrite, strong) ETUUID *persistentRoot;
@property (nonatomic, readwrite, strong) ETUUID *revision;
@property (nonatomic, readwrite, strong) ETUUID *innerObjectUUID;

@end
