// SKTTextArea.m
// Sketch Example
//

#import "SKTTextArea.h"
#import "SKTGraphicView.h"
#import "SKTDrawDocument.h"
#import "DrawingController.h"

@implementation SKTTextArea

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [self newBasicEntityDescription];
	
	ETPropertyDescription *attrStrProperty = [ETPropertyDescription descriptionWithName: @"attrStr"
																					  type: (id)@"COAttributedString"];
    [attrStrProperty setPersistent: YES];
    [entity setPropertyDescriptions: A(attrStrProperty)];
	
    return entity;
}

- (instancetype) initWithObjectGraphContext:(COObjectGraphContext *)aContext
{
	self = [super initWithObjectGraphContext: aContext];
	
	[self setAttrStr: [[COAttributedString alloc] initWithObjectGraphContext: aContext]];
	
	return self;
}

- (void)dealloc 
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (COAttributedString *) attrStr
{
	return [self valueForVariableStorageKey: @"attrStr"];
}

- (void) setAttrStr: (COAttributedString *)attrStr
{
	// Set the value
	[self willChangeValueForProperty: @"attrStr"];
	[self setValue: attrStr forVariableStorageKey: @"attrStr"];
	[self didChangeValueForProperty: @"attrStr"];
	
	// After
	
	[textStorage setBacking: attrStr];
}

- (NSTextStorage *) contents
{
	if (textStorage == nil)
	{
		textStorage = [[COAttributedStringWrapper alloc] initWithBacking: [self attrStr]];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(SKT_contentsChanged:) name:NSTextStorageDidProcessEditingNotification object:textStorage];
	}
	
	return textStorage;
}

- (void)SKT_contentsChanged:(NSNotification *)notification 
{
    // MF:!!! We won't be able to undo piecemeal changes to the text currently.
    [self didChange];
}

- (BOOL)drawsStroke 
{
    // Never draw stroke.
    return NO;
}

- (BOOL)canDrawStroke 
{
    // Never draw stroke.
    return NO;
}

NSArray *makeLMAndTC()
{
	NSTextContainer *tc = [[NSTextContainer new] initWithContainerSize:NSMakeSize(1.0e6, 1.0e6)];
	NSLayoutManager *lm = [[NSLayoutManager new] init];

	[tc setWidthTracksTextView:NO];
	[tc setHeightTracksTextView:NO];
	[lm addTextContainer:tc];

    return @[lm, tc];
}

- (void)drawInView:(SKTGraphicView *)view isSelected:(BOOL)flag 
{
    NSRect bounds = [self bounds];
    if ([self drawsFill]) 
	{
        [[self fillColor] set];
        NSRectFill(bounds);
    }
    if (([view editingGraphic] == self) || ([view creatingGraphic] == self))
	{
        [[NSColor knobColor] set];
        NSFrameRect(NSInsetRect(bounds, -1.0, -1.0));
        // If we are creating we have no text.  If we are editing, the editor (ie NSTextView) will draw the text.
    }
	else 
	{
        NSTextStorage *contents = [self contents];
        if ([contents length] > 0) 
		{
			NSArray *lmAndTc = makeLMAndTC();
            NSLayoutManager *lm = lmAndTc[0];
            NSTextContainer *tc = lmAndTc[1];
            NSRange glyphRange;

            [tc setContainerSize:bounds.size];
            [contents addLayoutManager:lm];
            // Force layout of the text and find out how much of it fits in the container.
            glyphRange = [lm glyphRangeForTextContainer:tc];
			//glyphRange.length  = 100;	

            if (glyphRange.length > 0) 
			{
                [lm drawBackgroundForGlyphRange:glyphRange atPoint:bounds.origin];
                [lm drawGlyphsForGlyphRange:glyphRange atPoint:bounds.origin];
            }
            [contents removeLayoutManager:lm];
        }
    }
    [super drawInView:view isSelected:flag];
}

- (NSSize)minSize 
{
    return NSMakeSize(10.0, 15.0);
}

static const float SKTRightMargin = 36.0;

- (NSSize)maxSize 
{
	return NSMakeSize(1.0e6, 1.0e6);
}

