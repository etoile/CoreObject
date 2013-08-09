#import <Cocoa/Cocoa.h>
#import <CoreObject/CoreObject.h>

@interface EWTextStorage : NSTextStorage
{
    ETUUID *_rootUUID;
    
    NSMutableAttributedString *backing_;
    
    NSMutableSet *paragraphsChangedDuringEditing_;
}

- (id) initWithDocumentUUID: (ETUUID *)aUUID;

- (BOOL) setTypewriterDocument: (id <COItemGraph>)aTree;
- (id <COItemGraph>) typewriterDocument;
- (COItem *) paragraphTreeForUUID: (ETUUID *)aUUID;

// FIXME: we will need the ability to incrementally update an EWTextStorage
// by writing a new root node and supplying the relevant added/modified paragraph
// nodes.


- (NSArray *) paragraphUUIDs;

- (NSRange) rangeForParagraphWithUUID: (ETUUID *)aUUID;

- (NSAttributedString *) attributedStringForParagraphWithUUID: (ETUUID *)aUUID;

- (NSArray *) paragraphUUIDsChangedDuringEditing;

@end
