/*
    Copyright (C) 2012 Eric Wasylishen

    Date:  March 2012
    License:  MIT  (see COPYING)
 */

#import "COSequenceEdit.h"
#import "COSequenceDeletion.h"
#import "COSequenceInsertion.h"
#import "COSequenceModification.h"
#import <EtoileFoundation/Macros.h>

static BOOL COOverlappingRanges(NSRange r1, NSRange r2)
{
    return (r1.location >= r2.location && r1.location < (r2.location + r2.length) && r1.length > 0)
    || (r2.location >= r1.location && r2.location < (r1.location + r1.length) && r2.length > 0);
}

@implementation COSequenceEdit

@synthesize range;

- (instancetype) initWithUUID: (ETUUID *)aUUID
                    attribute: (NSString *)anAttribute
             sourceIdentifier: (id)aSourceIdentifier
                        range: (NSRange)aRange
{
    NILARG_EXCEPTION_TEST(aUUID);
    NILARG_EXCEPTION_TEST(anAttribute);

    self = [super initWithUUID: aUUID attribute: anAttribute sourceIdentifier: aSourceIdentifier];
    if (self == nil)
        return nil;

    range = aRange;
    return self;
}

- (instancetype)initWithUUID: (ETUUID *)aUUID
                   attribute: (NSString *)anAttribute
            sourceIdentifier: (id)aSourceIdentifier
{
    return [self initWithUUID: nil
                    attribute: nil
             sourceIdentifier: nil
                        range: NSMakeRange(0, 0)];
}

- (instancetype)init
{
    return [self initWithUUID: nil
                    attribute: nil
             sourceIdentifier: nil
                        range: NSMakeRange(0, 0)];
}

static NSDictionary *classSortOrder;

+ (void) initialize
{
    if (self == [COSequenceEdit class])
    {
        classSortOrder = @{ NSStringFromClass([COSequenceDeletion class]) : @0,
                            NSStringFromClass([COSequenceModification class]) : @0,
                            NSStringFromClass([COSequenceInsertion class]) : @1 };
    }
}

- (NSComparisonResult) compare: (COSequenceEdit*)other
{
    if (other.range.location > self.range.location)
    {
        return NSOrderedAscending;
    }
    if (other.range.location == self.range.location)
    {
        NSNumber *selfOrder = classSortOrder[NSStringFromClass([self class])];
        NSNumber *otherOrder = classSortOrder[NSStringFromClass([other class])];
        
        assert(selfOrder != nil);
        assert(otherOrder != nil);
        
        if (selfOrder.intValue > otherOrder.intValue)
        {
            return NSOrderedDescending;
        }
        else if (selfOrder.intValue < otherOrder.intValue)
        {
            return NSOrderedAscending;
        }
        else
        {
            return NSOrderedSame;
        }
    }
    else
    {
        return NSOrderedDescending;
    }
}

- (BOOL) overlaps: (COSequenceEdit *)other
{
    return COOverlappingRanges(range, other.range);
}

- (BOOL) touches: (COSequenceEdit *)other
{
    if (COOverlappingRanges(range, other.range))
    {
        return YES;
    }
    
    if (range.location == NSMaxRange(other.range))
        return YES;
    
    if (range.location == other.range.location)
        return YES;
    
    if (NSMaxRange(range) == NSMaxRange(other.range))
        return YES;
    
    if (NSMaxRange(range) == other.range.location)
        return YES;

    return NO;
}

- (BOOL) isEqualIgnoringSourceIdentifier:(id)other
{
    return [super isEqualIgnoringSourceIdentifier: other]
    && NSEqualRanges(range, ((COSequenceEdit*)other).range);
}

- (NSUInteger) hash
{
    return 9723954873297612448ULL ^ super.hash ^ range.location ^ range.length;
}

- (BOOL) isSameKindOfEdit: (COItemGraphEdit*)anEdit
{
    return [anEdit isKindOfClass: [COSequenceEdit class]];
}

@end
