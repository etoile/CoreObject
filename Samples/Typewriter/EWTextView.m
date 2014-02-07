/*
    Copyright (C) 2014 Eric Wasylishen
 
    Date:  February 2014
    License:  MIT  (see COPYING)
 */

#import "EWTextView.h"
#import "EWDocument.h"
#import <CoreObject/COSQLiteStore+Attachments.h>

@implementation EWTextView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (BOOL)readSelectionFromPasteboard:(NSPasteboard *)pboard type:(NSString *)type
{
    if ([type isEqual: NSFilenamesPboardType])
    {
        NSString *urlString = [[[pboard pasteboardItems] objectAtIndex: 0] stringForType: @"public.file-url"];
        NSURL *url = [NSURL URLWithString: urlString];
        
        EWDocument *doc = [[[self window] windowController] document];
        COAttachmentID *attachmentKey = [doc.editingContext.store importAttachmentFromURL: url];
        assert(attachmentKey != nil);
        
        NSLog(@"------- attaching URL: %@ >>>>> attachment hash: %@", urlString, attachmentKey);
        
        NSFileWrapper *wrapper = [[NSFileWrapper alloc] initWithPath: [url path]];
        NSTextAttachment *attachment = [[NSTextAttachment alloc] initWithFileWrapper: wrapper];
        NSAttributedString *attributedString = [NSAttributedString attributedStringWithAttachment: attachment];

        [[self textStorage] replaceCharactersInRange: [self selectedRange]
                                withAttributedString: attributedString];

        return YES;
    }
    return [super readSelectionFromPasteboard: pboard type: type];
}

@end
