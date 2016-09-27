/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import "COAttributedString.h"
#import "COAttributedStringChunk.h"
#import "COAttributedStringAttribute.h"

// FIXME: Hack to get -insertObjects:atIndexes:hints:forProperty:
#import "COObject+Private.h"
#import "COObjectGraphContext+Private.h"
#import "COObjectGraphContext+Graphviz.h"

#import "COAttributedStringWrapper.h"

@implementation COAttributedString

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [self newBasicEntityDescription];

    if (![entity.name isEqual: [COAttributedString className]])
        return entity;
    
    ETPropertyDescription *chunksProperty = [ETPropertyDescription descriptionWithName: @"chunks"
                                                                                  typeName: @"COAttributedStringChunk"];
    chunksProperty.multivalued = YES;
    chunksProperty.ordered = YES;
    chunksProperty.persistent = YES;
    chunksProperty.oppositeName = @"COAttributedStringChunk.parentString";
    
    entity.propertyDescriptions = @[chunksProperty];
    
    entity.diffAlgorithm = @"COAttributedStringDiff";
    
    return entity;
}

@dynamic chunks;

- (NSString *)string
{
    NSMutableString *result = [NSMutableString new];
    for (COAttributedStringChunk *chunk in self.chunks)
    {
        if (chunk.text != nil)
        {
            [result appendString: chunk.text];
        }
    }
    return result;
}

- (NSArray *) chunkUUIDsOverlappingRange: (NSRange)aRange
                 excessCharactersAtStart: (NSUInteger *)excessAtStart
                   excessCharactersAtEnd: (NSUInteger *)excessAtEnd
{
    NSMutableArray *result = [NSMutableArray new];
    
    NSUInteger chunkIndex = 0, chunkStart = 0;
    COAttributedStringChunk *chunk = [self chunkContainingIndex: aRange.location chunkStart: &chunkStart chunkIndex: &chunkIndex];
    
    *excessAtStart = (aRange.location - chunkStart);
    
    [result addObject: chunk.UUID];
    
    const NSUInteger maxRange = NSMaxRange(aRange);
    
    while (chunkStart + chunk.length < maxRange)
    {
        chunkStart += chunk.length;
        chunkIndex++;
        chunk = self.chunks[chunkIndex];
        
        [result addObject: chunk.UUID];
    }
    
    *excessAtEnd = ((chunkStart + chunk.length) - maxRange);
    
    return result;
}

- (COItemGraph *) substringItemGraphWithRange: (NSRange)aRange
{
    ETAssert(aRange.length > 0);
    
    COItemGraph *result = [[COItemGraph alloc] init];
    
    NSUInteger excessAtStart = 0;
    NSUInteger excessAtEnd = 0;
    NSArray *chunkUUIDS = [self chunkUUIDsOverlappingRange: aRange excessCharactersAtStart: &excessAtStart excessCharactersAtEnd: &excessAtEnd];
    
    COCopier *copier = [COCopier new];
    NSArray *copiedUUIDs = [copier copyItemsWithUUIDs: chunkUUIDS fromGraph: self.objectGraphContext toGraph: result];
    
    // Trim off excess characters
    
    COMutableItem *firstChunk = [result itemForUUID: copiedUUIDs[0]];
    [firstChunk setValue: [[firstChunk valueForAttribute: @"text"] substringFromIndex: excessAtStart]
            forAttribute: @"text"
                    type: kCOTypeString];
    
    COMutableItem *lastChunk = [result itemForUUID: copiedUUIDs.lastObject];
    [lastChunk setValue: [[lastChunk valueForAttribute: @"text"] substringToIndex: ([[lastChunk valueForAttribute: @"text"] length] - excessAtEnd)]
            forAttribute: @"text"
                    type: kCOTypeString];
    
    // Insert a root COAttributedString item
    
    COMutableItem *rootItem = [COMutableItem item];

    rootItem.entityName = @"COAttributedString";
    rootItem.packageName = self.entityDescription.owner.name;
    rootItem.packageVersion = self.entityDescription.owner.version;

    [rootItem setValue: copiedUUIDs forAttribute: @"chunks" type: COTypeMakeArrayOf(kCOTypeCompositeReference)];

    [result insertOrUpdateItems: @[rootItem]];
    result.rootItemUUID = rootItem.UUID;
    
    return result;
}

- (COAttributedStringChunk *) chunkContainingIndex: (NSUInteger)anIndex chunkStart: (NSUInteger *)chunkStartOut chunkIndex: (NSUInteger *)chunkIndexOut
{
    COAttributedStringChunk *target = nil;
    NSUInteger i = 0, chunkIndex = 0;
    
    for (COAttributedStringChunk *chunk in self.chunks)
    {
        const NSUInteger chunkLen = chunk.length;
        if (anIndex >= i && anIndex < (i + chunkLen))
        {
            target = chunk;
            
            if (chunkStartOut != NULL)
            {
                *chunkStartOut = i;
            }
            
            if (chunkIndexOut != NULL)
            {
                *chunkIndexOut = chunkIndex;
            }
            
            break;
        }
        i += chunkLen;
        chunkIndex++;
    }
    
    return target;
}

