#import "EWTextStorage.h"

@implementation EWTextStorage

- (id) initWithDocumentUUID: (ETUUID *)aUUID
{
    NILARG_EXCEPTION_TEST(aUUID);
    
    self = [super init];
    
    ASSIGN(_rootUUID, aUUID);
    backing_ = [[NSMutableAttributedString alloc] init];
    paragraphsChangedDuringEditing_ = [[NSMutableSet alloc] init];
    
    return self;
}

- (void) dealloc
{
    [_rootUUID release];
    [paragraphsChangedDuringEditing_ release];
    [backing_ release];
    [super dealloc];
}

// Model access

- (NSArray *) paragraphUUIDs
{
    return [self paragraphUUIDSOverlappingRange: NSMakeRange(0, [backing_ length])];
}

- (NSRange) rangeForParagraphWithUUID: (id)aUUID
{
    NSRange limitRange = NSMakeRange(0, [backing_ length]);
    
    while (limitRange.length > 0)
    {
        NSRange effectiveRange;
        id attributeValue = [backing_ attribute: kCOParagraphUUIDAttribute
                                        atIndex: limitRange.location
                          longestEffectiveRange: &effectiveRange
                                        inRange: limitRange];
        
        if ([attributeValue isEqual: aUUID])
        {
            NSLog(@"found range: %@", NSStringFromRange(effectiveRange));
            return effectiveRange;
        }
        
        limitRange = NSMakeRange(NSMaxRange(effectiveRange),
                                 NSMaxRange(limitRange) - NSMaxRange(effectiveRange));
    }
    return NSMakeRange(NSNotFound, 0);
}

- (NSAttributedString *) attributedStringForParagraphWithUUID: (id)aUUID
{
    return [self attributedSubstringFromRange: [self rangeForParagraphWithUUID: aUUID]];
}

- (NSArray *) paragraphUUIDSOverlappingRange: (NSRange)aRange
{
    NSRange effectiveRange = NSMakeRange(aRange.location, 0);
    //NSUInteger length = [backing_ length];
    
    NSMutableArray *list = [NSMutableArray array];
    
    while (NSMaxRange(effectiveRange) < NSMaxRange(aRange))
    {
        id attributeValue = [backing_ attribute:kCOParagraphUUIDAttribute
                                        atIndex:NSMaxRange(effectiveRange)
                                 effectiveRange:&effectiveRange];
        [list addObject: attributeValue];
    }
    
    return list;
}

- (ETUUID *) paragraphUUIDAtIndex: (NSUInteger)index
{
    return [backing_ attribute: kCOParagraphUUIDAttribute
                       atIndex: index
                effectiveRange: NULL];
}

// Overrides for primitive methods

/**
 * Should be O(1)
 */
- (NSString *)string
{
    //NSLog(@"EWTextStorage -string");
    return [backing_ string];
}

- (NSDictionary *)attributesAtIndex:(NSUInteger)index effectiveRange:(NSRangePointer)aRange
{
    //NSLog(@"EWTextStorage -attributesAtIndex:effectiveRange:");
    
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:
                                    [backing_ attributesAtIndex: index effectiveRange: aRange]];
    
    [result removeObjectForKey: kCOParagraphUUIDAttribute];
    
    return result;
}

static NSString *kCOParagraphUUIDAttribute = @"COParagraphUUIDAttribute";

static NSRange paragraphRangeForLocationInString(NSString *aString, NSUInteger aLocation)
{
    NSUInteger paraStart = 0, paraEnd = 0;
    [aString getParagraphStart: &paraStart
                           end: &paraEnd
                   contentsEnd: NULL
                      forRange: NSMakeRange(aLocation, 0)];
    
    return NSMakeRange(paraStart, paraEnd - paraStart);
}

- (void) debug
{
    NSRange limitRange;
    NSRange effectiveRange;
    id attributeValue;
    
    limitRange = NSMakeRange(0, [backing_ length]);
    
    NSLog(@"DEBUG LOG");
    while (limitRange.length > 0) {
        attributeValue = [backing_ attribute:kCOParagraphUUIDAttribute
                                    atIndex:limitRange.location longestEffectiveRange:&effectiveRange
                                    inRange:limitRange];

        NSLog(@"    paragraph %@: '%@'", attributeValue, [[backing_ string] substringWithRange: effectiveRange]);
        
        limitRange = NSMakeRange(NSMaxRange(effectiveRange),
                                 NSMaxRange(limitRange) - NSMaxRange(effectiveRange));
    }
}

