/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>
#import "COObjectGraphContext+Graphviz.h"

static NSString *COGraphvizNodeNameForUUID(ETUUID *aUUID)
{
	NSString *str = [aUUID stringValue];
	str = [str stringByReplacingOccurrencesOfString: @"-" withString: @"_"];
	return [@"uuid_" stringByAppendingString: str];
}

static NSString *COGraphvizNodeNameForPath(COPath *aPath)
{
	NSString *str = @"path_";
	str = [str stringByAppendingString: COGraphvizNodeNameForUUID(aPath.persistentRoot)];
	if (aPath.branch != nil)
	{
		str = [str stringByAppendingString: COGraphvizNodeNameForUUID(aPath.branch)];
	}
	return str;
}

static NSString *COGraphvizNodeNameForObject(id anObject)
{
	if ([anObject isKindOfClass: [ETUUID class]])
	{
		return COGraphvizNodeNameForUUID(anObject);
	}
	else if ([anObject isKindOfClass: [COPath class]])
	{
		return COGraphvizNodeNameForPath(anObject);
	}
	assert(0);
	return nil;
}

static NSString *COGraphvizPortNameForAttribute(NSString *anAttribute)
{
	NSString *str = @"port_";
	str = [str stringByAppendingString: anAttribute];
	str = [str stringByReplacingOccurrencesOfString: @"." withString: @"_"];
	return str;
}

static NSString *COGraphvizNodeNameForCollectionNodeForAttribute(NSString *anAttribute, ETUUID *aUUID)
{
	return [NSString stringWithFormat: @"collection_%@_%@",
			COGraphvizNodeNameForUUID(aUUID),
			COGraphvizPortNameForAttribute(anAttribute)];
}

static NSString *COGraphvizSanatizeStringForHTML(NSString *aString)
{
	aString = [aString stringByReplacingOccurrencesOfString: @"<"
												 withString: @"&lt;"];
	aString = [aString stringByReplacingOccurrencesOfString: @">"
												 withString: @"&gt;"];
	return aString;
}

static NSString *COGraphvizPortNameForIndex(NSUInteger i)
{
	return [NSString stringWithFormat: @"p%llu", (unsigned long long)i];
}

static void COGraphvizWriteNodeForPathToString(COPath *aPath, NSMutableString *dest)
{
	NSString *destNodeName = COGraphvizNodeNameForPath(aPath);

	NSString *label = [NSString stringWithFormat: @"Cross-persistent root reference to %@", aPath.persistentRoot];
	if (aPath.branch == nil)
	{
		label = [label stringByAppendingString: @", current branch"];
	}
	else
	{
		label = [label stringByAppendingFormat: @", branch %@", aPath.branch];
	}
	
	[dest appendFormat: @"%@ [label=\"%@\"];\n", destNodeName, label];
}