- (NSUInteger) length
{
    NSUInteger result = 0;
    for (COAttributedStringChunk *chunk in self.chunks)
    {
        result += chunk.length;
    }
    return result;
}

- (NSUInteger) splitChunkAtIndex: (NSUInteger)characterIndex
{
    ETAssert(characterIndex <= [self length]);
    
    if (characterIndex == self.length)
        return self.chunks.count;
    
    NSUInteger chunkIndex = 0, chunkStart = 0;
    COAttributedStringChunk *chunk = [self chunkContainingIndex: characterIndex chunkStart: &chunkStart chunkIndex: &chunkIndex];
    
    ETAssert(chunk != nil);
    
    if (characterIndex == chunkStart)
        return chunkIndex;
    
    // We need to split 'chunk'
    
    ETAssert(characterIndex > chunkStart);
    
    NSUInteger leftChunkLength = characterIndex - chunkStart;
    NSString *leftString = [chunk.text substringToIndex: leftChunkLength];
    NSString *rightString = [chunk.text substringFromIndex: leftChunkLength];
    
    // First, trim 'chunk' down to the point where we are splitting it
    
    chunk.text = leftString;
    
    // Create a new chunk for the right side, copying from the left side so we also copy the
    // attributes.
    // FIXME: Since attributes aren't referred to with a composite rel'n, currently
    // they are being aliased and not copied.
    
    COCopier *copier = [COCopier new];
    ETUUID *rightChunkUUID = [copier copyItemWithUUID: chunk.UUID fromGraph: self.objectGraphContext toGraph: self.objectGraphContext];
    COAttributedStringChunk *rightChunk = [self.objectGraphContext loadedObjectForUUID: rightChunkUUID];
    rightChunk.text = rightString;
    
    // Insert rightChunk
    
    [self insertObjects: @[rightChunk]
              atIndexes: [[NSIndexSet alloc] initWithIndex: chunkIndex + 1]
                  hints: @[]
            forProperty: @"chunks"];
    
    return chunkIndex + 1;
}

- (NSSet *) attributesSetAtIndex: (NSUInteger)characterIndex longestEffectiveRange: (NSRange *)rangeOut inRange: (NSRange)rangeLimit
{
    NSUInteger chunkIndex = 0, chunkStart = 0;
    COAttributedStringChunk *chunk = [self chunkContainingIndex: characterIndex chunkStart: &chunkStart chunkIndex: &chunkIndex];
    NSSet *attribs = chunk.attributes;
    
    if (rangeOut != NULL)
    {
        NSRange longestEffectiveRange = NSMakeRange(chunkStart, chunk.length);

        // Look left
        
        for (NSInteger j=chunkIndex-1; j>=0; j--)
        {
            COAttributedStringChunk *leftChunk = self.chunks[j];
            
            if ([COAttributedStringAttribute isAttributeSet: leftChunk.attributes equalToSet: attribs])
            {
                longestEffectiveRange.location -= leftChunk.length;
                longestEffectiveRange.length += leftChunk.length;
            }
            else
            {
                break;
            }
        }
        
        // Look right
        
        for (NSInteger j=chunkIndex+1; j<self.chunks.count; j++)
        {
            COAttributedStringChunk *rightChunk = self.chunks[j];
            if ([COAttributedStringAttribute isAttributeSet: rightChunk.attributes equalToSet: attribs])
            {
                longestEffectiveRange.length += rightChunk.length;
            }
            else
            {
                break;
            }
        }
        
        // Trim longestEffectiveRange
        
        longestEffectiveRange = NSIntersectionRange(longestEffectiveRange, rangeLimit);
        
        *rangeOut = longestEffectiveRange;
    }
    
    return attribs;
}

+ (BOOL) isAttributedStringItemGraph: (COItemGraph *)aGraph equalToItemGraph: (COItemGraph *)anotherGraph
{
    COObjectGraphContext *ctx1 = [COObjectGraphContext new];
    COObjectGraphContext *ctx2 = [COObjectGraphContext new];
    [ctx1 setItemGraph: aGraph];
    [ctx2 setItemGraph: anotherGraph];
    
    COAttributedStringWrapper *actualWrapper = [[COAttributedStringWrapper alloc] initWithBacking: ctx1.rootObject];
    COAttributedStringWrapper *expectedWrapper = [[COAttributedStringWrapper alloc] initWithBacking: ctx2.rootObject];
    
    return [expectedWrapper isEqual: actualWrapper];
}

@end