- (void)replaceCharactersInRange:(NSRange)replacementRange
                      withString:(NSString *)replacementString
{
    //NSLog(@"EWTextStorage -replaceCharactersInRange:withString:");
    
    // Count up modified paragraphs
    
    NSMutableSet *modifiedParagraphs = [NSMutableSet set];
    [modifiedParagraphs addObjectsFromArray: [self paragraphUUIDSOverlappingRange: replacementRange]];    
    
    
    // Perform the change
    
    [backing_ replaceCharactersInRange: replacementRange withString: replacementString];
    
    const NSRange rangeAfterEdit = NSMakeRange(replacementRange.location,
                                               [replacementString length]);
    
    // Update paragraph metadata
    
    // FIXME: Typing at the start of a paragraph causes it to get a new UUID
    
    
    NSString *string = [self string];
    
    NSUInteger i = rangeAfterEdit.location;
    
    // 1. if i is currently in the middle of a paragraph,
    // extend that paragraph's UUID up to the end of the paragraph.
    
    ETUUID *firstAssignedUUID = nil;
    
    NSRange firstPara = paragraphRangeForLocationInString(string, rangeAfterEdit.location);
    if (firstPara.location != i)
    {
        ETUUID *firstParaUUID = [self paragraphUUIDAtIndex: firstPara.location];
        firstAssignedUUID = firstParaUUID;
        
        [modifiedParagraphs addObject: firstParaUUID];
        
//        if (firstParaUUID == nil)
//        {
//            // Should only happen on first insertion into an empty text storage
//            firstParaUUID = [COUUID UUID];
//            NSLog(@"assigned new UUID %@ to start of edit", firstParaUUID);
//        }
        
        [backing_ addAttribute: kCOParagraphUUIDAttribute value: firstParaUUID range: firstPara];
                
        NSLog(@"first paragraph edited (%@) was '%@'", firstParaUUID, [string substringWithRange: firstPara]);
        
        i = NSMaxRange(firstPara);
    }
    
    // 2. Now, (and the loop invariant):
    // either i is at the start of a paragraph to process, or it is at the
    // start of an existing paragraph, in which case we are done.
    
    while (i < [backing_ length])
    {
        ETUUID *paraUUID = [self paragraphUUIDAtIndex: i];
        
        if (firstAssignedUUID == nil)
        {
            firstAssignedUUID = paraUUID;
        }
        
        if (paraUUID != nil && ![paraUUID isEqual: firstAssignedUUID])
        {
            break;
        }
        
        NSRange para = paragraphRangeForLocationInString(string, i);  
        ETUUID *newUUID = [ETUUID UUID];
        
        [modifiedParagraphs addObject: newUUID];
        
        [backing_ addAttribute: kCOParagraphUUIDAttribute value: newUUID range: para];
        
        NSLog(@"subsequent paragraph edited assigned new uuid (%@) was '%@'", newUUID, [string substringWithRange: para]);
        
        i = NSMaxRange(para);
    }
    
    [self debug];
    
    [paragraphsChangedDuringEditing_ unionSet: modifiedParagraphs];
    //NSLog(@"---modified paragraphs: %@", modifiedParagraphs);
    
    [self edited: NSTextStorageEditedCharacters
           range: replacementRange
  changeInLength: rangeAfterEdit.length - replacementRange.length];
}

