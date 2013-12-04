#import <CoreObject/CoreObject.h>
#import "COObjectGraphContext+Graphviz.h"

@implementation COObjectGraphContext (Graphviz)

- (NSString *) graphvizNodeNameForUUID: (ETUUID *)aUUID
{
	NSString *str = [aUUID stringValue];
	str = [str stringByReplacingOccurrencesOfString: @"-" withString: @"_"];
	return [@"uuid_" stringByAppendingString: str];
}

- (NSString *) graphvizNodeNameForPath: (COPath *)aPath
{
	NSString *str = @"path_";
	str = [str stringByAppendingString: [self graphvizNodeNameForUUID: aPath.persistentRoot]];
	if (aPath.branch != nil)
	{
		str = [str stringByAppendingString: [self graphvizNodeNameForUUID: aPath.branch]];
	}
	return str;
}

- (NSString *) graphvizNodeNameForObject: (id)anObject
{
	if ([anObject isKindOfClass: [ETUUID class]])
	{
		return [self graphvizNodeNameForUUID: anObject];
	}
	else if ([anObject isKindOfClass: [COPath class]])
	{
		return [self graphvizNodeNameForPath: anObject];
	}
	ETAssertUnreachable();
	return nil;
}

- (NSString*) graphvizPortNameForAttribute: (NSString *)anAttribute
{
	NSString *str = @"port_";
	str = [str stringByAppendingString: anAttribute];
	str = [str stringByReplacingOccurrencesOfString: @"." withString: @"_"];
	return str;
}

- (NSString *) graphvizNodeNameForCollectionNodeForAttribute: (NSString *)anAttribute itemUUID: (ETUUID *)aUUID
{
	return [NSString stringWithFormat: @"collection_%@_%@", [self graphvizNodeNameForUUID: aUUID], [self graphvizPortNameForAttribute: anAttribute]];
}

- (NSString *) sanatizeStringForHTML: (NSString *)aString
{
	aString = [aString stringByReplacingOccurrencesOfString: @"<"
												 withString: @"&lt;"];
	aString = [aString stringByReplacingOccurrencesOfString: @">"
												 withString: @"&gt;"];
	return aString;
}

- (NSString *) graphvizPortNameForIndex: (NSUInteger)i
{
	return [NSString stringWithFormat: @"p%llu", (unsigned long long)i];
}

- (void) writeNodeForPath: (COPath *)aPath toString: (NSMutableString *)dest
{
	NSString *destNodeName = [self graphvizNodeNameForPath: aPath];

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

- (void) writeHTMLTableRowForAttribute: (NSString *)key forItem: (COItem *)anItem toString: (NSMutableString *)dest suffix: (NSMutableString *)extraNodes
{
	COType type = [anItem typeForAttribute: key];
	id value = [anItem valueForAttribute: key];
	
	NSString *nodeName = [self graphvizNodeNameForUUID: anItem.UUID];
	NSString *portName = [self graphvizPortNameForAttribute: key];
	
	[dest appendFormat: @"<tr><td>%@</td><td>%@</td><td port=\"%@\">", key, COTypeDescription(type), portName];

	if (COTypeIsPrimitive(type)) /* univalued */
	{
		if (!(COTypePrimitivePart(type) == kCOTypeCompositeReference
			  || COTypePrimitivePart(type) == kCOTypeReference))
		{
			/* non-object reference. */
			/* value is NSData, NSString, or NSNumber */
			[dest appendString: [self sanatizeStringForHTML: [value stringValue]]];
		}
		else /* object reference */
		{
			NSString *destNodeName = [self graphvizNodeNameForObject: value];
			[extraNodes appendFormat: @"%@:%@ -> %@;\n", nodeName, portName, destNodeName];
			
			/* draw the target of a cross-persistent root reference */
			if ([value isKindOfClass: [COPath class]])
			{
				[self writeNodeForPath: value toString: extraNodes];
			}
		}
	}
	else /* multivalued */
	{
		/** Node name for the box to display the collection contents in */
		NSString *collectionNodeName = [self graphvizNodeNameForCollectionNodeForAttribute: key itemUUID: anItem.UUID];
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
			
			[extraNodes appendFormat: @"<%@> %@", [self graphvizPortNameForIndex: i], subvalueLabel];
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
			
			NSString *destNodeName = [self graphvizNodeNameForObject: subvalue];
			[extraNodes appendFormat: @"%@:%@ -> %@;\n", collectionNodeName, [self graphvizPortNameForIndex: i], destNodeName];
			
			// Output cross-persistent root reference nodes if needed
			if ([subvalue isKindOfClass: [COPath class]])
			{
				[self writeNodeForPath: subvalue toString: extraNodes];
			}
		}
	}
		
	[dest appendFormat: @"</td></tr>"];
}
- (void) writeDotNodeForItem: (COItem *)anItem toString: (NSMutableString *)dest
{
	NSString *nodeName = [self graphvizNodeNameForUUID: anItem.UUID];
	NSString *nodeTitle = [anItem.UUID stringValue];
	
	NSMutableString *extraNodes = [NSMutableString string];
	
	[dest appendFormat: @"%@ [shape=plaintext, label=<<table border=\"0\" cellborder=\"1\" cellspacing=\"0\"><tr><td colspan=\"3\">%@</td></tr>", nodeName, nodeTitle];
	for (NSString *attr in [anItem attributeNames])
	{
		[self writeHTMLTableRowForAttribute: attr forItem: anItem toString: dest suffix: extraNodes];
	}
	[dest appendFormat: @"</table>>];\n"];
	[dest appendString: extraNodes];
}

- (NSString *) dotGraph
{
	NSMutableString *result = [NSMutableString string];
	[result appendString: @"digraph G {\n"];
	for (ETUUID *uuid in [self itemUUIDs])
	{
		COItem *item = [self itemForUUID: uuid];
		[self writeDotNodeForItem: item toString: result];
	}

	[result appendString: @"root_item [label=\"Graph Root\"];\n"];
	if ([self rootItemUUID] != nil)
	{
		[result appendFormat: @"root_item -> %@;\n", [self graphvizNodeNameForUUID: [self rootItemUUID]]];
	}
	[result appendString: @"}\n"];
    return result;
}

- (void) showGraph
{
	NSString *basePath = [NSString stringWithFormat: @"%@-%d",
						  [NSTemporaryDirectory() stringByAppendingPathComponent: [[[self branch] UUID] stringValue]],
						  rand()];
	
	NSString *dotGraphPath = [basePath stringByAppendingPathExtension: @"gv"];
	NSString *pdfPath = [basePath stringByAppendingPathExtension: @"pdf"];
	[[self dotGraph] writeToFile: dotGraphPath atomically: YES encoding: NSUTF8StringEncoding error: NULL];
	
	system([[NSString stringWithFormat: @"dot -Tpdf %@ -o %@ && open %@", dotGraphPath, pdfPath, pdfPath] UTF8String]);
}

@end