- (NSSize)requiredSize:(float)maxWidth 
{
    NSTextStorage *contents = [self contents];
    NSSize minSize = [self minSize];
    NSSize maxSize = [self maxSize];
    unsigned len = [contents length];
    
    if (len > 0) 
	{
		NSArray *lmAndTc = makeLMAndTC();
		NSLayoutManager *lm = lmAndTc[0];
		NSTextContainer *tc = lmAndTc[1];
        NSRange glyphRange;
        NSSize requiredSize;
        
        [tc setContainerSize: NSMakeSize(((maxSize.width < maxWidth) ? maxSize.width : maxWidth), maxSize.height)];
        [contents addLayoutManager:lm];
        // Force layout of the text and find out how much of it fits in the container.
        glyphRange = [lm glyphRangeForTextContainer:tc];

        requiredSize = [lm usedRectForTextContainer:tc].size;
        requiredSize.width += 1.0;

        if (requiredSize.width < minSize.width) 
		{
            requiredSize.width = minSize.width;
        }
        if (requiredSize.height < minSize.height) 
		{
            requiredSize.height = minSize.height;
        }

        [contents removeLayoutManager:lm];
        return requiredSize;
    }
	else 
	{
        return minSize;
    }
}

- (void)makeNaturalSize 
{
    NSRect bounds = [self bounds];
    NSSize requiredSize = [self requiredSize:1.0e6];
    bounds.size = requiredSize;
    [self setBounds:bounds];
}

- (void)setBounds:(NSRect)rect 
{
    // We need to make sure there's enough room for the text.
    NSSize minSize = [self minSize];
    if (minSize.width > rect.size.width) {
        rect.size.width = minSize.width;
    }
    if (minSize.height > rect.size.height) {
        rect.size.height = minSize.height;
    }
    [super setBounds:rect];
}

- (int)resizeByMovingKnob:(int)knob toPoint:(NSPoint)point 
{
    NSSize minSize = [self minSize];
    NSRect bounds = [self bounds];

    // This constrains the size to be big enough for the text.  It is different from the constraining in -setBounds since it takes into account which corner or edge is moving to figure out which way to grow the bounds if necessary.
    if ((knob == UpperLeftKnob) || (knob == MiddleLeftKnob) || (knob == LowerLeftKnob)) 
	{
        // Adjust left edge
        if ((NSMaxX(bounds) - point.x) < minSize.width) 
		{
            point.x -= minSize.width - (NSMaxX(bounds) - point.x);
        }
    }
	else if ((knob == UpperRightKnob) || (knob == MiddleRightKnob) || (knob == LowerRightKnob)) 
	{
        // Adjust right edge
        if ((point.x - bounds.origin.x) < minSize.width) {
            point.x += minSize.width - (point.x - bounds.origin.x);
        }
    }
    if ((knob == UpperLeftKnob) || (knob == UpperMiddleKnob) || (knob == UpperRightKnob)) {
        // Adjust top edge
        if ((NSMaxY(bounds) - point.y) < minSize.height) 
		{
            point.y -= minSize.height - (NSMaxY(bounds) - point.y);
        }
    }
	else if ((knob == LowerLeftKnob) || (knob == LowerMiddleKnob) || (knob == LowerRightKnob)) 
	{
        // Adjust bottom edge
        if ((point.y - bounds.origin.y) < minSize.height) 
		{
            point.y += minSize.height - (point.y - bounds.origin.y);
        }
    }
    
    return [super resizeByMovingKnob:knob toPoint:point];
}

- (BOOL)isEditable 
{
    return YES;
}

static NSArray *makeLM_TC_TV()
{
    NSLayoutManager *lm = [[NSLayoutManager alloc] init];
    NSTextContainer *tc = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(1.0e6, 1.0e6)];
    NSTextView *tv = [[NSTextView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 100.0, 100.0) textContainer:nil];

    [lm addTextContainer:tc];

    [tv setTextContainerInset:NSMakeSize(0.0, 0.0)];
    [tv setDrawsBackground:NO];
    [tv setAllowsUndo:YES];
    [tc setTextView:tv];

	assert([tv layoutManager] == lm);
	assert([tv textContainer] == tc);
	
    return @[lm, tc, tv];
}

