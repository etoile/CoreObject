/*
	Copyright (C) 2014 Quentin Mathe

	Date:  December 2014
	License:  MIT  (see COPYING)
 */

#import "COTopologicalSort.h"

static BOOL COTopologicalSortVisitNode(id node, NSMutableArray *traversedNodes,
	NSString *edgeKey, NSMutableSet *unsortedNodes, NSMutableArray *sortedNodes)
{
	BOOL hasCycle = [traversedNodes containsObject: node];
	
	if (hasCycle)
		return NO;
	
	BOOL isSorted = [sortedNodes containsObject: node];
	
	if (isSorted)
		return YES;
	
	[traversedNodes addObject: node];
	
	for (id childNode in [node valueForKey: edgeKey])
	{
		BOOL success = COTopologicalSortVisitNode(childNode, traversedNodes,
			edgeKey, unsortedNodes, sortedNodes);
		
		if (!success)
			return NO;
	}
	
	[unsortedNodes removeObject: node];
	[traversedNodes removeObject: node];
	[sortedNodes insertObject: node atIndex: 0];
	
	return YES;
}

/**
 * Based on Cormen's algorithm, see http://en.wikipedia.org/wiki/Topological_sorting
 */
NSArray * COTopologicalSort(NSSet *nodes, NSString *edgeKey)
{
	NSMutableSet *unsortedNodes = [nodes mutableCopy];
	NSMutableArray *sortedNodes = [NSMutableArray new];
	NSMutableArray *traversedNodes = [NSMutableArray new];
	BOOL success = NO;

	while (![unsortedNodes isEmpty])
	{
		id node = [unsortedNodes anyObject];

		
		success = COTopologicalSortVisitNode(node, traversedNodes, edgeKey, unsortedNodes, sortedNodes);
		assert(!success || [traversedNodes isEmpty]);

		if (!success)
			break;
	}
	
	return (success ? sortedNodes : nil);
}
