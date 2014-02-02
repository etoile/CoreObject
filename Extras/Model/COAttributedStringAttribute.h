/*
    Copyright (C) 2013 Eric Wasylishen
 
    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@interface COAttributedStringAttribute : COObject

@property (nonatomic, readwrite, strong) NSString *htmlCode;

- (COItemGraph *) attributeItemGraph;

+ (BOOL) isAttributeSet: (NSSet *)aSet equalToSet: (NSSet *)anotherSet;
+ (NSSet *) attributeSet: (NSSet *)aSet minusSet: (NSSet *)anotherSet;

+ (COItemGraph *) attributeItemGraphForHTMLCode: (NSString *)aCode;

+ (BOOL) isAttributeItemGraph: (COItemGraph *)aGraph equalToItemGraph: (COItemGraph *)anotherGraph;

@end
