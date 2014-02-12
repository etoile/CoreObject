/**
    Copyright (C) 2013 Eric Wasylishen
 
    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@interface COAttributedStringAttribute : COObject

/**
 * e.g. font-weight
 */
@property (nonatomic, readwrite, strong) NSString *styleKey;
/**
 * e.g. bold
 */
@property (nonatomic, readwrite, strong) NSString *styleValue;

- (COItemGraph *) attributeItemGraph;

+ (BOOL) isAttributeSet: (NSSet *)aSet equalToSet: (NSSet *)anotherSet;
+ (NSSet *) attributeSet: (NSSet *)aSet minusSet: (NSSet *)anotherSet;

+ (COItemGraph *) attributeItemGraphForStyleKey: (NSString *)aKey styleValue: (NSString *)aValue;

+ (BOOL) isAttributeItemGraph: (COItemGraph *)aGraph equalToItemGraph: (COItemGraph *)anotherGraph;

- (BOOL) isDeeplyEqualToAttribute: (COAttributedStringAttribute *)anAttribute;

@end
