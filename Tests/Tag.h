/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  August 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@interface Tag : COGroup

@property (nonatomic, readwrite, strong) NSString *label;
@property (nonatomic, readwrite, strong) NSSet *contents;

@property (nonatomic, readwrite, strong) NSSet *childTags;
@property (nonatomic, readonly, weak) Tag *parentTag;

@end