static void COGraphvizWriteHTMLTableRowForAttributeOfItem(NSString *key, COItem *anItem, NSMutableString *dest, NSMutableString *extraNodes)
{
	COType type = [anItem typeForAttribute: key];
	id value = [anItem valueForAttribute: key];
	
	NSString *nodeName = COGraphvizNodeNameForUUID(anItem.UUID);
	NSString *portName = COGraphvizPortNameForAttribute(key);
	
	[dest appendFormat: @"<tr><td>%@</td><td>%@</td><td port=\"%@\">", key, COTypeDescription(type), portName];

	if (COTypeIsUnivalued(type)) /* univalued */
	{
		if (!(COTypePrimitivePart(type) == kCOTypeCompositeReference
			  || COTypePrimitivePart(type) == kCOTypeReference))
		{
			/* non-object reference. */
			/* value is NSData, NSString, or NSNumber */
			[dest appendString: COGraphvizSanatizeStringForHTML([value stringValue])];
		}
		else /* object reference */
		{
			NSString *destNodeName = COGraphvizNodeNameForObject(value);
			[extraNodes appendFormat: @"%@:%@ -> %@;\n", nodeName, portName, destNodeName];
			
			/* draw the target of a cross-persistent root reference */
			if ([value isKindOfClass: [COPath class]])
			{
				COGraphvizWriteNodeForPathToString(value, extraNodes);
			}
		}
	}
	else /* multivalued */
	{
		/** Node name for the box to display the collection contents in */
		NSString *collectionNodeName = COGraphvizNodeNameForCollectionNodeForAttribute(key, anItem.UUID);
		[extraNodes appendFormat: @"%@:%@ -> %@;\n", nodeName, portName, collectionNodeName];
		
		// Output a node for the collection with one port per element in the collection
		
		NSArray *collectionArray = [value isKindOfClass: [NSSet class]] ? [value allObjects] : value;
		
		[extraNodes appendFormat: @"%@ [shape=%@, label=\"", collectionNodeName, COTypeIsOrdered(type) ? @"record" : @"Mrecord"];
		for (NSUInteger i=0; i<[collectionArray count]; i++)
		{
			id subvalue = [collectionArray objectAtIndex: i];
			
			NSString *subvalueLabel;
			if ([subvalue isKindOfClass: [ETUUID class]] || [subvalue isKindOfClass: [COPath class]])
			{
				if (COTypeIsOrdered(type))
				{
					subvalueLabel = [NSString stringWithFormat: @"%llu", (unsigned long long)i];
				}
				else
				{
					subvalueLabel = @"";
				}
			}
			else
			{
				subvalueLabel = [subvalue stringValue];
			}
			
			[extraNodes appendFormat: @"<%@> %@", COGraphvizPortNameForIndex(i), subvalueLabel];
			if (i < [collectionArray count] - 1)
			{
				[extraNodes appendFormat: @"|"];
			}
		}
		[extraNodes appendFormat: @"\"];\n"];
		
		// Output a link from each element in the collection to its destination, if they're object references or cross-persistent-root refs
		
		for (NSUInteger i=0; i<[collectionArray count]; i++)
		{
			id subvalue = [collectionArray objectAtIndex: i];

			if (!([subvalue isKindOfClass: [ETUUID class]] || [subvalue isKindOfClass: [COPath class]]))
				continue;
			
			NSString *destNodeName = COGraphvizNodeNameForObject(subvalue);
			[extraNodes appendFormat: @"%@:%@ -> %@;\n", collectionNodeName, COGraphvizPortNameForIndex(i), destNodeName];
			
			// Output cross-persistent root reference nodes if needed
			if ([subvalue isKindOfClass: [COPath class]])
			{
				COGraphvizWriteNodeForPathToString(subvalue, extraNodes);
			}
		}
	}
		
	[dest appendFormat: @"</td></tr>"];
}

static void COGraphvizWriteDotNodeForItem(COItem *anItem, NSMutableString *dest)
{
	NSString *nodeName = COGraphvizNodeNameForUUID(anItem.UUID);
	NSString *nodeTitle = [anItem.UUID stringValue];
	
	NSMutableString *extraNodes = [NSMutableString string];
	
	[dest appendFormat: @"%@ [shape=plaintext, label=<<table border=\"0\" cellborder=\"1\" cellspacing=\"0\"><tr><td colspan=\"3\">%@</td></tr>", nodeName, nodeTitle];
	for (NSString *attr in [anItem attributeNames])
	{
		COGraphvizWriteHTMLTableRowForAttributeOfItem(attr, anItem, dest, extraNodes);
	}
	[dest appendFormat: @"</table>>];\n"];
	[dest appendString: extraNodes];
}

NSString *COGraphvizDotFileForItemGraph(id<COItemGraph> graph)
{
	NSMutableString *result = [NSMutableString string];
	[result appendString: @"digraph G {\n"];
	for (ETUUID *uuid in [graph itemUUIDs])
	{
		COItem *item = [graph itemForUUID: uuid];
		COGraphvizWriteDotNodeForItem(item, result);
	}

	[result appendString: @"root_item [label=\"Graph Root\"];\n"];
	if ([graph rootItemUUID] != nil)
	{
		[result appendFormat: @"root_item -> %@;\n", COGraphvizNodeNameForUUID([graph rootItemUUID])];
	}
	[result appendString: @"}\n"];
    return result;
}

void COGraphvizShowGraph(id<COItemGraph> graph)
{
	NSString *basePath = [NSString stringWithFormat: @"%@-%d",
						  [NSTemporaryDirectory() stringByAppendingPathComponent: [[graph rootItemUUID] stringValue]],
						  rand()];
	
	NSString *dotGraphPath = [basePath stringByAppendingPathExtension: @"gv"];
	NSString *pdfPath = [basePath stringByAppendingPathExtension: @"pdf"];
	[COGraphvizDotFileForItemGraph(graph) writeToFile: dotGraphPath atomically: YES encoding: NSUTF8StringEncoding error: NULL];
	
	system([[NSString stringWithFormat: @"dot -Tpdf %@ -o %@ && open %@", dotGraphPath, pdfPath, pdfPath] UTF8String]);
}

@implementation COObjectGraphContext (Graphviz)

- (void) showGraph
{
	COGraphvizShowGraph(self);
}

@end

@implementation COItemGraph (Graphviz)

- (void) showGraph
{
	COGraphvizShowGraph(self);
}

@end
