/*
    Copyright (C) 2014 Eric Wasylishen
 
    Date:  April 2014
    License:  MIT  (see COPYING)
 */

#import "EWDiffWindowController.h"

#import "COPersistentRoot+Revert.h"
#import <CoreObject/COAttributedString.h>
#import <CoreObject/COAttributedStringWrapper.h>
#import "COAttributedStringDiff+PrettyPrint.h"
#import "TypewriterDocument.h"

@interface EWDiffWindowController ()
@end


@implementation EWDiffWindowController

- (instancetype)initWithInspectedPersistentRoot: (COPersistentRoot *)aPersistentRoot
{
    self = [super initWithWindowNibName: @"DiffWindow"];

    inspectedPersistentRoot = aPersistentRoot;

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(persistentRootDidChange:)
                                                 name: COPersistentRootDidChangeNotification
                                               object: inspectedPersistentRoot];

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [self update];
}

- (void)persistentRootDidChange: (NSNotification *)notif
{
    [self update];
}

- (void)update
{
    if ([inspectedPersistentRoot revisionToRevertTo] == nil)
    {
        return;
    }

    TypewriterDocument *doc = [[inspectedPersistentRoot objectGraphContext] rootObject];
    COAttributedString *as = doc.attrString;

    COObjectGraphContext *oldDocCtx = [inspectedPersistentRoot objectGraphContextForPreviewingRevision: [inspectedPersistentRoot revisionToRevertTo]];
    TypewriterDocument *oldDoc = [oldDocCtx rootObject];
    COAttributedString *oldAs = oldDoc.attrString;

    if (oldAs == nil)
    {
        return;
    }

    COAttributedStringDiff *diff = [[COAttributedStringDiff alloc] initWithFirstAttributedString: oldAs
                                                                          secondAttributedString: as
                                                                                          source: nil];

    COAttributedStringWrapper *oldAsWrapper = [[COAttributedStringWrapper alloc] initWithBacking: oldAs];

    NSAttributedString *prettyPrinted = [diff prettyPrintedWithSource: oldAsWrapper];

    [[textView textStorage] setAttributedString: prettyPrinted];
}

@end