- (void)setAttributes:(NSDictionary *)attributes range:(NSRange)aRange
{
    //NSLog(@"EWTextStorage -setAttributes:range:");
    
    // We don't call setAttributes:range: so as not to disturb the kCOParagraphUUIDAttribute
    
    for (NSString *attr in attributes)
    {
        [backing_ removeAttribute: attr range: aRange];
    }
    
    [backing_ addAttributes: attributes range: aRange];
    
    NSArray *modifiedParagraphs = [self paragraphUUIDSOverlappingRange: aRange];
    [paragraphsChangedDuringEditing_ addObjectsFromArray: modifiedParagraphs];
    //NSLog(@"---modified (attrs) paragraphs: %@", modifiedParagraphs);
    
    // FIXME: Remove, this was just an experiment
    NSTextAttachment *attachment = [attributes objectForKey: NSAttachmentAttributeName];
    if (nil != attachment)
    {
        NSFileWrapper *wrapper = [attachment fileWrapper];
        NSData *data = [wrapper regularFileContents];
        NSLog(@"Attachment data: %lu bytes",(unsigned long) [data length]);
    }
    
    [self edited: NSTextStorageEditedAttributes
           range: aRange
  changeInLength: 0];
}

// Change tracking

- (void) beginEditing
{
    [paragraphsChangedDuringEditing_ removeAllObjects];
    [super beginEditing];
}

- (NSArray *) paragraphUUIDsChangedDuringEditing
{
    return [paragraphsChangedDuringEditing_ allObjects];
}

// Input/output

- (BOOL) setTypewriterDocument: (id <COItemGraph>)aTree
{
    NSMutableAttributedString *result = [[[NSMutableAttributedString alloc] init] autorelease];

    ASSIGN(_rootUUID, [aTree rootItemUUID]);
    
    COItem *rootItem = [aTree itemForUUID: [aTree rootItemUUID]];
    
    for (ETUUID *paragraphUUID in [rootItem valueForAttribute: @"paragraphs"])
    {
        COItem *paragraph = [aTree itemForUUID: paragraphUUID];
        if ([paragraph typeForAttribute: @"data"] != kCOBlobType)
        {
            return NO;
        }
        
        NSData *rtf = [paragraph valueForAttribute: @"data"];
        
        NSAttributedString *paragraphAttrString = [[NSAttributedString alloc] initWithRTF: rtf
                                                                       documentAttributes: NULL];
        
        if (paragraphAttrString == nil)
        {
            return NO;
        }
        
        NSLog(@"appending paragraph: '%@'", [paragraphAttrString string]);
        [result appendAttributedString: paragraphAttrString];
    }

    [self beginEditing];
    [self setAttributedString: result];
    [self endEditing];

    return YES;
}

- (id <COItemGraph>) typewriterDocument
{
    NSMutableArray *items = [NSMutableArray array];
    // Writes out the contents of the text storage as a typewriter document
    
    COMutableItem *result = [COMutableItem itemWithUUID: _rootUUID];
    // HACK: This is an implementation detail of COObject
    [result setValue: @"Anonymous.TypewriterDocument" forAttribute: @"org.etoile-project.coreobject.entityname" type: kCOStringType];
    
    [items addObject: result];
    
    NSLog(@"dumping typewriterDocument");
    for (ETUUID *paragraphUUID in [self paragraphUUIDs])
    {
        NSLog(@"UUID: %@", paragraphUUID);
        COItem *paragraphTree = [self paragraphTreeForUUID: paragraphUUID];
        [items addObject: paragraphTree];
        
        [result addObject: [paragraphTree UUID]
       toOrderedAttribute: @"paragraphs"
                  atIndex: [[result valueForAttribute: @"paragraphs"] count]
                     type: kCOCompositeReferenceType | kCOArrayType];
    }
    
    return [[COItemGraph alloc] initWithItems: items rootItemUUID: _rootUUID];
}

- (COItem *) paragraphTreeForUUID: (ETUUID *)paragraphUUID
{
    NSAttributedString *paragraphAttrString = [self attributedStringForParagraphWithUUID: paragraphUUID];
    NSData *paragraphAsRTF = [paragraphAttrString RTFFromRange: NSMakeRange(0, [paragraphAttrString length])
                                            documentAttributes: nil];
    
    COMutableItem *paragraphTree = [[[COMutableItem alloc] initWithUUID: paragraphUUID] autorelease];
    [paragraphTree setValue: paragraphAsRTF
               forAttribute: @"data"
                       type: kCOBlobType];
    // HACK: This is an implementation detail of COObject
    [paragraphTree setValue: @"Anonymous.TypewriterParagraph" forAttribute: @"org.etoile-project.coreobject.entityname" type: kCOStringType];
    
    return paragraphTree;
}

@end
