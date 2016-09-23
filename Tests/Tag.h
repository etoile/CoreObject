/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  August 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@interface Tag : COGroup

@property (nonatomic, readwrite, copy) NSString *label;
@property (nonatomic, readwrite, copy) NSSet *contents;

@property (nonatomic, readwrite, copy) NSSet *childTags;
@property (nonatomic, readonly, weak) Tag *parentTag;

@end
