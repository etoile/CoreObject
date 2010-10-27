#import "ETXMLWriter.h"

// FIXME: Cyclic dependency between EtoileFoundation and EtoileXML
#import "../Headers/ETSocket.h"
#import "../Headers/Macros.h"
#import "../Headers/EtoileCompatibility.h"

NSString *ETXMLMismatchedTagException = @"ETXMLMismatchedTagException";

/**
 * A buffered XML-writer that flushes its buffer to the parent writer upon
 * deallocation.
 */
@interface ETXMLSubtreeWriter : ETXMLWriter
{
	ETXMLWriter *parent;
	NSCondition *parentCondition;
	NSInteger initialDepth;
}
- (id)initWithParent: (ETXMLWriter*) aParent
        andCondition: (NSCondition*) theParentLock
             atDepth: (NSInteger) theDepth;
@end

@implementation ETXMLWriter

- (NSUInteger)depth
{
	return [tagStack count];
}

- (ETXMLWriter*)beginTransaction
{
	[condition lock];
	NSUInteger depth = [tagStack count];
	if (0 == depth)
	{
		[condition unlock];
		return self;
	}
	else
	{
		@synchronized(self)
		{
			if (subwriterCount == 0)
			{
				subwriterCount++;
				condition = [[NSCondition alloc] init];
				[condition lock];
			}
		}
		ETXMLSubtreeWriter *subWriter = [[[ETXMLSubtreeWriter alloc] initWithParent: self
		                                                               andCondition: condition
		                                                                    atDepth: depth] autorelease];
		[subWriter setAutoindent: autoindent];
		[condition unlock];
		return subWriter;
	}
}

- (void)setAutoindent: (BOOL)aFlag
{
	autoindent = aFlag;
}
- (BOOL)autoindent
{
	return autoindent;
}
- (NSString*)stringValue
{
	return [[buffer copy] autorelease];
}
- (NSString*)endDocument
{
	id ret = [buffer autorelease];
	buffer = nil;
	return ret;
}
- (void)characters: (NSString*)chars
{
	if (inOpenTag)
	{
		[buffer appendString:@">"];
		inOpenTag = NO;
	}
	[buffer appendString: escapeXMLCData(chars)];
}
- (void)writeXMLHeader
{
	[buffer appendString: @"<?xml version=\"1.0\" encoding=\"utf-8\" ?>"];
}
- (void)appendUnescapedString: (NSString*)aString
{
	[buffer appendString: aString];
}
- (void)startElement: (NSString*)aName
{
	[self startElement: aName
	        attributes: nil];
}
- (void)startAndEndElement: (NSString*)aName
{
	[self startAndEndElement: aName
	              attributes: nil];
}
- (void)startAndEndElement: (NSString*)aName
                attributes: (NSDictionary*)attributes
{
	[self startElement: aName
	        attributes: attributes];
	[self endElement];
}
- (void)startAndEndElement: (NSString*)aName
                attributes: (NSDictionary*)attributes
                containing: (id)aBlock
{
	[self startElement: aName
	        attributes: attributes];
	[aBlock value];
	[self endElement];
}
- (void)startAndEndElement: (NSString*)aName
                containing: (id)aBlock
{
	[self startAndEndElement: aName
	              attributes: nil
	              containing: aBlock];
}
- (void)startAndEndElement: (NSString*)aName
                attributes: (NSDictionary*)attributes
                     cdata: (NSString*)chars
{
	[self startElement: aName
	        attributes: attributes];
	[self characters: chars];
	[self endElement];
}
- (void)startAndEndElement: (NSString*)aName
                     cdata: (NSString*)chars
{
	[self startAndEndElement: aName
	              attributes: nil
	                   cdata: chars];
}
- (void)startElement: (NSString*)aName
          attributes: (NSDictionary*)attributes
{
	[condition lock];
	if (inOpenTag)
	{
		[buffer appendString: @">"];
		inOpenTag = NO;
	}
	if (autoindent)
	{
		if (0 != [tagStack count])
		{
			[buffer appendString: indentString];
		}
		[indentString appendString: @"\t"];
	}
	//Open tag
	[buffer appendFormat: @"<%@",aName];
	
	//Add attributes
	if (attributes != nil)
	{
		NSEnumerator *enumerator = [attributes keyEnumerator];		
		NSString* key;
		while (nil != (key = [enumerator nextObject])) 
		{
			[buffer appendFormat: @" %@=\"%@\"", key,
					escapeXMLCData([attributes objectForKey:key])];
		}
	}
	[tagStack addObject: aName];
	inOpenTag = YES;
	[condition unlock];
}

