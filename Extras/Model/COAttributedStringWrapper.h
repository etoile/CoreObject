/**
	Copyright (C) 2013 Eric Wasylishen
 
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#if (TARGET_OS_IPHONE)
#	import <CoreObject/COCocoaTouchCompatibility.h>
#else
#	import <AppKit/AppKit.h>
#	if defined(GNUSTEP) || MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_11
#		define NSTextStorageEditActions NSUInteger
#	endif
#endif

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
