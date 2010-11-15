// SKTTextArea.m
// Sketch Example
//

#import "SKTTextArea.h"
#import "SKTGraphicView.h"
#import "SKTDrawDocument.h"

@implementation SKTTextArea

- (id)init 
{
	self = [super init];
	if (self) 
	{
		_contents = [[NSTextStorage allocWithZone:[self zone]] init];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(SKT_contentsChanged:) name:NSTextStorageDidProcessEditingNotification object:_contents];
	}
	return self;
}

- (void)dealloc 
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_contents release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone 
{
    id newObj = [super copyWithZone:zone];

    [newObj setContents:[self contents]];

    return newObj;
}

- (void)setContents:(id)contents 
{
    if (contents != _contents) 
	{
        NSAttributedString *contentsCopy = [[NSAttributedString allocWithZone:[self zone]] initWithAttributedString:_contents];
        [[[self undoManager] prepareWithInvocationTarget:self] setContents:contentsCopy];
        [contentsCopy release];
        // We are willing to accept either a string or an attributed string.
        if ([contents isKindOfClass:[NSAttributedString class]]) 
		{
            [_contents replaceCharactersInRange:NSMakeRange(0, [_contents length]) withAttributedString:contents];
        } 
		else 
		{
            [_contents replaceCharactersInRange:NSMakeRange(0, [_contents length]) withString:contents];
        }
        [self didChange];
    }
}

- (id)coerceValueForContents:(id)value 
{
    // We want to just get Strings unchanged.  We will detect this and do the right thing in setContents().  We do this because, this way, we will do more reasonable things about attributes when we are receiving plain text.
    if ([value isKindOfClass:[NSString class]]) 
	{
        return value;
    }
	else 
	{
	    return nil; //NRO -- we don't have NSScript stuff..
        //return [[NSScriptCoercionHandler sharedCoercionHandler] coerceValue:value toClass:[NSTextStorage class]];
    }
}


- (NSTextStorage *)contents 
{
    return _contents;
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

/* NOTE: We do not share NSLayoutManager anymore because GNUstep crashes
 * when trying to do layout with reused layout manager.
 */
/*static*/ NSLayoutManager *sharedDrawingLayoutManager() 
{
    // This method returns an NSLayoutManager that can be used to draw the contents of a SKTTextArea.
    /*static*/ NSLayoutManager *sharedLM = nil;
    if (!sharedLM) 
	{
        //NSTextContainer *tc = [[NSTextContainer allocWithZone:NULL] initWithContainerSize:NSMakeSize(1.0e6, 1.0e6)];
        NSTextContainer *tc = [[NSTextContainer new] initWithContainerSize:NSMakeSize(1.0e6, 1.0e6)];
        
        //sharedLM = [[NSLayoutManager allocWithZone:NULL] init];
        sharedLM = [[NSLayoutManager new] init];

        [tc setWidthTracksTextView:NO];
        [tc setHeightTracksTextView:NO];
        [sharedLM addTextContainer:tc];
        [tc release];
    }
    return sharedLM;
}

- (void)drawInView:(SKTGraphicView *)view isSelected:(BOOL)flag 
{
    NSRect bounds = [self bounds];
    if ([self drawsFill]) 
	{
        [[self fillColor] set];
        NSRectFill(bounds);
    }
    if (view && ([view editingGraphic] == self) || ([view creatingGraphic] == self)) 
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
            NSLayoutManager *lm = sharedDrawingLayoutManager();
            NSTextContainer *tc = [[lm textContainers] objectAtIndex:0];
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
    NSRect bounds = [self bounds];
    NSSize size = [[self document] documentSize];
    size.width = (size.width - bounds.origin.x - SKTRightMargin);
    size.height = (size.height - bounds.origin.y - SKTRightMargin);
    return size;
}

- (NSSize)requiredSize:(float)maxWidth 
{
    NSTextStorage *contents = [self contents];
    NSSize minSize = [self minSize];
    NSSize maxSize = [self maxSize];
    unsigned len = [contents length];
    
    if (len > 0) 
	{
        NSLayoutManager *lm = sharedDrawingLayoutManager();
        NSTextContainer *tc = [[lm textContainers] objectAtIndex:0];
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

static NSTextView *newEditor() 
{
    // This method returns an NSTextView whose NSLayoutManager has a refcount of 1.  It is the caller's responsibility to release the NSLayoutManager.  This function is only for the use of the following method.
    NSLayoutManager *lm = [[NSLayoutManager allocWithZone:NULL] init];
    NSTextContainer *tc = [[NSTextContainer allocWithZone:NULL] initWithContainerSize:NSMakeSize(1.0e6, 1.0e6)];
    NSTextView *tv = [[NSTextView allocWithZone:NULL] initWithFrame:NSMakeRect(0.0, 0.0, 100.0, 100.0) textContainer:nil];

    [lm addTextContainer:tc];
    [tc release];

    [tv setTextContainerInset:NSMakeSize(0.0, 0.0)];
    [tv setDrawsBackground:NO];
    [tv setAllowsUndo:YES];
    [tc setTextView:tv];
    [tv release];

    return tv;
}

static NSTextView *sharedEditor = nil;
static BOOL sharedEditorInUse = NO;

- (void)startEditingWithEvent:(NSEvent *)event inView:(SKTGraphicView *)view 
{ 
    NSTextView *editor;
    NSTextStorage *contents = [self contents];
    NSSize maxSize = [self maxSize];
    NSSize minSize = [self minSize];
    NSRect bounds = [self bounds];
    
    if (!sharedEditorInUse) 
	{
        if (!sharedEditor) 
		{
            sharedEditor = newEditor();
        }
        sharedEditorInUse = YES;
        editor = sharedEditor;
    }
	else 
	{
        editor = newEditor();
    }
    [[editor textContainer] setWidthTracksTextView:NO];
    if (NSWidth(bounds) > minSize.width + 1.0) 
	{
        // If we are bigger than the minimum width we assume that someone already edited this SKTTextArea or that they created it by dragging out a rect.  In either case, we figure the width should remain fixed.
        [[editor textContainer] setContainerSize:NSMakeSize(NSWidth(bounds), maxSize.height)];
        [editor setHorizontallyResizable:NO];
    }
	else 
	{
        [[editor textContainer] setContainerSize:maxSize];
        [editor setHorizontallyResizable:YES];
    }
    [editor setMinSize:minSize];
    [editor setMaxSize:maxSize];
    [[editor textContainer] setHeightTracksTextView:NO];
    [editor setVerticallyResizable:YES];
    [editor setFrame:bounds];

    [contents addLayoutManager:[editor layoutManager]];
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
        if (editor == sharedEditor) 
		{
            sharedEditorInUse = NO;
        }
		else 
		{
            [[editor layoutManager] release];
        }
        [view setEditingGraphic:nil editorView:nil];
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

NSString *SKTTextAreaContentsKey = @"Text";

- (NSMutableDictionary *)propertyListRepresentation 
{
    NSMutableDictionary *dict = [super propertyListRepresentation];
    [dict setObject:[NSArchiver archivedDataWithRootObject:[self contents]] forKey:SKTTextAreaContentsKey];
    return dict;
}

- (void)loadPropertyListRepresentation:(NSDictionary *)dict 
{
    id obj;

    [super loadPropertyListRepresentation:dict];

    obj = [dict objectForKey:SKTTextAreaContentsKey];
    if (obj) 
	{
        [self setContents:[NSUnarchiver unarchiveObjectWithData:obj]];
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
