/**
	Copyright (C) 2013 Eric Wasylishen
 
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <Cocoa/Cocoa.h>

@class COAttributedString;

@interface COAttributedStringWrapper : NSTextStorage
{
	COAttributedString *_backing;
	NSUInteger _lastNotifiedLength;
	BOOL _inPrimitiveMethod;
	NSString *_cachedString;
	/**
	 * For tracking what we are observing with KVO,
	 * so we can unregister accurately.
	 */
	NSHashTable *_observedObjectsSet;
	
	// Debugging / Self-checks
	NSInteger _beginEditingStackDepth;
	NSInteger _lengthAtStartOfBatch;
	NSInteger _lengthDeltaInBatch;
}

- (instancetype) initWithBacking: (COAttributedString *)aBacking;

@property (nonatomic, readwrite, strong) COAttributedString *backing;

@end
