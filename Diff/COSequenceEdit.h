/**
    Copyright (C) 2012 Eric Wasylishen

    Date:  March 2012
    License:  MIT  (see COPYING)
 */

#import "COItemGraphEdit.h"

@interface COSequenceEdit : COItemGraphEdit
{
    NSRange range;
}

@property (readonly, nonatomic) NSRange range;

- (NSComparisonResult)compare: (id)otherObject;
- (BOOL)overlaps: (COSequenceEdit *)other;
- (BOOL)touches: (COSequenceEdit *)other;

- (instancetype)initWithUUID: (ETUUID *)aUUID
                   attribute: (NSString *)anAttribute
            sourceIdentifier: (id)aSourceIdentifier
                       range: (NSRange)aRange NS_DESIGNATED_INITIALIZER;

@end
