/*
    Copyright (C) 2012 Eric Wasylishen

    Date:  March 2012
    License:  MIT  (see COPYING)
 */

#import "COArrayDiff.h"
#include "diff.h"

#import <CoreObject/CoreObject.h>

static bool comparefn(size_t i, size_t j, const void *userdata1, const void *userdata2)
{
    return [((__bridge NSArray *)userdata1)[i] isEqual:
            ((__bridge NSArray *)userdata2)[j]];
}

void CODiffArrays(NSArray *a, NSArray *b, id <CODiffArraysDelegate> delegate, id userInfo)
{
    const diffresult_t *const result = diff_arrays(a.count,
                                                   b.count,
                                                   comparefn,
                                                   (__bridge const void *)(a),
                                                   (__bridge const void *)(b));

    for (size_t i = 0; i < diff_editcount(result); i++)
    {
        const diffedit_t edit = diff_edit_at_index(result, i);

        const NSRange firstRange = NSMakeRange(edit.range_in_a.location, edit.range_in_a.length);
        const NSRange secondRange = NSMakeRange(edit.range_in_b.location, edit.range_in_b.length);

        switch (edit.type)
        {
            case difftype_insertion:
                if (secondRange.length > 0)
                {
                    [delegate recordInsertionWithLocation: firstRange.location
                                          insertedObjects: [b subarrayWithRange: secondRange]
                                                 userInfo: userInfo];
                }
                break;
            case difftype_deletion:
                [delegate recordDeletionWithRange: firstRange
                                         userInfo: userInfo];
                break;
            case difftype_modification:
                [delegate recordModificationWithRange: firstRange
                                      insertedObjects: [b subarrayWithRange: secondRange]
                                             userInfo: userInfo];

                break;
            case difftype_copy:
                break;
        }
    }
    diff_free(result);
}

/**
 * Note: automatically handles "false conflicts", that is, when both
 * diffs make the same edit, this will (correctly) only perform that edit once.
 */
void COApplyEditsToArray(NSMutableArray *array, NSArray *edits)
{
    edits = [edits sortedArrayUsingSelector: @selector(compare:)];

    //NSArray *uniqueEdits = COEditsByUniquingNonconflictingDuplicates(edits);

    const NSUInteger editsCount = edits.count;

    NSInteger i = 0;
    NSInteger nextI = 0;
    NSInteger lastEditStart = -1;
    for (NSUInteger whichEdit = 0; whichEdit < editsCount; whichEdit++)
    {
        COSequenceEdit *op = edits[whichEdit];
        if ((whichEdit + 1) < editsCount)
        {
            COSequenceEdit *nextOp = edits[whichEdit + 1];
            if ([op isEqualIgnoringSourceIdentifier: nextOp])
            {
                // Skip "false conflicts"
                continue;
            }
        }

        if (op.range.location != lastEditStart)
        {
            i = nextI;
        }

        if ([op isMemberOfClass: [COSequenceInsertion class]])
        {
            const COSequenceInsertion *const opp = (COSequenceInsertion *)op;
            const NSRange range = NSMakeRange(op.range.location + i, opp.objects.count);

            [array insertObjects: opp.objects
                       atIndexes: [NSIndexSet indexSetWithIndexesInRange: range]];

            nextI += range.length;
        }
        else if ([op isMemberOfClass: [COSequenceDeletion class]])
        {
            const NSRange range = NSMakeRange(op.range.location + i, op.range.length);

            [array removeObjectsAtIndexes: [NSIndexSet indexSetWithIndexesInRange: range]];
            nextI -= range.length;
        }
        else if ([op isMemberOfClass: [COSequenceModification class]])
        {
            const COSequenceModification *const opp = (COSequenceModification *)op;
            const NSRange deleteRange = NSMakeRange(opp.range.location + i, opp.range.length);
            const NSRange insertRange = NSMakeRange(opp.range.location + i, opp.objects.count);

            [array removeObjectsAtIndexes: [NSIndexSet indexSetWithIndexesInRange: deleteRange]];
            [array insertObjects: opp.objects
                       atIndexes: [NSIndexSet indexSetWithIndexesInRange: insertRange]];
            nextI += (insertRange.length - deleteRange.length);
        }
        else
        {
            [NSException raise: NSInternalInconsistencyException
                        format: @"Unexpected edit type"];
        }

        lastEditStart = op.range.location;
    }
}

NSArray *COArrayByApplyingEditsToArray(NSArray *array, NSArray *edits)
{
    NSMutableArray *mutableArray = [NSMutableArray arrayWithArray: array];
    COApplyEditsToArray(mutableArray, edits);
    return [NSArray arrayWithArray: mutableArray];
}
