// Needed to allow limits.h stuff to work in C++ (otherwise INTPTR_MAX is undefined)
#define __STDC_LIMIT_MACROS

#import "COStringDiff.h"
#include "diff.hh"

// For 100k characters:
// With NSString wrapper: 1.25s
// With direct buffer: 0.688s 
// diff: 0.063s

// For 130k characters: (encounters lots of unrelated text)
// direct buffer: 3.2s
// diff: 0.4s

class NSStringWrapper
{
private:
	unichar *buf1, *buf2;
public:
	bool equal(size_t i, size_t j)
	{
		return buf1[i] == buf2[j];
	}
	NSStringWrapper(NSString *s1, NSString *s2)
	{
		buf1 = new unichar[[s1 length]];
		buf2 = new unichar[[s2 length]];
		[s1 getCharacters: buf1 range: NSMakeRange(0, [s1 length])];
		[s2 getCharacters: buf2 range: NSMakeRange(0, [s2 length])];
	}
	~NSStringWrapper()
	{
		delete []buf1;
		delete []buf2;
	}
};


@implementation COStringDiff

- (id) initWithFirstString: (NSString *)first
              secondString: (NSString *)second
{
	NSMutableArray *operations = [NSMutableArray array];
	
	NSStringWrapper wrapper(first, second);
	std::vector<ManagedFusion::DifferenceItem> items = 
    ManagedFusion::Diff<NSStringWrapper>(wrapper, [first length], [second length]);
    
	for (std::vector<ManagedFusion::DifferenceItem>::iterator it = items.begin();
		 it != items.end();
		 it++)
	{
		NSRange firstRange = NSMakeRange((*it).rangeInA.location, (*it).rangeInA.length);
		NSRange secondRange = NSMakeRange((*it).rangeInB.location, (*it).rangeInB.length);
		
		switch ((*it).type)
		{
			case ManagedFusion::INSERTION:
				[operations addObject: [COStringDiffOperationInsert insertWithLocation: firstRange.location
																				string: [second substringWithRange: secondRange]]];
				break;
			case ManagedFusion::DELETION:
				[operations addObject: [COStringDiffOperationDelete deleteWithRange: firstRange]];
				break;
			case ManagedFusion::MODIFICATION:
				[operations addObject: [COStringDiffOperationModify modifyWithRange: firstRange
																		  newString: [second substringWithRange: secondRange]]];
				
				break;
		}
	}
	
	self = [super initWithOperations: operations];
	return self;
}

/**
 * Applys the receiver to the given mutable array
 */
- (void) applyTo: (NSMutableString*)string
{
	NSInteger i = 0;
	for (COSequenceDiffOperation *op in ops)
	{
		NSRange range = NSMakeRange([op range].location + i, [op range].length);
		if ([op isKindOfClass: [COStringDiffOperationInsert class]])
		{
			[string insertString: [(COStringDiffOperationInsert*)op insertedString] atIndex: range.location];
			i += [[(COStringDiffOperationInsert*)op insertedString] length];
		}
		else if ([op isKindOfClass: [COStringDiffOperationDelete class]])
		{
			[string replaceCharactersInRange:range withString: @""];
			i -= range.length;
		}
		else if ([op isKindOfClass: [COStringDiffOperationModify class]])
		{
			[string replaceCharactersInRange:range withString: [(COStringDiffOperationModify*)op insertedString]];
			i += ([[(COStringDiffOperationModify*)op insertedString] length] - range.length);
		}
		else
		{
			assert(0);
		}    
	}
}

- (NSString *)stringWithDiffAppliedTo: (NSString*)string
{
	NSMutableString *mutableString = [NSMutableString stringWithString:string];
	[self applyTo: mutableString];
	return mutableString;
}


/**
 * Applys the receiver to the given mutable array
 */
