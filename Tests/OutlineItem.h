/*
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  August 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@interface OutlineItem : COContainer

@property (nonatomic, readwrite, assign) BOOL isShared;
@property (nonatomic, readwrite, strong) NSString *label;
@property (nonatomic, readwrite, copy) NSArray *contents;
@property (nonatomic, readonly, weak) OutlineItem *parentContainer;
@property (nonatomic, readonly, weak) NSSet *parentCollections;
@property (nonatomic, readwrite, assign, getter=isChecked) BOOL checked;
@property (nonatomic, readwrite, strong) COAttachmentID *attachmentID;

@end

/* OutlineItem variant to test a composite/container transient relationship */
@interface TransientOutlineItem : COContainer

@property (nonatomic, readwrite, copy) NSArray *contents;
@property (nonatomic, readwrite, weak) TransientOutlineItem *parentContainer;

@end

