/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <CoreObject/COObjectGraphContext.h>
#import <CoreObject/COItemGraph.h>

NSString *COGraphvizDotFileForItemGraph(id<COItemGraph> graph);
void COGraphvizShowGraph(id<COItemGraph> graph);

@interface COObjectGraphContext (Graphviz)
- (void) showGraph;
@end

@interface COItemGraph (Graphviz)
- (void) showGraph;
@end