/**
    Copyright (C) 2014 Quentin Mathe

    Date:  January 2014
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

/**
 * Returns the graph nodes sorted topologically.
 *
 * The node property that represents one or more outgoing edges to other nodes,
 * must be provided with the edge key (e.g. 'children' or 'dependencies').
 * COTopologicalSort will then use Key-Value Coding to visit the graph.
 *
 * When a cycle is detected, returns nil immediately, otherwise always returns 
 * a valid array containing all the nodes passed in argument.
 */
extern NSArray * COTopologicalSort(NSSet *nodes, NSString *edgeKey);
