#import <CoreObject/CoreObject.h>
#import "COObjectGraphContext+Graphviz.h"

@implementation COObjectGraphContext (Graphviz)

- (NSString *) graphvizNodeNameForUUID: (ETUUID *)aUUID
{
	NSString *str = [aUUID stringValue];
	str = [str stringByReplacingOccurrencesOfString: @"-" withString: @"_"];
	return [@"uuid_" stringByAppendingString: str];
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

- (void) writeHTMLTableRowForAttribute: (NSString *)key forItem: (COItem *)anItem toString: (NSMutableString *)dest suffix: (NSMutableString *)extraNodes
{
	COType type = [anItem typeForAttribute: key];
	id value = [anItem valueForAttribute: key];
	
	NSString *nodeName = [self graphvizNodeNameForUUID: anItem.UUID];
	NSString *portName = [self graphvizPortNameForAttribute: key];
	
	[dest appendFormat: @"<tr><td>%@</td><td>%@</td><td port=\"%@\">", key, COTypeDescription(type), portName];

	if (COTypePrimitivePart(type) == kCOTypeCompositeReference
		  || COTypePrimitivePart(type) == kCOTypeReference)
	{
		if (!COTypeIsMultivalued(type))
		{
			NSString *destNodeName = [self graphvizNodeNameForUUID: value];
			[extraNodes appendFormat: @"%@:%@ -> %@;\n", nodeName, portName, destNodeName];
		}
		else
		{
			NSString *collectionNodeName = [self graphvizNodeNameForCollectionNodeForAttribute: key itemUUID: anItem.UUID];
			[extraNodes appendFormat: @"%@:%@ -> %@;\n", nodeName, portName, collectionNodeName];
			
			// Output a node for the collection with one port per element in the collection
			
			[extraNodes appendFormat: @"%@ [shape=record, label=\"", collectionNodeName];
			for (NSUInteger i=0; i<[value count]; i++)
			{
				[extraNodes appendFormat: @"<%@> %llu", [self graphvizPortNameForIndex: i], (unsigned long long)i];
				if (i < [value count] - 1)
				{
					[extraNodes appendFormat: @"|"];
				}
			}
			[extraNodes appendFormat: @"\"];\n"];
			
			// Output a link from each element in the collection to its destination
			
			for (NSUInteger i=0; i<[value count]; i++)
			{
				ETUUID *dest = [value objectAtIndex: i];
				NSString *destNodeName = [self graphvizNodeNameForUUID: dest];
				
				[extraNodes appendFormat: @"%@:%@ -> %@;", collectionNodeName, [self graphvizPortNameForIndex: i], destNodeName];				
			}
		}
	}
	else
	{
		/* value is NSData, NSString, or NSNumber */
		[dest appendString: [self sanatizeStringForHTML: [value stringValue]]];
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
