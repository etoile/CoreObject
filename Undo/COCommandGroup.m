#import "COCommandGroup.h"
#import <EtoileFoundation/Macros.h>

static NSString * const kCOCommandContents = @"COCommandContents";

@implementation COCommandGroup

@synthesize contents = _contents;

- (id)init
{
    SUPERINIT;
    _contents = [[NSMutableArray alloc] init];
    return self;
}

- (id) initWithPlist: (id)plist
{
    SUPERINIT;
    
    NSMutableArray *edits = [NSMutableArray array];
    for (id editPlist in [plist objectForKey: kCOCommandContents])
    {
        COCommand *subEdit = [COCommand commandWithPlist: editPlist];
        [edits addObject: subEdit];
    }
    
    self.contents = edits;
    return self;
}

- (id) plist
{
    NSMutableDictionary *result = [super plist];
    
    NSMutableArray *edits = [NSMutableArray array];
    for (COCommand *subEdit in _contents)
    {
        id subEditPlist = [subEdit plist];
        [edits addObject: subEditPlist];
    }
    [result setObject: edits forKey: kCOCommandContents];
    return result;
}

- (COCommand *) inverse
{
    COCommandGroup *inverse = [[COCommandGroup alloc] init];
    
    NSMutableArray *edits = [NSMutableArray array];
    for (COCommand *subEdit in _contents)
    {
        COCommand *subEditInverse = [subEdit inverse];
        [edits addObject: subEditInverse];
    }
    inverse.contents = edits;
    
    return inverse;
}

- (BOOL) canApplyToContext: (COEditingContext *)aContext
{
    for (COCommand *subEdit in _contents)
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
    for (COCommand *subEdit in _contents)
    {
        [subEdit applyToContext: aContext];
    }
}

@end
