/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  July 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>

@class ETUUID;

NS_ASSUME_NONNULL_BEGIN

@interface COSearchResult : NSObject

@property (nonatomic, readwrite, copy) ETUUID *persistentRoot;
@property (nonatomic, readwrite, copy) ETUUID *revision;
@property (nonatomic, readwrite, copy, nullable) ETUUID *innerObjectUUID;

@end

NS_ASSUME_NONNULL_END