- (void)startEditingWithEvent:(NSEvent *)event inView:(SKTGraphicView *)view 
{
	NSLayoutManager *lm;
	NSTextContainer *tc;
	NSTextView *editor;
    NSTextStorage *contents = [self contents];
    NSSize maxSize = [self maxSize];
    NSSize minSize = [self minSize];
    NSRect bounds = [self bounds];
    
	NSArray *lmTcTv = makeLM_TC_TV();
	lm = lmTcTv[0];
	tc = lmTcTv[1];
	editor = lmTcTv[2];
	
    [tc setWidthTracksTextView:NO];
    if (NSWidth(bounds) > minSize.width + 1.0) 
	{
        // If we are bigger than the minimum width we assume that someone already edited this SKTTextArea or that they created it by dragging out a rect.  In either case, we figure the width should remain fixed.
        [tc setContainerSize:NSMakeSize(NSWidth(bounds), maxSize.height)];
        [editor setHorizontallyResizable:NO];
    }
	else 
	{
        [tc setContainerSize:maxSize];
        [editor setHorizontallyResizable:YES];
    }
    [editor setMinSize:minSize];
    [editor setMaxSize:maxSize];
    [tc setHeightTracksTextView:NO];
    [editor setVerticallyResizable:YES];
    [editor setFrame:bounds];

    [contents addLayoutManager:lm];
    [view addSubview:editor];
    [view setEditingGraphic:self editorView:editor];
    [editor setSelectedRange:NSMakeRange(0, [contents length])];
    [editor setDelegate:self];

    // Make sure we redisplay
    [self didChange];

    [[view window] makeFirstResponder:editor];
    if (event) 
	{
        [editor mouseDown:event];
    }
}

- (void)endEditingInView:(SKTGraphicView *)view 
{
    if ([view editingGraphic] == self) 
	{
        NSTextView *editor = (NSTextView *)[view editorView];
        [editor setDelegate:nil];
        [editor removeFromSuperview];
        [[self contents] removeLayoutManager:[editor layoutManager]];
		
        [view setEditingGraphic:nil editorView:nil];
		
		[[view drawingController] commitWithIdentifier: @"typing"];
    }
}

- (void)textDidChange:(NSNotification *)notification 
{
    NSSize textSize;
    NSRect myBounds = [self bounds];
    BOOL fixedWidth = ([[notification object] isHorizontallyResizable] ? NO : YES);
    
    textSize = [self requiredSize:(fixedWidth ? NSWidth(myBounds) : 1.0e6)];
    
    if ((textSize.width > myBounds.size.width) || (textSize.height > myBounds.size.height)) 
	{
        [self setBounds:NSMakeRect(myBounds.origin.x, myBounds.origin.y, ((!fixedWidth && (textSize.width > myBounds.size.width)) ? textSize.width : myBounds.size.width), ((textSize.height > myBounds.size.height) ? textSize.height : myBounds.size.height))];
        // MF: For multiple editors we must fix up the others...  but we don't support multiple views of a document yet, and that's the only way we'd ever have the potential for multiple editors.
    }
}

@end

/*
 IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc. ("Apple") in
 consideration of your agreement to the following terms, and your use, installation,
 modification or redistribution of this Apple software constitutes acceptance of these
 terms.  If you do not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.

 In consideration of your agreement to abide by the following terms, and subject to these
 terms, Apple grants you a personal, non-exclusive license, under Apple's copyrights in
 this original Apple software (the "Apple Software"), to use, reproduce, modify and
 redistribute the Apple Software, with or without modifications, in source and/or binary
 forms; provided that if you redistribute the Apple Software in its entirety and without
 modifications, you must retain this notice and the following text and disclaimers in all
 such redistributions of the Apple Software.  Neither the name, trademarks, service marks
 or logos of Apple Computer, Inc. may be used to endorse or promote products derived from
 the Apple Software without specific prior written permission from Apple. Except as expressly
 stated in this notice, no other rights or licenses, express or implied, are granted by Apple
 herein, including but not limited to any patent rights that may be infringed by your
 derivative works or by other works in which the Apple Software may be incorporated.

 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO WARRANTIES,
 EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT,
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS
 USE AND OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
          OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE,
 REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND
 WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR
 OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
