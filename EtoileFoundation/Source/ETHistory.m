/*
	Copyright (C) 2008 Truls Becken <truls.becken@gmail.com>

	Date:  December 2008
	License: Modified BSD (see COPYING)
 */

#import "ETHistory.h"
#import "EtoileCompatibility.h"
#import "Macros.h"

#define INCREMENT_HISTORY_INDEX\
	if (max_size < 1 || index < max_size) { ++index; }\
	else { [history removeObjectAtIndex: 0]; }

@implementation ETHistory

+ (id) history
{
	return AUTORELEASE([[self alloc] init]);
}

- (id) init
{
	SUPERINIT;
	history = [[NSMutableArray alloc] init];
	future = nil;
	max_size = 0;
	index = -1;
	return self;
}

- (void) dealloc
{
	DESTROY(history);
	DESTROY(future);
	[super dealloc];
}

- (void) addObject: (id)object
{
	[self setFuture: nil];
	INCREMENT_HISTORY_INDEX;
	[history addObject: object];
}

- (id) currentObject
{
	if (index < 0)
	{
		return nil;
	}
	return [history objectAtIndex: index];
}

- (void) back
{
	if (index > 0)
	{
		--index;
	}
}

- (id) previousObject
{
	if (index > 0)
	{
		--index;
		return [history objectAtIndex: index];
	}
	return nil;
}

- (BOOL) hasPrevious
{
	return index > 0;
}

- (void) forward
{
	if ([self hasNext] == YES)
	{
		INCREMENT_HISTORY_INDEX;
	}
}

- (id) nextObject
{
	if ([self hasNext] == YES)
	{
		INCREMENT_HISTORY_INDEX;
		return [history objectAtIndex: index];
	}
	return nil;
}

- (BOOL) hasNext
{
	if (index < (int)[history count] - 1)
	{
		return YES;
	}

	id object = [future nextObject];

 	if (object != nil)
	{
		[history addObject: object];
		return YES;
	}
	else
	{
		DESTROY(future);
		return NO;
	}
}

- (id) peek: (int)relativeIndex
{
	int peekIndex = index + relativeIndex;

	if (peekIndex < 0)
	{
		return nil;
	}

	for (int i = peekIndex - [history count] + 1; i > 0; i--)
	{
		id object = [future nextObject];

		if (object != nil)
		{
			[history addObject: object];
		}
		else
		{
			DESTROY(future);
			return nil;
		}
	}

	return [history objectAtIndex: peekIndex];
}

- (void) clear
{
	[history removeAllObjects];
	DESTROY(future);
	index = -1;
}

- (void) setFuture: (NSEnumerator *)enumerator
{
	NSRange toEnd = NSMakeRange(index + 1, [history count]);
	[history removeObjectsInRange: toEnd];
	ASSIGN(future, enumerator);
}

- (void) setMaxHistorySize: (int)maxSize
{
	max_size = maxSize;

	if (maxSize > 0 && index > maxSize)
	{
		NSRange range = NSMakeRange(0, index - maxSize);
		[history removeObjectsInRange: range];
		index = maxSize;
	}
}

- (int) maxHistorySize
{
	return max_size;
}

- (NSString *) displayName
{
	return _(@"History");
}

- (BOOL) isOrdered
{
	return YES;
}

- (BOOL) isEmpty
{
	return ([history count] == 0);
}

- (id) content
{
	return history;
}

- (NSArray *) contentArray
{
	return [NSArray arrayWithArray: history];
}

@end
