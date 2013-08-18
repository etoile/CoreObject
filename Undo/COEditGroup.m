#import "COEditGroup.h"

static NSString * const kCOEditContents = @"COEditContents";

@implementation COEditGroup

@synthesize  contents = _contents;

- (id) initWithPlist: (id)plist
{
    self = [super initWithPlist: plist];
    
    NSMutableArray *edits = [NSMutableArray array];
    for (id editPlist in [plist objectForKey: kCOEditContents])
    {
        COEdit *subEdit = [COEdit editWithPlist: editPlist];
        [edits addObject: subEdit];
    }
    
    self.contents = edits;
    return self;
}

- (id) plist
{
    NSMutableDictionary *result = [super plist];
    
    NSMutableArray *edits = [NSMutableArray array];
    for (COEdit *subEdit in _contents)
    {
        id subEditPlist = [subEdit plist];
        [edits addObject: subEditPlist];
    }
    [result setObject: edits forKey: kCOEditContents];
    return result;
}

- (COEdit *) inverse
{
    COEditGroup *inverse = [[super copyWithZone: NSDefaultMallocZone()] autorelease];
    
    NSMutableArray *edits = [NSMutableArray array];
    for (COEdit *subEdit in _contents)
    {
        COEdit *subEditInverse = [subEdit inverse];
        [edits addObject: subEditInverse];
    }
    inverse.contents = edits;
    
    return inverse;
}

- (BOOL) canApplyToContext: (COEditingContext *)aContext
{
    for (COEdit *subEdit in _contents)
    {
        if (![subEdit canApplyToContext: aContext])
        {
            return NO;
        }
    }
    return YES;
}

- (void) applyToContext: (COEditingContext *)aContext
{
    for (COEdit *subEdit in _contents)
    {
        [subEdit applyToContext: aContext];
    }
}

@end