// - (void) applyToAttributedString: (NSMutableAttributedString*)string
// {
// 	NSDictionary *insertionAttribs = [NSDictionary dictionaryWithObjectsAndKeys:
// 									  [NSColor greenColor], NSForegroundColorAttributeName, 
// 									  [NSFont boldSystemFontOfSize: [NSFont systemFontSize]], NSFontAttributeName,
// 									  nil];
// 	
// 	NSDictionary *deletionAttribs = [NSDictionary dictionaryWithObjectsAndKeys:
// 									 [[NSColor redColor] colorWithAlphaComponent: 0.3], NSForegroundColorAttributeName, 
// 									 [NSNumber numberWithInteger: NSUnderlineStyleSingle], NSStrikethroughStyleAttributeName,
// 									 nil];
//     
// 	NSDictionary *modifyDeletionAttribs = [NSDictionary dictionaryWithObjectsAndKeys:
// 										   [[NSColor redColor] colorWithAlphaComponent: 0.3], NSForegroundColorAttributeName, 
// 										   [NSNumber numberWithInteger: NSUnderlineStyleSingle], NSStrikethroughStyleAttributeName,
// 										   nil];
// 	
// 	NSDictionary *modifyInsertionAttribs = [NSDictionary dictionaryWithObjectsAndKeys:
// 											[NSColor colorWithCalibratedRed:0 green:0.5 blue:0 alpha:1], NSForegroundColorAttributeName, 
// 											[NSFont boldSystemFontOfSize: [NSFont systemFontSize]], NSFontAttributeName,
// 											nil];
// 	
// 	
// 	NSInteger i = 0;
// 	for (COSequenceDiffOperation *op in ops)
// 	{
// 		NSRange range = NSMakeRange([op range].location + i, [op range].length);
// 		if ([op isKindOfClass: [COStringDiffOperationInsert class]])
// 		{
// 			NSAttributedString *insertion = 
// 			[[[NSAttributedString alloc] initWithString: [(COStringDiffOperationInsert*)op insertedString]
// 											 attributes: insertionAttribs] autorelease];
// 			[string insertAttributedString: insertion
// 								   atIndex: range.location];
// 			i += [[(COStringDiffOperationInsert*)op insertedString] length];
// 		}
// 		else if ([op isKindOfClass: [COStringDiffOperationDelete class]])
// 		{
// 			[string setAttributes:deletionAttribs range:range];
// 		}
// 		else if ([op isKindOfClass: [COStringDiffOperationModify class]])
// 		{
// 			[string setAttributes:modifyDeletionAttribs range:range];
// 			
// 			NSAttributedString *insertion = 
// 			[[[NSAttributedString alloc] initWithString: [(COStringDiffOperationModify*)op insertedString]
// 											 attributes: modifyInsertionAttribs] autorelease];
// 			[string insertAttributedString: insertion
// 								   atIndex: range.location + range.length];
// 			i += [[(COStringDiffOperationModify*)op insertedString] length];
// 		}
// 		else
// 		{
// 			assert(0);
// 		}    
// 	}
// }
// 
// - (NSAttributedString *)attributedStringWithDiffAppliedTo: (NSString*)string
// {
// 	NSMutableAttributedString *mutableString = [[NSMutableAttributedString alloc] initWithString: string];
// 	[self applyToAttributedString: mutableString];
// 	return [mutableString autorelease];
// }


@end



@implementation COStringDiffOperationInsert 

@synthesize insertedString;

+ (COStringDiffOperationInsert*)insertWithLocation: (NSUInteger)loc string: (NSString*)string
{
	COStringDiffOperationInsert *op = [[[COStringDiffOperationInsert alloc] init] autorelease];
	op->range = NSMakeRange(loc, 0);
	op->insertedString = [string retain];
	return op;
}

- (NSString *)description
{
	return [NSString stringWithFormat: @"Insert '%@' at %d", insertedString, range.location];
}

- (BOOL) isEqual: (id)other
{
	if ([other isKindOfClass: [COStringDiffOperationInsert class]])
	{
		COStringDiffOperationInsert *o = other;
		return NSEqualRanges([o range], [self range]) &&
		[[o insertedString] isEqual: [self insertedString]];
	}
	return NO;
}

- (void) dealloc
{
	[insertedString release];
	[super dealloc];
}
@end

@implementation COStringDiffOperationDelete

+ (COStringDiffOperationDelete*)deleteWithRange: (NSRange)range
{
	COStringDiffOperationDelete *op = [[[COStringDiffOperationDelete alloc] init] autorelease];
	op->range = range;
	return op;
}

- (NSString *)description
{
	return [NSString stringWithFormat: @"Delete '%@'", NSStringFromRange(range)];
}

- (BOOL) isEqual: (id)other
{
	if ([other isKindOfClass: [COStringDiffOperationDelete class]])
	{
		COStringDiffOperationDelete *o = other;
		return NSEqualRanges([o range], [self range]);
	}
	return NO;
}

@end

@implementation COStringDiffOperationModify

@synthesize insertedString;

+ (COStringDiffOperationModify*)modifyWithRange: (NSRange)range newString: (NSString*)string
{
	COStringDiffOperationModify *op = [[[COStringDiffOperationModify alloc] init] autorelease];
	op->range = range;
	op->insertedString = [string retain];
	return op;
}

- (NSString *)description
{
	return [NSString stringWithFormat: @"Modify '%@' to '%@'", NSStringFromRange(range), insertedString];
}

- (BOOL) isEqual: (id)other
{
	if ([other isKindOfClass: [COStringDiffOperationModify class]])
	{
		COStringDiffOperationModify *o = other;
		return NSEqualRanges([o range], [self range]) &&
		[[o insertedString] isEqual: [self insertedString]];
	}
	return NO;
}

- (void) dealloc
{
	[insertedString release];
	[super dealloc];
}

@end
