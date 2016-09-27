/**
 Copyright (c) 2009-2011 Matt Gallagher. All rights reserved.
 
 This software is provided 'as-is', without any express or implied
 warranty. In no event will the authors be held liable for any
 damages arising from the use of this software. Permission is granted
 to anyone to use this software for any purpose, including commercial
 applications, and to alter it and redistribute it freely, subject to
 the following restrictions:
 
 1. The origin of this software must not be misrepresented; you must
 not claim that you wrote the original software. If you use this
 software in a product, an acknowledgment in the product
 documentation would be appreciated but is not required.
 2. Altered source versions must be plainly marked as such, and must
 not be misrepresented as being the original software.
 3. This notice may not be removed or altered from any source
 distribution.
 */

#import "PrioritySplitViewDelegate.h"


@implementation PrioritySplitViewDelegate


- (void)setMinimumLength:(CGFloat)minLength forViewAtIndex:(NSInteger)viewIndex
{
    if (!lengthsByViewIndex)
    {
        lengthsByViewIndex = [[NSMutableDictionary alloc] initWithCapacity:0];
    }
    [lengthsByViewIndex
        setObject:[NSNumber numberWithDouble:minLength]
        forKey:[NSNumber numberWithInteger:viewIndex]];
}

- (void)setPriority:(NSInteger)priorityIndex forViewAtIndex:(NSInteger)viewIndex
{
    if (!viewIndicesByPriority)
    {
        viewIndicesByPriority = [[NSMutableDictionary alloc] initWithCapacity:0];
    }
    [viewIndicesByPriority
        setObject:[NSNumber numberWithInteger:viewIndex]
        forKey:[NSNumber numberWithInteger:priorityIndex]];
}

- (CGFloat)splitView:(NSSplitView *)sender
    constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset
{
    NSView *subview = [[sender subviews] objectAtIndex:offset];
    NSRect subviewFrame = subview.frame;
    CGFloat frameOrigin;
    if ([sender isVertical])
    {
        frameOrigin = subviewFrame.origin.x;
    }
    else
    {
        frameOrigin = subviewFrame.origin.y;
    }
    
    CGFloat minimumSize =
        [[lengthsByViewIndex objectForKey:[NSNumber numberWithInteger:offset]]
            doubleValue];
    
    return frameOrigin + minimumSize;
}

- (CGFloat)splitView:(NSSplitView *)sender
    constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset
{
    NSView *growingSubview = [[sender subviews] objectAtIndex:offset];
    NSView *shrinkingSubview = [[sender subviews] objectAtIndex:offset + 1];
    NSRect growingSubviewFrame = growingSubview.frame;
    NSRect shrinkingSubviewFrame = shrinkingSubview.frame;
    CGFloat shrinkingSize;
    CGFloat currentCoordinate;
    if ([sender isVertical])
    {
        currentCoordinate =
            growingSubviewFrame.origin.x + growingSubviewFrame.size.width;
        shrinkingSize = shrinkingSubviewFrame.size.width;
    }
    else
    {
        currentCoordinate =
            growingSubviewFrame.origin.y + growingSubviewFrame.size.height;
        shrinkingSize = shrinkingSubviewFrame.size.height;
    }
    
    CGFloat minimumSize =
        [[lengthsByViewIndex objectForKey:[NSNumber numberWithInteger:offset + 1]]
            doubleValue];
    
    return currentCoordinate + (shrinkingSize - minimumSize);
}

- (void)splitView:(NSSplitView *)sender
    resizeSubviewsWithOldSize:(NSSize)oldSize
{
    NSArray *subviews = [sender subviews];
    NSInteger subviewsCount = [subviews count];
    
    BOOL isVertical = [sender isVertical];
    
    CGFloat delta = [sender isVertical] ?
        (sender.bounds.size.width - oldSize.width) :
        (sender.bounds.size.height - oldSize.height);
    
    NSInteger viewCountCheck = 0;
    
    for (NSNumber *priorityIndex in
        [[viewIndicesByPriority allKeys] sortedArrayUsingSelector:@selector(compare:)])
    {
        NSNumber *viewIndex = [viewIndicesByPriority objectForKey:priorityIndex];
        NSInteger viewIndexValue = [viewIndex integerValue];
        if (viewIndexValue >= subviewsCount)
        {
            continue;
        }
        
        NSView *view = [subviews objectAtIndex:viewIndexValue];
        
        NSSize frameSize = [view frame].size;
        NSNumber *minLength = [lengthsByViewIndex objectForKey:viewIndex];
        CGFloat minLengthValue = [minLength doubleValue];
        
        if (isVertical)
        {
            frameSize.height = sender.bounds.size.height;
            if (delta > 0 ||
                frameSize.width + delta >= minLengthValue)
            {
                frameSize.width += delta;
                delta = 0;
            }
            else if (delta < 0)
            {
                delta += frameSize.width - minLengthValue;
                frameSize.width = minLengthValue;
            }
        }
        else
        {
            frameSize.width = sender.bounds.size.width;
            if (delta > 0 ||
                frameSize.height + delta >= minLengthValue)
            {
                frameSize.height += delta;
                delta = 0;
            }
            else if (delta < 0)
            {
                delta += frameSize.height - minLengthValue;
                frameSize.height = minLengthValue;
            }
        }
        
        [view setFrameSize:frameSize];
        viewCountCheck++;
    }
    
    NSAssert1(viewCountCheck == [subviews count],
        @"Number of valid views in priority list is less than the subview count"
        @" of split view %p.",
        sender);
    NSAssert3(fabs(delta) < 0.5,
        @"Split view %p resized smaller than minimum %@ of %f",
        sender,
        isVertical ? @"width" : @"height",
        sender.frame.size.width - delta);
    
    CGFloat offset = 0;
    CGFloat dividerThickness = [sender dividerThickness];
    for (NSView *subview in subviews)
    {
        NSRect viewFrame = subview.frame;
        NSPoint viewOrigin = viewFrame.origin;
        viewOrigin.x = offset;
        [subview setFrameOrigin:viewOrigin];
        offset += viewFrame.size.width + dividerThickness;
    }
}

@end