- (void)endElement
{
	[condition lock];
	NSString *aName = [tagStack lastObject];
	if (autoindent)
	{
		int length = [indentString length];
		if (length > 0)
		{
			[indentString deleteCharactersInRange: NSMakeRange(length-1, 1)];
		}
	}
	if (inOpenTag)
	{
		[buffer appendString: @" />"];
	}
	else
	{
		if (autoindent)
		{
			[buffer appendString: indentString];
		}
		[buffer appendFormat: @"</%@>", aName];
	}
	[tagStack removeLastObject];
	inOpenTag = NO;
	[condition broadcast];
	[condition unlock];
}
- (void)endElement: (NSString*)aName
{
	if (![aName isEqualToString: [tagStack lastObject]])
	{
		[NSException raise: ETXMLMismatchedTagException
		            format: @"Attempting to close %@ inside %@",
			aName, [tagStack lastObject]];
	}
	[self endElement];
}
- (void)reset
{
	[buffer release];
	[tagStack release];
	[indentString release];
	buffer = [NSMutableString new];
	indentString = [@"\n" mutableCopy];
	tagStack = [NSMutableArray new];
}

- (void)appendSubtree: (NSString*)anXMLString
{
	// NOTE: Additional synchronization is not needed here because the calling
	// ETXMLSubtreeWriter obtains the condition prior to this.
	if (inOpenTag)
	{
		[buffer appendString:@">"];
		inOpenTag = NO;
	}
	subwriterCount--;
	[buffer appendString: anXMLString];
	if (0 == subwriterCount)
	{
		[condition release];
		condition = nil;
	}
}

- (id)init
{
	SUPERINIT;
	buffer = [NSMutableString new];
	indentString = [@"\n" mutableCopy];
	tagStack = [NSMutableArray new];
	return self;
}
- (void)dealloc
{
	[buffer release];
	[tagStack release];
	[indentString release];
	[condition release];
	[super dealloc];
}
@end	
@implementation ETXMLSocketWriter : ETXMLWriter 
- (void)sendBuffer
{
	[socket sendData: [buffer dataUsingEncoding: NSUTF8StringEncoding]];
	[buffer setString: @""];
}
- (void)characters: (NSString*)chars
{
	[super characters: chars];
	[self sendBuffer];
}
- (void)startElement: (NSString*)aName
          attributes: (NSDictionary*)attributes
{
	[super startElement: aName attributes: attributes];
	[self sendBuffer];
}
- (void)endElement
{
	[super endElement];
	[self sendBuffer];
}
- (void)setSocket: (ETSocket*)aSocket
{
	ASSIGN(socket, aSocket);
}
- (void)appendSubtree: (NSString*)anXMLString
{
	[super appendSubtree: anXMLString];
	[self sendBuffer];
}
- (void)dealloc
{
	[socket release];
	[super dealloc];
}
@end

@implementation ETXMLSubtreeWriter
- (id)initWithParent: (ETXMLWriter*) aWriter
        andCondition: (NSCondition*) aCondition
             atDepth: (NSInteger) theDepth
{
	SUPERINIT;
	parent = [aWriter retain];
	parentCondition = [aCondition retain];
	initialDepth = theDepth;
	return self;
}

- (BOOL)finishTransaction
{
	BOOL success = NO;
	// We don't want to inject subtrees that are not well-formed.
	if (0 != [tagStack count])
	{
		NSDebugLog(@"Attempt to transact unfinished XML tree.");
		return success;
	}

	[parentCondition lock];
	while ([parent depth] > initialDepth)
	{
		[parentCondition wait];
	}

	if ([parent depth] == initialDepth)
	{
		[parent appendSubtree: [self endDocument]];
		success = YES;
	}
	// We also don't want to append any data if the parent writer has left the
	// scope in which we were created.
	[parentCondition broadcast];
	[parentCondition unlock];
	return success;
}

- (void)dealloc
{
	[self finishTransaction];
	[parent release];
	[parentCondition release];
	[super dealloc];
}

- (void)finalize
{
	[self finishTransaction];
	[super finalize];
}
@end
