/*
    Copyright (C) 2014 Eric Wasylishen
 
    Date:  April 2014
    License:  MIT  (see COPYING)
 */

#import "COAttributedStringDiff+PrettyPrint.h"
#import <CoreObject/COAttributedStringWrapper.h>

@implementation COAttributedStringDiff (PrettyPrint)


#pragma mark - Utility -


- (NSMutableAttributedString *)attributedStringForItemGraph: (COItemGraph *)aGraph
{
    COObjectGraphContext *ctx = [[COObjectGraphContext alloc] init];
    [ctx setItemGraph: aGraph];
    COAttributedStringWrapper *wrapper = [[COAttributedStringWrapper alloc] initWithBacking: ctx.rootObject];
    return [[NSMutableAttributedString alloc] initWithAttributedString: wrapper];
}


#pragma mark - Handlers for operation types -


- (NSInteger)handleInsertion: (COAttributedStringDiffOperationInsertAttributedSubstring *)op
               currentOffset: (NSInteger)offset
                      target: (NSMutableAttributedString *)string
{
    NSDictionary *insertionAttribs = @{NSForegroundColorAttributeName: [NSColor greenColor],
                                       NSFontAttributeName: [NSFont boldSystemFontOfSize: [NSFont systemFontSize]]};

    const NSRange range = NSMakeRange([op range].location + offset, [op range].length);

    NSMutableAttributedString *insertion = [self attributedStringForItemGraph: [op attributedStringItemGraph]];
    [insertion addAttributes: insertionAttribs range: NSMakeRange(0, [insertion length])];
    [string insertAttributedString: insertion
                           atIndex: range.location];

    return [insertion length];
}

- (NSInteger)handleDeletion: (COAttributedStringDiffOperationDeleteRange *)op
              currentOffset: (NSInteger)offset
                     target: (NSMutableAttributedString *)string
{
    NSDictionary *deletionAttribs = @{NSForegroundColorAttributeName: [[NSColor redColor] colorWithAlphaComponent: 0.3],
                                      NSStrikethroughStyleAttributeName: [NSNumber numberWithInteger: NSUnderlineStyleSingle]};


    NSRange range = NSMakeRange([op range].location + offset, [op range].length);

    [string addAttributes: deletionAttribs range: range];

    return 0;
}

- (NSInteger)handleReplacement: (COAttributedStringDiffOperationReplaceRange *)op
                 currentOffset: (NSInteger)offset
                        target: (NSMutableAttributedString *)string
{
    NSDictionary *modifyDeletionAttribs = @{NSForegroundColorAttributeName: [[NSColor redColor] colorWithAlphaComponent: 0.3],
                                            NSStrikethroughStyleAttributeName: [NSNumber numberWithInteger: NSUnderlineStyleSingle]};

    NSDictionary *modifyInsertionAttribs = @{NSForegroundColorAttributeName: [NSColor colorWithCalibratedRed: 0
                                                                                                       green: 0.5
                                                                                                        blue: 0
                                                                                                       alpha: 1],
                                             NSFontAttributeName: [NSFont boldSystemFontOfSize: [NSFont systemFontSize]]};

    NSRange range = NSMakeRange([op range].location + offset, [op range].length);
    [string setAttributes: modifyDeletionAttribs range: range];

    NSMutableAttributedString *insertion = [self attributedStringForItemGraph: [op attributedStringItemGraph]];
    [insertion addAttributes: modifyInsertionAttribs range: NSMakeRange(0, [insertion length])];
    [string insertAttributedString: insertion
                           atIndex: range.location + range.length];

    return [insertion length];
}

- (NSInteger)handleAddAttribute: (COAttributedStringDiffOperationAddAttribute *)op
                  currentOffset: (NSInteger)offset
                         target: (NSMutableAttributedString *)string
{
    // TODO: Do something to indicate an attribute was added
    return 0;
}

- (NSInteger)handleRemoveAttribute: (COAttributedStringDiffOperationRemoveAttribute *)op
                     currentOffset: (NSInteger)offset
                            target: (NSMutableAttributedString *)string
{
    // TODO: Do something to indicate an attribute was removed
    return 0;
}

- (NSInteger)handleOp: (id <COAttributedStringDiffOperation>)op
        currentOffset: (NSInteger)offset
               target: (NSMutableAttributedString *)string
{
    if ([op isKindOfClass: [COAttributedStringDiffOperationInsertAttributedSubstring class]])
    {
        return [self handleInsertion: (COAttributedStringDiffOperationInsertAttributedSubstring *)op
                       currentOffset: offset
                              target: string];
    }
    else if ([op isKindOfClass: [COAttributedStringDiffOperationDeleteRange class]])
    {
        return [self handleDeletion: (COAttributedStringDiffOperationDeleteRange *)op
                      currentOffset: offset
                             target: string];
    }
    else if ([op isKindOfClass: [COAttributedStringDiffOperationReplaceRange class]])
    {
        return [self handleReplacement: (COAttributedStringDiffOperationReplaceRange *)op
                         currentOffset: offset
                                target: string];
    }
    else if ([op isKindOfClass: [COAttributedStringDiffOperationAddAttribute class]])
    {
        return [self handleAddAttribute: (COAttributedStringDiffOperationAddAttribute *)op
                          currentOffset: offset
                                 target: string];
    }
    else if ([op isKindOfClass: [COAttributedStringDiffOperationRemoveAttribute class]])
    {
        return [self handleRemoveAttribute: (COAttributedStringDiffOperationRemoveAttribute *)op
                             currentOffset: offset
                                    target: string];
    }
    else
    {
        [NSException raise: NSInvalidArgumentException format: @"Unexpected operation %@", op];
        return 0;
    }
}


#pragma mark - Main methods -


- (void)prettyPrintWithAttributedString: (NSMutableAttributedString *)string
{
    NSInteger i = 0;
    for (id <COAttributedStringDiffOperation> op in self.operations)
    {
        i += [self handleOp: op currentOffset: i target: string];
    }
}

- (NSAttributedString *)prettyPrintedWithSource: (NSAttributedString *)string
{
    NSMutableAttributedString *mutableString = [[NSMutableAttributedString alloc] initWithAttributedString: string];
    [self prettyPrintWithAttributedString: mutableString];
    return mutableString;
}

@end
