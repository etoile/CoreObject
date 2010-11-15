// SKTGraphic.m
// Sketch Example
//

#import "SKTGraphic.h"
#import "SKTGraphicView.h"
#import "SKTDrawDocument.h"
#import "SKTFoundationExtras.h"
#import <math.h>

NSString *SKTGraphicDidChangeNotification = @"SKTGraphicDidChange";

@implementation SKTGraphic

// =================================== Initialization ===================================
- (id)init {
    self = [super init];
    if (self) {
        _document = nil;
        [self setBounds:NSMakeRect(0.0, 0.0, 1.0, 1.0)];
        //[self setFillColor:[NSColor whiteColor]];
        [self setFillColor:[NSColor colorWithCalibratedRed: 1.0 green: 1.0 blue: 1.0 alpha: 0.5]];
        [self setDrawsFill:NO];
        [self setStrokeColor:[NSColor blackColor]];
        [self setDrawsStroke:YES];
        [self setStrokeLineWidth:1.0];
        _origBounds = NSZeroRect;
        _gFlags.manipulatingBounds = NO;
    }
    return self;
}

- (void)dealloc {
    [_fillColor release];
    [_strokeColor release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone {
    id newObj = [[[self class] allocWithZone:zone] init];

    // Document is not "copied".  The new graphic will need to be inserted into a document.
    [newObj setBounds:[self bounds]];
    [newObj setFillColor:[self fillColor]];
    [newObj setDrawsFill:[self drawsFill]];
    [newObj setStrokeColor:[self strokeColor]];
    [newObj setDrawsStroke:[self drawsStroke]];
    [newObj setStrokeLineWidth:[self strokeLineWidth]];

    return newObj;
}

// ========================= Document accessors and conveniences =========================
- (void)setDocument:(SKTDrawDocument *)document {
    _document = document;
}

- (SKTDrawDocument *)document {
    return _document;
}

- (NSUndoManager *)undoManager {
    return [[self document] undoManager];
}

- (NSString *)graphicType {
    return NSStringFromClass([self class]);
}

// =================================== Primitives ===================================
- (void)didChange {
    [_document invalidateGraphic:self];
    [[NSNotificationCenter defaultCenter] postNotificationName:SKTGraphicDidChangeNotification object:self];
}
    
- (void)setBounds:(NSRect)bounds {
    if (!NSEqualRects(bounds, _bounds)) {
        if (!_gFlags.manipulatingBounds) {
            // Send the notification before and after so that observers who invalidate display in views will wind up invalidating both the original rect and the new one.
            [self didChange];
            [[[self undoManager] prepareWithInvocationTarget:self] setBounds:_bounds];
        }
        _bounds = bounds;
        if (!_gFlags.manipulatingBounds) {
            [self didChange];
        }
    }
}

- (NSRect)bounds {
    return _bounds;
}

- (void)setDrawsFill:(BOOL)flag {
    if (_gFlags.drawsFill != flag) {
        [[[self undoManager] prepareWithInvocationTarget:self] setDrawsFill:_gFlags.drawsFill];
        _gFlags.drawsFill = (flag ? YES : NO);
        [self didChange];
    }
}

- (BOOL)drawsFill {
    return _gFlags.drawsFill;
}

- (void)setFillColor:(NSColor *)fillColor {
    if (_fillColor != fillColor) {
        [[[self undoManager] prepareWithInvocationTarget:self] setFillColor:_fillColor];
        [_fillColor autorelease];
        _fillColor = [fillColor retain];
        [self didChange];
    }
    if (_fillColor) {
        [self setDrawsFill:YES];
    } else {
        [self setDrawsFill:NO];
    }
}

- (NSColor *)fillColor {
    return _fillColor;
}

- (void)setDrawsStroke:(BOOL)flag {
    if (_gFlags.drawsStroke != flag) {
        [[[self undoManager] prepareWithInvocationTarget:self] setDrawsStroke:_gFlags.drawsStroke];
        _gFlags.drawsStroke = (flag ? YES : NO);
        [self didChange];
    }
}

- (BOOL)drawsStroke {
    return _gFlags.drawsStroke;
}

- (void)setStrokeColor:(NSColor *)strokeColor {
    if (_strokeColor != strokeColor) {
        [[[self undoManager] prepareWithInvocationTarget:self] setStrokeColor:_strokeColor];
        [_strokeColor autorelease];
        _strokeColor = [strokeColor retain];
        [self didChange];
    }
    if (_strokeColor) {
        [self setDrawsStroke:YES];
    } else {
        [self setDrawsStroke:NO];
    }
}

- (NSColor *)strokeColor {
    return _strokeColor;
}

- (void)setStrokeLineWidth:(float)width {
    if (_lineWidth != width) {
        [[[self undoManager] prepareWithInvocationTarget:self] setStrokeLineWidth:_lineWidth];
        if (width >= 0.0) {
            [self setDrawsStroke:YES];
            _lineWidth = width;
        } else {
            [self setDrawsStroke:NO];
            _lineWidth = 0.0;
        }
        [self didChange];
    }
}

- (float)strokeLineWidth {
    return _lineWidth;
}

// =================================== Extended mutation ===================================
- (void)startBoundsManipulation {
    // Save the original bounds.
    _gFlags.manipulatingBounds = YES;
    _origBounds = _bounds;
}

- (void)stopBoundsManipulation {
    if (_gFlags.manipulatingBounds) {
        // Restore the original bounds, the set the new bounds.
        if (!NSEqualRects(_origBounds, _bounds)) {
            NSRect temp;

            _gFlags.manipulatingBounds = NO;
            temp = _bounds;
            _bounds = _origBounds;
            [self setBounds:temp];
        } else {
            _gFlags.manipulatingBounds = NO;
        }
    }
}

- (void)moveBy:(NSPoint)vector {
    [self setBounds:NSOffsetRect([self bounds], vector.x, vector.y)];
}

- (void)flipHorizontally {
    // Some subclasses need to know.
    return;
}

- (void)flipVertically {
    // Some subclasses need to know.
    return;
}

+ (int)flipKnob:(int)knob horizontal:(BOOL)horizFlag {
    static BOOL initedFlips = NO;
    static int horizFlips[9];
    static int vertFlips[9];

    if (!initedFlips) {
        horizFlips[UpperLeftKnob] = UpperRightKnob;
        horizFlips[UpperMiddleKnob] = UpperMiddleKnob;
        horizFlips[UpperRightKnob] = UpperLeftKnob;
        horizFlips[MiddleLeftKnob] = MiddleRightKnob;
        horizFlips[MiddleRightKnob] = MiddleLeftKnob;
        horizFlips[LowerLeftKnob] = LowerRightKnob;
        horizFlips[LowerMiddleKnob] = LowerMiddleKnob;
        horizFlips[LowerRightKnob] = LowerLeftKnob;
        
        vertFlips[UpperLeftKnob] = LowerLeftKnob;
        vertFlips[UpperMiddleKnob] = LowerMiddleKnob;
        vertFlips[UpperRightKnob] = LowerRightKnob;
        vertFlips[MiddleLeftKnob] = MiddleLeftKnob;
        vertFlips[MiddleRightKnob] = MiddleRightKnob;
        vertFlips[LowerLeftKnob] = UpperLeftKnob;
        vertFlips[LowerMiddleKnob] = UpperMiddleKnob;
        vertFlips[LowerRightKnob] = UpperRightKnob;
        initedFlips = YES;
    }
    if (horizFlag) {
        return horizFlips[knob];
    } else {
        return vertFlips[knob];
    }
}

- (int)resizeByMovingKnob:(int)knob toPoint:(NSPoint)point {
    NSRect bounds = [self bounds];

    if ((knob == UpperLeftKnob) || (knob == MiddleLeftKnob) || (knob == LowerLeftKnob)) {
        // Adjust left edge
        bounds.size.width = NSMaxX(bounds) - point.x;
        bounds.origin.x = point.x;
    } else if ((knob == UpperRightKnob) || (knob == MiddleRightKnob) || (knob == LowerRightKnob)) {
        // Adjust left edge
        bounds.size.width = point.x - bounds.origin.x;
    }
    if (bounds.size.width < 0.0) {
        knob = [SKTGraphic flipKnob:knob horizontal:YES];
        bounds.size.width = -bounds.size.width;
        bounds.origin.x -= bounds.size.width;
        [self flipHorizontally];
    }

    if ((knob == UpperLeftKnob) || (knob == UpperMiddleKnob) || (knob == UpperRightKnob)) {
        // Adjust top edge
        bounds.size.height = NSMaxY(bounds) - point.y;
        bounds.origin.y = point.y;
    } else if ((knob == LowerLeftKnob) || (knob == LowerMiddleKnob) || (knob == LowerRightKnob)) {
        // Adjust bottom edge
        bounds.size.height = point.y - bounds.origin.y;
    }
    if (bounds.size.height < 0.0) {
        knob = [SKTGraphic flipKnob:knob horizontal:NO];
        bounds.size.height = -bounds.size.height;
        bounds.origin.y -= bounds.size.height;
        [self flipVertically];
    }
    [self setBounds:bounds];
    return knob;
}

- (void)makeNaturalSize {
    // Do nothing by default
}

// =================================== Subclass capabilities ===================================

// Some subclasses will not ever have a stroke or fill or a natural size.  Overriding these methods in such subclasses allows the Inspector and Menu items to better reflect allowable actions.

- (BOOL)canDrawStroke {
    return YES;
}

- (BOOL)canDrawFill {
    return YES;
}

- (BOOL)hasNaturalSize {
    return YES;
}

// =================================== Persistence ===================================
NSString *SKTClassKey = @"Class";
NSString *SKTBoundsKey = @"Bounds";
NSString *SKTDrawsFillKey = @"DrawsFill";
NSString *SKTFillColorKey = @"FillColor";
NSString *SKTDrawsStrokeKey = @"DrawsStroke";
NSString *SKTStrokeColorKey = @"StrokeColor";
NSString *SKTStrokeLineWidthKey = @"StrokeLineWidth";

- (NSMutableDictionary *)propertyListRepresentation {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    NSString *className = NSStringFromClass([self class]);
    NSRange sktRange = [className rangeOfString:@"SKT" options:NSAnchoredSearch];
    
    // Strip SKT prefix to preserve document capatibility with old versions of Sketch.
    if (sktRange.location != NSNotFound) {
        className = [className substringFromIndex:NSMaxRange(sktRange)];
    }
    [dict setObject:className forKey:SKTClassKey];
    [dict setObject:NSStringFromRect([self bounds]) forKey:SKTBoundsKey];
    [dict setObject:([self drawsFill] ? @"YES" : @"NO") forKey:SKTDrawsFillKey];
    if ([self fillColor]) {
        [dict setObject:[NSArchiver archivedDataWithRootObject:[self fillColor]] forKey:SKTFillColorKey];
    }
    [dict setObject:([self drawsStroke] ? @"YES" : @"NO") forKey:SKTDrawsStrokeKey];
    if ([self strokeColor]) {
        [dict setObject:[NSArchiver archivedDataWithRootObject:[self strokeColor]] forKey:SKTStrokeColorKey];
    }
    [dict setObject:[NSString stringWithFormat:@"%.2f", [self strokeLineWidth]] forKey:SKTStrokeLineWidthKey];

    return dict;
}

+ (id)graphicWithPropertyListRepresentation:(NSDictionary *)dict {
    Class theClass = NSClassFromString([dict objectForKey:SKTClassKey]);
    id theGraphic = nil;
    
    // Prepend SKT to the class name if we did not find it literally.  When we write the classname key we strip the prefix.  We try it first without the prefix because for a short time Sketch did not strip the prefix so there could be documents that do not need it prepended.
    if (!theClass) {
        theClass = NSClassFromString([@"SKT" stringByAppendingString:[dict objectForKey:SKTClassKey]]);
    }
    if (theClass) {
        theGraphic = [[[theClass allocWithZone:NULL] init] autorelease];
        if (theGraphic) {
            [theGraphic loadPropertyListRepresentation:dict];
        }
    }
    return theGraphic;
}

- (void)loadPropertyListRepresentation:(NSDictionary *)dict {
    id obj;

    obj = [dict objectForKey:SKTBoundsKey];
    if (obj) {
        [self setBounds:NSRectFromString(obj)];
    }
    obj = [dict objectForKey:SKTFillColorKey];
    if (obj) {
        [self setFillColor:[NSUnarchiver unarchiveObjectWithData:obj]];
    }
    obj = [dict objectForKey:SKTDrawsFillKey];
    if (obj) {
        [self setDrawsFill:[obj isEqualToString:@"YES"]];
    }
    obj = [dict objectForKey:SKTStrokeColorKey];
    if (obj) {
        [self setStrokeColor:[NSUnarchiver unarchiveObjectWithData:obj]];
    }
    obj = [dict objectForKey:SKTStrokeLineWidthKey];
    if (obj) {
        [self setStrokeLineWidth:[obj floatValue]];
    }
    obj = [dict objectForKey:SKTDrawsStrokeKey];
    if (obj) {
        [self setDrawsStroke:[obj isEqualToString:@"YES"]];
    }
    return;
}

// =================================== Drawing ===================================
- (NSRect)drawingBounds {
    float inset = -SKT_HALF_HANDLE_WIDTH;
    if ([self drawsStroke]) {
        float halfLineWidth = ([self strokeLineWidth] / 2.0) + 1.0;
        if (-halfLineWidth < inset) {
            inset = -halfLineWidth;
        }
    }
    inset += -1.0;
    return NSInsetRect([self bounds], inset, inset);
}

- (NSBezierPath *)bezierPath {
    // Subclasses that just have a simple path override this to return it.  The basic drawInView:isSelected: implementation below will stroke and fill this path.  Subclasses that need more complex drawing will just override drawInView:isSelected:.
    return nil;
}

- (void)drawInView:(SKTGraphicView *)view isSelected:(BOOL)flag {
    NSBezierPath *path = [self bezierPath];
    if (path) {
        if ([self drawsFill]) {
            [[self fillColor] set];
            [path fill];
        }
        if ([self drawsStroke]) {
            [[self strokeColor] set];
            [path stroke];
        }
    }
    if (flag) {
        [self drawHandlesInView:view];
    }
}

- (unsigned)knobMask {
    return AllKnobsMask;
}

- (int)knobUnderPoint:(NSPoint)point {
    NSRect bounds = [self bounds];
    unsigned knobMask = [self knobMask];
    NSRect handleRect;

    handleRect.size.width = SKT_HANDLE_WIDTH;
    handleRect.size.height = SKT_HANDLE_WIDTH;

    if (knobMask & UpperLeftKnobMask) {
        handleRect.origin.x = NSMinX(bounds) - SKT_HALF_HANDLE_WIDTH;
        handleRect.origin.y = NSMinY(bounds) - SKT_HALF_HANDLE_WIDTH;
        if (NSPointInRect(point, handleRect)) {
            return UpperLeftKnob;
        }
    }
    if (knobMask & UpperMiddleKnobMask) {
        handleRect.origin.x = NSMidX(bounds) - SKT_HALF_HANDLE_WIDTH;
        handleRect.origin.y = NSMinY(bounds) - SKT_HALF_HANDLE_WIDTH;
        if (NSPointInRect(point, handleRect)) {
            return UpperMiddleKnob;
        }
    }
    if (knobMask & UpperRightKnobMask) {
        handleRect.origin.x = NSMaxX(bounds) - SKT_HALF_HANDLE_WIDTH;
        handleRect.origin.y = NSMinY(bounds) - SKT_HALF_HANDLE_WIDTH;
        if (NSPointInRect(point, handleRect)) {
            return UpperRightKnob;
        }
    }
    if (knobMask & MiddleLeftKnobMask) {
        handleRect.origin.x = NSMinX(bounds) - SKT_HALF_HANDLE_WIDTH;
        handleRect.origin.y = NSMidY(bounds) - SKT_HALF_HANDLE_WIDTH;
        if (NSPointInRect(point, handleRect)) {
            return MiddleLeftKnob;
        }
    }
    if (knobMask & MiddleRightKnobMask) {
        handleRect.origin.x = NSMaxX(bounds) - SKT_HALF_HANDLE_WIDTH;
        handleRect.origin.y = NSMidY(bounds) - SKT_HALF_HANDLE_WIDTH;
        if (NSPointInRect(point, handleRect)) {
            return MiddleRightKnob;
        }
    }
    if (knobMask & LowerLeftKnobMask) {
        handleRect.origin.x = NSMinX(bounds) - SKT_HALF_HANDLE_WIDTH;
        handleRect.origin.y = NSMaxY(bounds) - SKT_HALF_HANDLE_WIDTH;
        if (NSPointInRect(point, handleRect)) {
            return LowerLeftKnob;
        }
    }
    if (knobMask & LowerMiddleKnobMask) {
        handleRect.origin.x = NSMidX(bounds) - SKT_HALF_HANDLE_WIDTH;
        handleRect.origin.y = NSMaxY(bounds) - SKT_HALF_HANDLE_WIDTH;
        if (NSPointInRect(point, handleRect)) {
            return LowerMiddleKnob;
        }
    }
    if (knobMask & LowerRightKnobMask) {
        handleRect.origin.x = NSMaxX(bounds) - SKT_HALF_HANDLE_WIDTH;
        handleRect.origin.y = NSMaxY(bounds) - SKT_HALF_HANDLE_WIDTH;
        if (NSPointInRect(point, handleRect)) {
            return LowerRightKnob;
        }
    }

    return NoKnob;
}

- (void)drawHandleAtPoint:(NSPoint)point inView:(SKTGraphicView *)view {
    NSRect handleRect;

    handleRect.origin.x = point.x - SKT_HALF_HANDLE_WIDTH + 1.0;
    handleRect.origin.y = point.y - SKT_HALF_HANDLE_WIDTH + 1.0;
    handleRect.size.width = SKT_HANDLE_WIDTH - 1.0;
    handleRect.size.height = SKT_HANDLE_WIDTH - 1.0;
    handleRect = [view centerScanRect:handleRect];
    [[NSColor controlDarkShadowColor] set];
    NSRectFill(handleRect);
    handleRect = NSOffsetRect(handleRect, -1.0, -1.0);
    [[NSColor knobColor] set];
    NSRectFill(handleRect);
}

- (void)drawHandlesInView:(SKTGraphicView *)view {
    NSRect bounds = [self bounds];
    unsigned knobMask = [self knobMask];

    if (knobMask & UpperLeftKnobMask) {
        [self drawHandleAtPoint:NSMakePoint(NSMinX(bounds), NSMinY(bounds)) inView:view];
    }
    if (knobMask & UpperMiddleKnobMask) {
        [self drawHandleAtPoint:NSMakePoint(NSMidX(bounds), NSMinY(bounds)) inView:view];
    }
    if (knobMask & UpperRightKnobMask) {
        [self drawHandleAtPoint:NSMakePoint(NSMaxX(bounds), NSMinY(bounds)) inView:view];
    }

    if (knobMask & MiddleLeftKnobMask) {
        [self drawHandleAtPoint:NSMakePoint(NSMinX(bounds), NSMidY(bounds)) inView:view];
    }
    if (knobMask & MiddleRightKnobMask) {
        [self drawHandleAtPoint:NSMakePoint(NSMaxX(bounds), NSMidY(bounds)) inView:view];
    }

    if (knobMask & LowerLeftKnobMask) {
        [self drawHandleAtPoint:NSMakePoint(NSMinX(bounds), NSMaxY(bounds)) inView:view];
    }
    if (knobMask & LowerMiddleKnobMask) {
        [self drawHandleAtPoint:NSMakePoint(NSMidX(bounds), NSMaxY(bounds)) inView:view];
    }
    if (knobMask & LowerRightKnobMask) {
        [self drawHandleAtPoint:NSMakePoint(NSMaxX(bounds), NSMaxY(bounds)) inView:view];
    }
}

// =================================== Event Handling ===================================
+ (NSCursor *)creationCursor {
    // By default we use the crosshair cursor
    static NSCursor *crosshairCursor = nil;
    if (!crosshairCursor) {
        NSImage *crosshairImage = [NSImage imageNamed:@"Cross"];
        NSSize imageSize = [crosshairImage size];
        crosshairCursor = [[NSCursor allocWithZone:[self zone]] initWithImage:crosshairImage hotSpot:NSMakePoint((imageSize.width / 2.0), (imageSize.height / 2.0))];
    }
    return crosshairCursor;
}

- (BOOL)createWithEvent:(NSEvent *)theEvent inView:(SKTGraphicView *)view {
    // default implementation tracks until mouseUp: just setting the bounds of the new graphic.
    NSPoint point = [view convertPoint:[theEvent locationInWindow] fromView:nil];
    int knob = LowerRightKnob;
    NSRect bounds;
    BOOL snapsToGrid = [view snapsToGrid];
    float spacing = [view gridSpacing];
    BOOL echoToRulers = [[view enclosingScrollView] rulersVisible];

    [self startBoundsManipulation];
    if (snapsToGrid) {
        point.x = floor((point.x / spacing) + 0.5) * spacing;
        point.y = floor((point.y / spacing) + 0.5) * spacing;
    }
    [self setBounds:NSMakeRect(point.x, point.y, 0.0, 0.0)];
    if (echoToRulers) {
        [view beginEchoingMoveToRulers:[self bounds]];
    }
    while (1) {
        theEvent = [[view window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
        point = [view convertPoint:[theEvent locationInWindow] fromView:nil];
        if (snapsToGrid) {
            point.x = floor((point.x / spacing) + 0.5) * spacing;
            point.y = floor((point.y / spacing) + 0.5) * spacing;
        }
        [view setNeedsDisplayInRect:[self drawingBounds]];
        knob = [self resizeByMovingKnob:knob toPoint:point];
        [view setNeedsDisplayInRect:[self drawingBounds]];
        if (echoToRulers) {
            [view continueEchoingMoveToRulers:[self bounds]];
        }
        if ([theEvent type] == NSLeftMouseUp) {
            break;
        }
    }
    if (echoToRulers) {
        [view stopEchoingMoveToRulers];
    }

    [self stopBoundsManipulation];
    
    bounds = [self bounds];
    if ((bounds.size.width > 0.0) || (bounds.size.height > 0.0)) {
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)isEditable {
    return NO;
}

- (void)startEditingWithEvent:(NSEvent *)event inView:(SKTGraphicView *)view {
    return;
}

- (void)endEditingInView:(SKTGraphicView *)view {
    return;
}

- (BOOL)hitTest:(NSPoint)point isSelected:(BOOL)isSelected {
    if (isSelected && ([self knobUnderPoint:point] != NoKnob)) {
        return YES;
    } else {
        NSBezierPath *path = [self bezierPath];

        if (path) {
            if ([path containsPoint:point]) {
                return YES;
            }
        } else {
            if (NSPointInRect(point, [self bounds])) {
                return YES;
            }
        }
        return NO;
    }
}

- (NSString *)description {
    return [[self propertyListRepresentation] description];
}

@end

@implementation SKTGraphic (SKTScriptingExtras)

// These are methods that we probably wouldn't bother with if we weren't scriptable.

	/*
- (NSScriptObjectSpecifier *)objectSpecifier {
    NSArray *graphics = [[self document] graphics];
    unsigned index = [graphics indexOfObjectIdenticalTo:self];
    if (index != NSNotFound) {
        NSScriptObjectSpecifier *containerRef = [[self document] objectSpecifier];
        return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"graphics" index:index] autorelease];
    } else {
        return nil;
    }
}
*/
- (float)xPosition {
    return [self bounds].origin.x;
}

- (void)setXPosition:(float)newVal {
    NSRect bounds = [self bounds];
    bounds.origin.x = newVal;
    [self setBounds:bounds];
}

- (float)yPosition {
    return [self bounds].origin.y;
}

- (void)setYPosition:(float)newVal {
    NSRect bounds = [self bounds];
    bounds.origin.y = newVal;
    [self setBounds:bounds];
}

- (float)width {
    return [self bounds].size.width;
}

- (void)setWidth:(float)newVal {
    NSRect bounds = [self bounds];
    bounds.size.width = newVal;
    [self setBounds:bounds];
}

- (float)height {
    return [self bounds].size.height;
}

- (void)setHeight:(float)newVal {
    NSRect bounds = [self bounds];
    bounds.size.height = newVal;
    [self setBounds:bounds];
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
