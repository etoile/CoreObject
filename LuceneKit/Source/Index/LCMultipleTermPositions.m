#include "LCMultipleTermPositions.h"
#include "LCPriorityQueue.h"
#include "GNUstep.h"

/**
* Describe class <code>MultipleTermPositions</code> here.
 *
 * @author Anders Nielsen
 * @version 1.0
 */
@interface LCTermPositionsQueue: LCPriorityQueue
- (id) initWithTermPositions: (NSArray *) termPositions;
- (id <LCTermPositions>) peek;
@end

@implementation LCTermPositionsQueue
- (id) initWithTermPositions: (NSArray *) termPositions
{
	self = [super initWithSize: [termPositions count]];
	NSEnumerator *e = [termPositions objectEnumerator];
	id <LCTermPositions> tp;
	while((tp = [e nextObject]))
	{
		if ([tp hasNextDocument])
			[self put:tp];
	}
	return self;
}

- (id <LCTermPositions>) peek
{
	return (id <LCTermPositions>)[self top];
}

@end

@interface LCIntQueue: NSObject
{
	int _arraySize;
	int _index;
	int _lastIndex;
	NSMutableArray *_array;
}

- (void) add: (int) i;
- (int) next;
- (void) sort;
- (void) clear;
- (int) size;
- (void) growArray;

@end


@implementation LCIntQueue
- (id) init
{
	self = [super init];
	_arraySize = 16;
	_index = 0;
	_lastIndex = 0;
	_array = [[NSMutableArray alloc] init];
	return self;
}

- (void) dealloc
{
	DESTROY(_array);
	[super dealloc];
}

- (void) add: (int) i
{
	if (_lastIndex == _arraySize)
		[self growArray];
	[_array addObject: [NSNumber numberWithInt: i]];
	_lastIndex++;
}

- (int) next
{
	return [[_array objectAtIndex: _index++] intValue];
}

- (void) sort
{
	[_array sortUsingSelector: @selector(compare:)];
}

- (void) clear
{
	_index = 0;
	_lastIndex = 0;
	[_array removeAllObjects];
}

- (int) size
{
	return (_lastIndex - _index);
}

- (void) growArray
{
	_arraySize *= 2;
}

@end

@implementation LCMultipleTermPositions
/**
* Creates a new <code>MultipleTermPositions</code> instance.
 *
 * @param indexReader an <code>IndexReader</code> value
 * @param terms a <code>Term[]</code> value
 * @exception IOException if an error occurs
 */
- (id) initWithIndexReader: (LCIndexReader *) indexReader
					 terms: (NSArray *) terms
{
	self = [super init];
	NSMutableArray *termPositions = [[NSMutableArray alloc] init];
	int i;
	for (i = 0; i < [terms count]; i++)
		[termPositions addObject: [indexReader termPositionsWithTerm: [terms objectAtIndex: i] ]];
	
	_termPositionsQueue = [[LCTermPositionsQueue alloc] initWithTermPositions: termPositions];
	_posList = [[LCIntQueue alloc] init];
        DESTROY(termPositions);
	return self;
}

- (void) dealloc
{
	DESTROY(_termPositionsQueue);
	DESTROY(_posList);
	[super dealloc];
}

- (BOOL) hasNextDocument
{
	if ([_termPositionsQueue size] == 0)
		return NO;
	
	[_posList clear];
	_doc = [[_termPositionsQueue peek] document];
	
	id <LCTermPositions> tp;
	do
	{
  	    tp = [_termPositionsQueue peek];
		
		int i;
	    for (i=0; i< [tp frequency]; i++)
			[_posList add: [tp nextPosition]];
		
	    if ([tp hasNextDocument])
			[_termPositionsQueue adjustTop];
	    else
	    {
			[_termPositionsQueue pop];
			[tp close];
	    }
	}
	while ([_termPositionsQueue size] > 0 && [[_termPositionsQueue peek] document] == _doc);
	
	[_posList sort];
	_freq = [_posList size];
	
	return YES;
}

- (int) nextPosition
{
	
	return [_posList next];
}

- (BOOL)  skipTo: (int) target
{
#if 1
	while (target > [[_termPositionsQueue peek] document])
#else /* FIXME: below is new code */
       while (_termPositionsQueue.peek() != null && target > _termPositionsQueue.peek().doc())
#endif
	{
	    id <LCTermPositions> tp = (id <LCTermPositions>)[_termPositionsQueue pop];
		
	    if ([tp skipTo: target])
			[_termPositionsQueue put: tp];
	    else
			[tp close];
	}
	
	return [self hasNextDocument];
}

- (long) document
{
	
	return _doc;
}

- (long) frequency
{
	return _freq;
}

- (void) close
{
	while ([_termPositionsQueue size] > 0)
	    [(id <LCTermPositions>)[_termPositionsQueue pop] close];
}

/** Not implemented.
* @throws UnsupportedOperationException
*/
- (void) seekTerm: (LCTerm *) arg0
{
    NSLog(@"UnsupportedOperation");
}

/** Not implemented.
* @throws UnsupportedOperationException
*/
- (void) seekTermEnumerator: (LCTermEnumerator *) termEnum
{
    NSLog(@"UnsupportedOperation");
}

/** Not implemented.
* @throws UnsupportedOperationException
*/
- (int) readDocuments: (NSMutableArray *) docs  frequency: (NSMutableArray *) freq size: (int) size
{
	NSLog(@"UnsupportedOperation");
	return 0;
}

- (NSComparisonResult) compare: (id) o
{
	LCMultipleTermPositions *other = (LCMultipleTermPositions *) o;
	if ([self document] < [other document])
		return NSOrderedAscending;
	else if ([self document] == [other document])
		return NSOrderedSame;
	else
		return NSOrderedDescending;
}

@end
