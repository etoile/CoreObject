// SKTGraphicView.m
// Sketch Example
//

#import "SKTGraphicView.h"
#import "SKTDrawWindowController.h"
#import "SKTDrawDocument.h"
#import "SKTGraphic.h"
#import "SKTFoundationExtras.h"
#import "SKTToolPaletteController.h"
#import "SKTImage.h"
#import "SKTGridPanelController.h"
#import <math.h>

NSString *SKTGraphicViewSelectionDidChangeNotification = @"SKTGraphicViewSelectionDidChange";

@implementation SKTGraphicView

static float SKTDefaultPasteCascadeDelta = 10.0;

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        NSMutableArray *dragTypes = [NSMutableArray arrayWithObjects:NSColorPboardType, NSFilenamesPboardType, nil];
        [dragTypes addObjectsFromArray:[NSImage imagePasteboardTypes]];
        [self registerForDraggedTypes:dragTypes];
        _selectedGraphics = [[NSMutableArray allocWithZone:[self zone]] init];
        _creatingGraphic = nil;
        _rubberbandRect = NSZeroRect;
        _rubberbandGraphics = nil;
        _gvFlags.rubberbandIsDeselecting = NO;
        _gvFlags.initedRulers = NO;
        _editingGraphic = nil;
        _editorView = nil;
        _pasteboardChangeCount = -1;
        _pasteCascadeNumber = 0;
        _pasteCascadeDelta = NSMakePoint(SKTDefaultPasteCascadeDelta, SKTDefaultPasteCascadeDelta);
        _gvFlags.snapsToGrid = NO;
        _gvFlags.showsGrid = NO;
        _gvFlags.knobsHidden = NO;
        _gridSpacing = 8.0;
        _gridColor = [[NSColor lightGrayColor] retain];
        _unhideKnobsTimer = nil;
    }
    return self;
}

- (void)dealloc {
    [self endEditing];
    [_selectedGraphics release];
    [_rubberbandGraphics release];
    [_gridColor release];
    [super dealloc];
}

// SKTDrawWindowController accessors and convenience methods
- (void)setDrawWindowController:(SKTDrawWindowController *)theController {
    controller = theController;
}

- (SKTDrawWindowController *)drawWindowController {
    return controller;
}

- (SKTDrawDocument *)drawDocument {
    return [[self drawWindowController] document];
}

- (NSArray *)graphics {
    return [[[self drawWindowController] document] graphics];
}

// Display invalidation
- (void)invalidateGraphic:(SKTGraphic *)graphic {
    [self setNeedsDisplayInRect:[graphic drawingBounds]];
    if (![[self graphics] containsObject:graphic]) {
        [self deselectGraphic:graphic];  // deselectGraphic will call invalidateGraphic, too, but only if the graphic is in the selection and since the graphic is removed from the selection before this method is called again the potential infinite loop should not happen.
    }
}

- (void)invalidateGraphics:(NSArray *)graphics {
    unsigned i, c = [graphics count];
    for (i=0; i<c; i++) {
        [self invalidateGraphic:[graphics objectAtIndex:i]];
    }
}

// Selection primitives
- (NSArray *)selectedGraphics {
    return _selectedGraphics;
}

static int SKT_orderGraphicsFrontToBack(id graphic1, id graphic2, void *gArray) {
    NSArray *graphics = (NSArray *)gArray;
    unsigned index1, index2;

    index1 = [graphics indexOfObjectIdenticalTo:graphic1];
    index2 = [graphics indexOfObjectIdenticalTo:graphic2];
    if (index1 == index2) {
        return NSOrderedSame;
    } else if (index1 < index2) {
        return NSOrderedAscending;
    } else {
        return NSOrderedDescending;
    }
}

- (NSArray *)orderedSelectedGraphics  {
    return [[self selectedGraphics] sortedArrayUsingFunction:SKT_orderGraphicsFrontToBack context:[self graphics]];
}

- (BOOL)graphicIsSelected:(SKTGraphic *)graphic {
    return (([_selectedGraphics indexOfObjectIdenticalTo:graphic] == NSNotFound) ? NO : YES);
}

- (void)selectGraphic:(SKTGraphic *)graphic {
    unsigned curIndex = [_selectedGraphics indexOfObjectIdenticalTo:graphic];
    if (curIndex == NSNotFound) {
        [[[self undoManager] prepareWithInvocationTarget:self] deselectGraphic:graphic];
        [[[self drawDocument] undoManager] setActionName:NSLocalizedStringFromTable(@"Selection Change", @"UndoStrings", @"Action name for selection changes.")];
        [_selectedGraphics addObject:graphic];
        [self invalidateGraphic:graphic];
        _pasteCascadeDelta = NSMakePoint(SKTDefaultPasteCascadeDelta, SKTDefaultPasteCascadeDelta);
        [[NSNotificationCenter defaultCenter] postNotificationName:SKTGraphicViewSelectionDidChangeNotification object:self];
        [self updateRulers];
    }
}

- (void)deselectGraphic:(SKTGraphic *)graphic {
    unsigned curIndex = [_selectedGraphics indexOfObjectIdenticalTo:graphic];
    if (curIndex != NSNotFound) {
        [[[self undoManager] prepareWithInvocationTarget:self] selectGraphic:graphic];
        [[[self drawDocument] undoManager] setActionName:NSLocalizedStringFromTable(@"Selection Change", @"UndoStrings", @"Action name for selection changes.")];
        [_selectedGraphics removeObjectAtIndex:curIndex];
        [self invalidateGraphic:graphic];
        _pasteCascadeDelta = NSMakePoint(SKTDefaultPasteCascadeDelta, SKTDefaultPasteCascadeDelta);
        [[NSNotificationCenter defaultCenter] postNotificationName:SKTGraphicViewSelectionDidChangeNotification object:self];
        [self updateRulers];
    }
}

- (void)clearSelection {
    int i, c = [_selectedGraphics count];
    id curGraphic;
    
    if (c > 0) {
        for (i=0; i<c; i++) {
            curGraphic = [_selectedGraphics objectAtIndex:i];
            [[[self undoManager] prepareWithInvocationTarget:self] selectGraphic:curGraphic];
            [self invalidateGraphic:curGraphic];
        }
        [[[self drawDocument] undoManager] setActionName:NSLocalizedStringFromTable(@"Selection Change", @"UndoStrings", @"Action name for selection changes.")];
        [_selectedGraphics removeAllObjects];
        _pasteCascadeDelta = NSMakePoint(SKTDefaultPasteCascadeDelta, SKTDefaultPasteCascadeDelta);
        [[NSNotificationCenter defaultCenter] postNotificationName:SKTGraphicViewSelectionDidChangeNotification object:self];
        [self updateRulers];
    }
}

// Editing
- (void)setEditingGraphic:(SKTGraphic *)graphic editorView:(NSView *)editorView {
    // Called by a SKTGraphic that is told to start editing.  SKTGraphicView doesn't do anything with editorView, just remembers it.
    _editingGraphic = graphic;
    _editorView = editorView;
}

- (SKTGraphic *)editingGraphic {
    return _editingGraphic;
}

- (NSView *)editorView {
    return _editorView;
}

- (void)startEditingGraphic:(SKTGraphic *)graphic withEvent:(NSEvent *)event {
    [graphic startEditingWithEvent:event inView:self];
}

- (void)endEditing {
    if (_editingGraphic) {
        [_editingGraphic endEditingInView:self];
        _editingGraphic = nil;
        _editorView = nil;
    }
}

// Geometry calculations
- (SKTGraphic *)graphicUnderPoint:(NSPoint)point {
    SKTDrawDocument *document = [self drawDocument];
    NSArray *graphics = [document graphics];
    unsigned i, c = [graphics count];
    SKTGraphic *curGraphic = nil;

    for (i=0; i<c; i++) {
        curGraphic = [graphics objectAtIndex:i];
        if ([self mouse:point inRect:[curGraphic drawingBounds]] && [curGraphic hitTest:point isSelected:[self graphicIsSelected:curGraphic]]) {
            break;
        }
    }
    if (i < c) {
        return curGraphic;
    } else {
        return nil;
    }
}

- (NSSet *)graphicsIntersectingRect:(NSRect)rect {
    NSArray *graphics = [self graphics];
    unsigned i, c = [graphics count];
    NSMutableSet *result = [NSMutableSet set];
    SKTGraphic *curGraphic;

    for (i=0; i<c; i++) {
        curGraphic = [graphics objectAtIndex:i];
        if (NSIntersectsRect(rect, [curGraphic drawingBounds])) {
            [result addObject:curGraphic];
        }
    }
    return result;
}

// Drawing and mouse tracking
- (BOOL)isFlipped {
    return YES;
}

- (BOOL)isOpaque {
    return YES;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)becomeFirstResponder {
    [self updateRulers];
    return YES;
}

- (void)drawRect:(NSRect)rect {
    SKTDrawWindowController *drawWindowController = [self drawWindowController];
    NSArray *graphics;
    unsigned i;
    SKTGraphic *curGraphic;
    BOOL isSelected;
    NSRect drawingBounds;
    NSGraphicsContext *currentContext = [NSGraphicsContext currentContext];

    [[NSColor whiteColor] set];
    NSRectFill(rect);
    if ([self showsGrid]) {
        SKTDrawGridWithSettingsInRect([self gridSpacing], [self gridColor], rect, NSZeroPoint);
    }

    graphics = [[drawWindowController document] graphics];
    i = [graphics count];
    while (i-- > 0) {
        curGraphic = [graphics objectAtIndex:i];
        drawingBounds = [curGraphic drawingBounds];
        if (NSIntersectsRect(rect, drawingBounds)) {
            if (!_gvFlags.knobsHidden && (curGraphic != _editingGraphic)) {
                // Figure out if we should draw selected.
                isSelected = [self graphicIsSelected:curGraphic];
                // Account for any current rubberband selection state
                if (_rubberbandGraphics && (isSelected == _gvFlags.rubberbandIsDeselecting) && [_rubberbandGraphics containsObject:curGraphic]) {
                    isSelected = (isSelected ? NO : YES);
                }
            } else {
                // Do not draw handles on graphics that are editing.
                isSelected = NO;
            }
            [currentContext saveGraphicsState];
            [NSBezierPath clipRect:drawingBounds];
            [curGraphic drawInView:self isSelected:isSelected];
            [currentContext restoreGraphicsState];
        }
    }

    if (_creatingGraphic) {
        drawingBounds = [_creatingGraphic drawingBounds];
        if (NSIntersectsRect(rect, drawingBounds)) {
            [currentContext saveGraphicsState];
            [NSBezierPath clipRect:drawingBounds];
            [_creatingGraphic drawInView:self isSelected:NO];
            [currentContext restoreGraphicsState];
        }
    }
    if (!NSEqualRects(_rubberbandRect, NSZeroRect)) {
        [[NSColor knobColor] set];
        NSFrameRect(_rubberbandRect);
    }
}

- (void)beginEchoingMoveToRulers:(NSRect)echoRect {
    NSRulerView *horizontalRuler = [[self enclosingScrollView] horizontalRulerView];
    NSRulerView *verticalRuler = [[self enclosingScrollView] verticalRulerView];

    _horizontalRulerLineRect = [self convertRect:echoRect toView:horizontalRuler];
    _verticalRulerLineRect = [self convertRect:echoRect toView:verticalRuler];

    [horizontalRuler moveRulerlineFromLocation:-1.0 toLocation:NSMinX(_horizontalRulerLineRect)];
    [horizontalRuler moveRulerlineFromLocation:-1.0 toLocation:NSMidX(_horizontalRulerLineRect)];
    [horizontalRuler moveRulerlineFromLocation:-1.0 toLocation:NSMaxX(_horizontalRulerLineRect)];

    [verticalRuler moveRulerlineFromLocation:-1.0 toLocation:NSMinY(_verticalRulerLineRect)];
    [verticalRuler moveRulerlineFromLocation:-1.0 toLocation:NSMidY(_verticalRulerLineRect)];
    [verticalRuler moveRulerlineFromLocation:-1.0 toLocation:NSMaxY(_verticalRulerLineRect)];
}

- (void)continueEchoingMoveToRulers:(NSRect)echoRect {
    NSRulerView *horizontalRuler = [[self enclosingScrollView] horizontalRulerView];
    NSRulerView *verticalRuler = [[self enclosingScrollView] verticalRulerView];
    NSRect newHorizontalRect = [self convertRect:echoRect toView:horizontalRuler];
    NSRect newVerticalRect = [self convertRect:echoRect toView:verticalRuler];

    [horizontalRuler moveRulerlineFromLocation:NSMinX(_horizontalRulerLineRect) toLocation:NSMinX(newHorizontalRect)];
    [horizontalRuler moveRulerlineFromLocation:NSMidX(_horizontalRulerLineRect) toLocation:NSMidX(newHorizontalRect)];
    [horizontalRuler moveRulerlineFromLocation:NSMaxX(_horizontalRulerLineRect) toLocation:NSMaxX(newHorizontalRect)];

    [verticalRuler moveRulerlineFromLocation:NSMinY(_verticalRulerLineRect) toLocation:NSMinY(newVerticalRect)];
    [verticalRuler moveRulerlineFromLocation:NSMidY(_verticalRulerLineRect) toLocation:NSMidY(newVerticalRect)];
    [verticalRuler moveRulerlineFromLocation:NSMaxY(_verticalRulerLineRect) toLocation:NSMaxY(newVerticalRect)];

    _horizontalRulerLineRect = newHorizontalRect;
    _verticalRulerLineRect = newVerticalRect;
}

- (void)stopEchoingMoveToRulers {
    NSRulerView *horizontalRuler = [[self enclosingScrollView] horizontalRulerView];
    NSRulerView *verticalRuler = [[self enclosingScrollView] verticalRulerView];

    [horizontalRuler moveRulerlineFromLocation:NSMinX(_horizontalRulerLineRect) toLocation:-1.0];
    [horizontalRuler moveRulerlineFromLocation:NSMidX(_horizontalRulerLineRect) toLocation:-1.0];
    [horizontalRuler moveRulerlineFromLocation:NSMaxX(_horizontalRulerLineRect) toLocation:-1.0];

    [verticalRuler moveRulerlineFromLocation:NSMinY(_verticalRulerLineRect) toLocation:-1.0];
    [verticalRuler moveRulerlineFromLocation:NSMidY(_verticalRulerLineRect) toLocation:-1.0];
    [verticalRuler moveRulerlineFromLocation:NSMaxY(_verticalRulerLineRect) toLocation:-1.0];

    _horizontalRulerLineRect = NSZeroRect;
    _verticalRulerLineRect = NSZeroRect;
}

- (void)createGraphicOfClass:(Class)theClass withEvent:(NSEvent *)theEvent {
    SKTDrawDocument *document = [self drawDocument];
    _creatingGraphic = [[theClass allocWithZone:[document zone]] init];
    if ([_creatingGraphic createWithEvent:theEvent inView:self]) {
        [document insertGraphic:_creatingGraphic atIndex:0];
        [self selectGraphic:_creatingGraphic];
        if ([_creatingGraphic isEditable]) {
            [self startEditingGraphic:_creatingGraphic withEvent:nil ];
        }
        [[document undoManager] setActionName:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Create %@", @"UndoStrings", @"Action name for newly created graphics.  Class name is inserted at the substitution."), [[NSBundle mainBundle] localizedStringForKey:NSStringFromClass(theClass) value:@"" table:@"GraphicClassNames"]]];
    }
    [_creatingGraphic release];
    _creatingGraphic = nil;
}

- (SKTGraphic *)creatingGraphic {
    return _creatingGraphic;
}

- (void)trackKnob:(int)knob ofGraphic:(SKTGraphic *)graphic withEvent:(NSEvent *)theEvent {
    NSPoint point;
    BOOL snapsToGrid = [self snapsToGrid];
    float spacing = [self gridSpacing];
    BOOL echoToRulers = [[self enclosingScrollView] rulersVisible];

    [graphic startBoundsManipulation];
    if (echoToRulers) {
        [self beginEchoingMoveToRulers:[graphic bounds]];
    }
    while (1) {
        theEvent = [[self window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
        point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
        [self invalidateGraphic:graphic];
        if (snapsToGrid) {
            point.x = floor((point.x / spacing) + 0.5) * spacing;
            point.y = floor((point.y / spacing) + 0.5) * spacing;
        }
        knob = [graphic resizeByMovingKnob:knob toPoint:point];
        [self invalidateGraphic:graphic];
        if (echoToRulers) {
            [self continueEchoingMoveToRulers:[graphic bounds]];
        }
        if ([theEvent type] == NSLeftMouseUp) {
            break;
        }
    }
    if (echoToRulers) {
        [self stopEchoingMoveToRulers];
    }

    [graphic stopBoundsManipulation];

    [[[self drawDocument] undoManager] setActionName:NSLocalizedStringFromTable(@"Resize", @"UndoStrings", @"Action name for resizes.")];
}

- (void)rubberbandSelectWithEvent:(NSEvent *)theEvent {
    NSPoint origPoint, curPoint;
    NSEnumerator *objEnum;
    SKTGraphic *curGraphic;

    _gvFlags.rubberbandIsDeselecting = (([theEvent modifierFlags] & NSAlternateKeyMask) ? YES : NO);
    origPoint = curPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];

    while (1) {
        theEvent = [[self window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
        curPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
        if (NSEqualPoints(origPoint, curPoint)) {
            if (!NSEqualRects(_rubberbandRect, NSZeroRect)) {
                [self setNeedsDisplayInRect:_rubberbandRect];
                [self performSelector:@selector(invalidateGraphic:) withEachObjectInSet:_rubberbandGraphics];
            }
            _rubberbandRect = NSZeroRect;
            [_rubberbandGraphics release];
            _rubberbandGraphics = nil;
        } else {
            NSRect newRubberbandRect = SKTRectFromPoints(origPoint, curPoint);
            if (!NSEqualRects(_rubberbandRect, newRubberbandRect)) {
                [self setNeedsDisplayInRect:_rubberbandRect];
                [self performSelector:@selector(invalidateGraphic:) withEachObjectInSet:_rubberbandGraphics];
                _rubberbandRect = newRubberbandRect;
                [_rubberbandGraphics release];
                _rubberbandGraphics = [[self graphicsIntersectingRect:_rubberbandRect] retain];
                [self setNeedsDisplayInRect:_rubberbandRect];
                [self performSelector:@selector(invalidateGraphic:) withEachObjectInSet:_rubberbandGraphics];
            }
        }
        if ([theEvent type] == NSLeftMouseUp) {
            break;
        }
    }

    // Now select or deselect the rubberbanded graphics.
    objEnum = [_rubberbandGraphics objectEnumerator];
    while ((curGraphic = [objEnum nextObject]) != nil) {
        if (_gvFlags.rubberbandIsDeselecting) {
            [self deselectGraphic:curGraphic];
        } else {
            [self selectGraphic:curGraphic];
        }
    }
    if (!NSEqualRects(_rubberbandRect, NSZeroRect)) {
        [self setNeedsDisplayInRect:_rubberbandRect];
    }
   
    _rubberbandRect = NSZeroRect;
    [_rubberbandGraphics release];
    _rubberbandGraphics = nil;
}

- (void)moveSelectedGraphicsWithEvent:(NSEvent *)theEvent {
    NSPoint lastPoint, curPoint;
    NSArray *selGraphics = [self selectedGraphics];
    unsigned i, c;
    SKTGraphic *graphic;
    BOOL didMove = NO, isMoving = NO;
    NSPoint selOriginOffset = NSZeroPoint;
    NSPoint boundsOrigin;
    BOOL snapsToGrid = [self snapsToGrid];
    float spacing = [self gridSpacing];
    BOOL echoToRulers = [[self enclosingScrollView] rulersVisible];
    NSRect selBounds = [[self drawDocument] boundsForGraphics:selGraphics];

    c = [selGraphics count];

    lastPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    if (snapsToGrid || echoToRulers) {
        selOriginOffset = NSMakePoint((lastPoint.x - selBounds.origin.x), (lastPoint.y - selBounds.origin.y));
    }
    if (echoToRulers) {
        [self beginEchoingMoveToRulers:selBounds];
    }

    while (1) {
        theEvent = [[self window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
        curPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
        if (!isMoving && ((fabs(curPoint.x - lastPoint.x) >= 2.0) || (fabs(curPoint.y - lastPoint.y) >= 2.0))) {
            isMoving = YES;
            [selGraphics makeObjectsPerformSelector:@selector(startBoundsManipulation)];
            _gvFlags.knobsHidden = YES;
        }
        if (isMoving) {
            if (snapsToGrid) {
                boundsOrigin.x = curPoint.x - selOriginOffset.x;
                boundsOrigin.y = curPoint.y - selOriginOffset.y;
                boundsOrigin.x = floor((boundsOrigin.x / spacing) + 0.5) * spacing;
                boundsOrigin.y = floor((boundsOrigin.y / spacing) + 0.5) * spacing;
                curPoint.x = boundsOrigin.x + selOriginOffset.x;
                curPoint.y = boundsOrigin.y + selOriginOffset.y;
            }
            if (!NSEqualPoints(lastPoint, curPoint)) {
                for (i=0; i<c; i++) {
                    graphic = [selGraphics objectAtIndex:i];
                    [self invalidateGraphic:graphic];
                    [graphic moveBy:NSMakePoint(curPoint.x - lastPoint.x, curPoint.y - lastPoint.y)];
                    [self invalidateGraphic:graphic];
                    if (echoToRulers) {
                        [self continueEchoingMoveToRulers:NSMakeRect(curPoint.x - selOriginOffset.x, curPoint.y - selOriginOffset.y, NSWidth(selBounds),NSHeight(selBounds))];
                    }
                    didMove = YES;
                }
                // Adjust the delta that is used for cascading pastes.  Pasting and then moving the pasted graphic is the way you determine the cascade delta for subsequent pastes.
                _pasteCascadeDelta.x += (curPoint.x - lastPoint.x);
                _pasteCascadeDelta.y += (curPoint.y - lastPoint.y);
            }
            lastPoint = curPoint;
        }
        if ([theEvent type] == NSLeftMouseUp) {
            break;
        }
    }

    if (echoToRulers)  {
        [self stopEchoingMoveToRulers];
    }
    if (isMoving) {
        [selGraphics makeObjectsPerformSelector:@selector(stopBoundsManipulation)];
        _gvFlags.knobsHidden = NO;

        if (didMove) {
            // Only if we really moved.
            [[[self drawDocument] undoManager] setActionName:NSLocalizedStringFromTable(@"Move", @"UndoStrings", @"Action name for moves.")];
        }
    }
}

- (void)selectAndTrackMouseWithEvent:(NSEvent *)theEvent {
    NSPoint curPoint;
    SKTGraphic *graphic = nil;
    BOOL isSelected;
    BOOL extending = (([theEvent modifierFlags] & NSShiftKeyMask) ? YES : NO);

    curPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    graphic = [self graphicUnderPoint:curPoint];
    isSelected = (graphic ? [self graphicIsSelected:graphic] : NO);

//    NSLog (@"graphic %@ isSelected %d", graphic, isSelected);

    if (!extending && !isSelected) {
        [self clearSelection];
    }

    if (graphic) {
        // Add or remove this graphic from selection.
        if (extending) {
            if (isSelected) {
                [self deselectGraphic:graphic];
                isSelected = NO;
            } else {
                [self selectGraphic:graphic];
                isSelected = YES;
            }
        } else {
            if (isSelected) {
                int knobHit = [graphic knobUnderPoint:curPoint];
                if (knobHit != NoKnob) {
                    [self trackKnob:knobHit ofGraphic:graphic withEvent:theEvent];
                    return;
                }
            }
            [self selectGraphic:graphic];
            isSelected = YES;
        }
    } else {
        [self rubberbandSelectWithEvent:theEvent];
        return;
    }

    if (isSelected) {
        [self moveSelectedGraphicsWithEvent:theEvent];
        return;
    }

    // If we got here then there must be nothing else to do.  Just track until mouseUp:.
    while (1) {
        theEvent = [[self window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
        if ([theEvent type] == NSLeftMouseUp) {
            break;
        }
    }
}

- (void)mouseDown:(NSEvent *)theEvent {
    Class theClass = [[SKTToolPaletteController sharedToolPaletteController] currentGraphicClass];
    if ([self editingGraphic]) {
        [self endEditing];
    }
    if ([theEvent clickCount] > 1) {
        NSPoint curPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
        SKTGraphic *graphic = [self graphicUnderPoint:curPoint];
        if (graphic && [graphic isEditable]) {
            [self startEditingGraphic:graphic withEvent:theEvent];
            return;
        }
    }
    if (theClass) {
        [self clearSelection];
        [self createGraphicOfClass:theClass withEvent:theEvent];
    } else {
        [self selectAndTrackMouseWithEvent:theEvent];
    }
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent {
    return YES;
}

// SKTImage graphic creation
- (BOOL)makeNewImageFromPasteboard:(NSPasteboard *)pboard atPoint:(NSPoint)point {
    NSString *type = [pboard availableTypeFromArray:[NSImage imagePasteboardTypes]];
    if (type) {
        NSImage *contents = [[NSImage allocWithZone:[[self drawDocument] zone]] initWithPasteboard:pboard];
        if (contents) {
            SKTImage *newImage = [[SKTImage allocWithZone:[[self drawDocument] zone]] init];
            [newImage setBounds:NSMakeRect(point.x, point.y - [contents size].height, [contents size].width, [contents size].height)];
            [newImage setImage:contents];
            [contents release];
            [[self drawDocument] insertGraphic:newImage atIndex:0];
            [newImage release];
            [self clearSelection];
            [self selectGraphic:newImage];
            return YES;
        }
    }
    return NO;
}

- (BOOL)makeNewImageFromContentsOfFile:(NSString *)filename atPoint:(NSPoint)point {
    NSString *extension = [filename pathExtension];
    if ([[NSImage imageFileTypes] containsObject:extension]) {
        NSImage *contents = [[NSImage allocWithZone:[[self drawDocument] zone]] initWithContentsOfFile:filename];
        if (contents) {
            SKTImage *newImage = [[SKTImage allocWithZone:[[self drawDocument] zone]] init];
            [newImage setBounds:NSMakeRect(point.x, point.y, [contents size].width, [contents size].height)];
            [newImage setImage:contents];
            [contents release];
            [[self drawDocument] insertGraphic:newImage atIndex:0];
            [newImage release];
            [self clearSelection];
            [self selectGraphic:newImage];
            return YES;
        }
    }
    return NO;
}

// Dragging
- (unsigned int)dragOperationForDraggingInfo:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSColorPboardType, NSFilenamesPboardType, nil]];
    
    if (type) {
        if ([type isEqualToString:NSColorPboardType]) {
            NSPoint point = [self convertPoint:[sender draggingLocation] fromView:nil];
            if ([self graphicUnderPoint:point]) {
                return NSDragOperationGeneric;
            }
        }
        if ([type isEqualToString:NSFilenamesPboardType]) {
            return NSDragOperationCopy;
        }
    }

    type = [pboard availableTypeFromArray:[NSImage imagePasteboardTypes]];
    if (type) {
        return NSDragOperationCopy;
    }
    
    return NSDragOperationNone;
}

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender {
    return [self dragOperationForDraggingInfo:sender];
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender {
    return [self dragOperationForDraggingInfo:sender];
}

- (void)draggingExited:(id <NSDraggingInfo>)sender {
    return;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender {
    return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSColorPboardType, NSFilenamesPboardType, nil]];
    NSPoint point = [self convertPoint:[sender draggingLocation] fromView:nil];
    NSPoint draggedImageLocation = [self convertPoint:[sender draggedImageLocation] fromView:nil];

    if (type) {
        if ([type isEqualToString:NSColorPboardType]) {
            SKTGraphic *hitGraphic = [self graphicUnderPoint:point];
            
            if (hitGraphic) {
                NSColor *color = [[NSColor colorFromPasteboard:pboard] colorWithAlphaComponent:1.0];
                [hitGraphic setFillColor:color];
                [[self undoManager] setActionName:NSLocalizedStringFromTable(@"Set Fill Color", @"UndoStrings", @"Action name for setting fill color.")];
            }
        } else if ([type isEqualToString:NSFilenamesPboardType]) {
            NSArray *filenames = [pboard propertyListForType:NSFilenamesPboardType];
            // Handle multiple files (cascade them?)
            if ([filenames count] == 1) {
                NSString *filename = [filenames objectAtIndex:0];
                [self makeNewImageFromContentsOfFile:filename atPoint:point];
            }
        }
        return;
    }

    (void)[self makeNewImageFromPasteboard:pboard atPoint:draggedImageLocation];
}

// Ruler support
- (void)updateRulers {
    NSScrollView *enclosingScrollView = [self enclosingScrollView];
    if ([enclosingScrollView rulersVisible]) {
        // MF: Eventually, it'd be nice if we added ruler markers for the selection, but for now we just clear them.  By clearing the markers we make sure that no markers from text editing are left over when the editing stops.
        [[enclosingScrollView verticalRulerView] setMarkers:nil];
        [[enclosingScrollView horizontalRulerView] setMarkers:nil];
    }
}

- (BOOL)rulerView:(NSRulerView *)ruler shouldMoveMarker:(NSRulerMarker *)marker {
    return YES;
}

- (float)rulerView:(NSRulerView *)ruler willMoveMarker:(NSRulerMarker *)marker toLocation:(float)location {
    return location;
}

- (void)rulerView:(NSRulerView *)ruler didMoveMarker:(NSRulerMarker *)marker {
    
}

- (BOOL)rulerView:(NSRulerView *)ruler shouldRemoveMarker:(NSRulerMarker *)marker {
    return NO;
}

#define SKT_RULER_MARKER_THICKNESS 8.0
#define SKT_RULER_ACCESSORY_THICKNESS 10.0

- (IBAction)toggleRuler:(id)sender {
    NSScrollView *enclosingScrollView = [self enclosingScrollView];
    BOOL rulersAreVisible = [enclosingScrollView rulersVisible];
    if (rulersAreVisible) {
        [enclosingScrollView setRulersVisible:NO];
    } else {
        if (!_gvFlags.initedRulers) {
            NSRulerView *ruler;
            ruler = [enclosingScrollView horizontalRulerView];
            [ruler setReservedThicknessForMarkers:SKT_RULER_MARKER_THICKNESS];
            [ruler setReservedThicknessForAccessoryView:SKT_RULER_ACCESSORY_THICKNESS];
            ruler = [enclosingScrollView verticalRulerView];
            [ruler setReservedThicknessForMarkers:SKT_RULER_MARKER_THICKNESS];
            [ruler setReservedThicknessForAccessoryView:SKT_RULER_ACCESSORY_THICKNESS];
            _gvFlags.initedRulers = YES;
        }
        [enclosingScrollView setRulersVisible:YES];
        [self updateRulers];
    }
}

// Action methods and other UI entry points
- (void)changeColor:(id)sender {
    NSArray *selGraphics = [self selectedGraphics];
    unsigned i, c = [selGraphics count];
    if (c > 0) {
        SKTGraphic *curGraphic;
        NSColor *color = [sender color];

        for (i=0; i<c; i++) {
            curGraphic = [selGraphics objectAtIndex:i];
            [curGraphic setFillColor:color];
            [curGraphic setDrawsFill:YES];
        }
        [[self undoManager] setActionName:NSLocalizedStringFromTable(@"Set Fill Color", @"UndoStrings", @"Action name for setting fill color.")];
    }
}

- (IBAction)selectAll:(id)sender {
    NSArray *graphics = [[self drawDocument] graphics];
    [self performSelector:@selector(selectGraphic:) withEachObjectInArray:graphics];
}

- (IBAction)deselectAll:(id)sender {
    [self clearSelection];
}

- (IBAction)delete:(id)sender {
    NSArray *selCopy = [[NSArray allocWithZone:[self zone]] initWithArray:[self selectedGraphics]];
    if ([selCopy count] > 0) {
        [[self drawDocument] performSelector:@selector(removeGraphic:) withEachObjectInArray:selCopy];
        [selCopy release];
        [[[self drawDocument] undoManager] setActionName:NSLocalizedStringFromTable(@"Delete", @"UndoStrings", @"Action name for deletions.")];
    }
}

- (IBAction)bringToFront:(id)sender {
    NSArray *orderedSelection = [self orderedSelectedGraphics];
    unsigned c = [orderedSelection count];
    if (c > 0) {
        SKTDrawDocument *document = [self drawDocument];
        while (c-- > 0) {
            [document moveGraphic:[orderedSelection objectAtIndex:c] toIndex:0];
        }
        [[self undoManager] setActionName:NSLocalizedStringFromTable(@"Bring To Front", @"UndoStrings", @"Action name for bring to front.")];
    }
}

- (IBAction)sendToBack:(id)sender {
    NSArray *orderedSelection = [self orderedSelectedGraphics];
    unsigned i, c = [orderedSelection count];
    if (c > 0) {
        SKTDrawDocument *document = [self drawDocument];
        unsigned lastIndex = [[self graphics] count];
        for (i=0; i<c; i++) {
            [document moveGraphic:[orderedSelection objectAtIndex:i] toIndex:lastIndex];
        }
        [[self undoManager] setActionName:NSLocalizedStringFromTable(@"Send To Back", @"UndoStrings", @"Action name for send to back.")];
    }
}

- (IBAction)alignLeftEdges:(id)sender {
    NSArray *selection = [self selectedGraphics];
    unsigned i, c = [selection count];
    if (c > 1) {
        NSRect firstBounds = [[selection objectAtIndex:0] bounds];
        SKTGraphic *curGraphic;
        NSRect curBounds;
        for (i=1; i<c; i++) {
            curGraphic = [selection objectAtIndex:i];
            curBounds = [curGraphic bounds];
            if (curBounds.origin.x != firstBounds.origin.x) {
                curBounds.origin.x = firstBounds.origin.x;
                [curGraphic setBounds:curBounds];
            }
        }
        [[self undoManager] setActionName:NSLocalizedStringFromTable(@"Align Left Edges", @"UndoStrings", @"Action name for align left edges.")];
    }
}

- (IBAction)alignRightEdges:(id)sender {
    NSArray *selection = [self selectedGraphics];
    unsigned i, c = [selection count];
    if (c > 1) {
        NSRect firstBounds = [[selection objectAtIndex:0] bounds];
        SKTGraphic *curGraphic;
        NSRect curBounds;
        for (i=1; i<c; i++) {
            curGraphic = [selection objectAtIndex:i];
            curBounds = [curGraphic bounds];
            if (NSMaxX(curBounds) != NSMaxX(firstBounds)) {
                curBounds.origin.x = NSMaxX(firstBounds) - curBounds.size.width;
                [curGraphic setBounds:curBounds];
            }
        }
        [[self undoManager] setActionName:NSLocalizedStringFromTable(@"Align Right Edges", @"UndoStrings", @"Action name for align right edges.")];
    }
}

- (IBAction)alignTopEdges:(id)sender {
    NSArray *selection = [self selectedGraphics];
    unsigned i, c = [selection count];
    if (c > 1) {
        NSRect firstBounds = [[selection objectAtIndex:0] bounds];
        SKTGraphic *curGraphic;
        NSRect curBounds;
        for (i=1; i<c; i++) {
            curGraphic = [selection objectAtIndex:i];
            curBounds = [curGraphic bounds];
            if (curBounds.origin.y != firstBounds.origin.y) {
                curBounds.origin.y = firstBounds.origin.y;
                [curGraphic setBounds:curBounds];
            }
        }
        [[self undoManager] setActionName:NSLocalizedStringFromTable(@"Align Top Edges", @"UndoStrings", @"Action name for align top edges.")];
    }
}

- (IBAction)alignBottomEdges:(id)sender {
    NSArray *selection = [self selectedGraphics];
    unsigned i, c = [selection count];
    if (c > 1) {
        NSRect firstBounds = [[selection objectAtIndex:0] bounds];
        SKTGraphic *curGraphic;
        NSRect curBounds;
        for (i=1; i<c; i++) {
            curGraphic = [selection objectAtIndex:i];
            curBounds = [curGraphic bounds];
            if (NSMaxY(curBounds) != NSMaxY(firstBounds)) {
                curBounds.origin.y = NSMaxY(firstBounds) - curBounds.size.height;
                [curGraphic setBounds:curBounds];
            }
        }
        [[self undoManager] setActionName:NSLocalizedStringFromTable(@"Align Bottom Edges", @"UndoStrings", @"Action name for align bottom edges.")];
    }
}

- (IBAction)alignHorizontalCenters:(id)sender {
    NSArray *selection = [self selectedGraphics];
    unsigned i, c = [selection count];
    if (c > 1) {
        NSRect firstBounds = [[selection objectAtIndex:0] bounds];
        SKTGraphic *curGraphic;
        NSRect curBounds;
        for (i=1; i<c; i++) {
            curGraphic = [selection objectAtIndex:i];
            curBounds = [curGraphic bounds];
            if (NSMidX(curBounds) != NSMidX(firstBounds)) {
                curBounds.origin.x = NSMidX(firstBounds) - (curBounds.size.width / 2.0);
                [curGraphic setBounds:curBounds];
            }
        }
        [[self undoManager] setActionName:NSLocalizedStringFromTable(@"Align Horizontal Centers", @"UndoStrings", @"Action name for align horizontal centers.")];
    }
}

- (IBAction)alignVerticalCenters:(id)sender {
    NSArray *selection = [self selectedGraphics];
    unsigned i, c = [selection count];
    if (c > 1) {
        NSRect firstBounds = [[selection objectAtIndex:0] bounds];
        SKTGraphic *curGraphic;
        NSRect curBounds;
        for (i=1; i<c; i++) {
            curGraphic = [selection objectAtIndex:i];
            curBounds = [curGraphic bounds];
            if (NSMidY(curBounds) != NSMidY(firstBounds)) {
                curBounds.origin.y = NSMidY(firstBounds) - (curBounds.size.height / 2.0);
                [curGraphic setBounds:curBounds];
            }
        }
        [[self undoManager] setActionName:NSLocalizedStringFromTable(@"Align Vertical Centers", @"UndoStrings", @"Action name for align vertical centers.")];
    }
}

- (IBAction)makeSameWidth:(id)sender {
    NSArray *selection = [self selectedGraphics];
    unsigned i, c = [selection count];
    if (c > 1) {
        NSRect firstBounds = [[selection objectAtIndex:0] bounds];
        SKTGraphic *curGraphic;
        NSRect curBounds;
        for (i=1; i<c; i++) {
            curGraphic = [selection objectAtIndex:i];
            curBounds = [curGraphic bounds];
            if (curBounds.size.width != firstBounds.size.width) {
                curBounds.size.width = firstBounds.size.width;
                [curGraphic setBounds:curBounds];
            }
        }
        [[self undoManager] setActionName:NSLocalizedStringFromTable(@"Make Same Width", @"UndoStrings", @"Action name for make same width.")];
    }
}

- (IBAction)makeSameHeight:(id)sender {
    NSArray *selection = [self selectedGraphics];
    unsigned i, c = [selection count];
    if (c > 1) {
        NSRect firstBounds = [[selection objectAtIndex:0] bounds];
        SKTGraphic *curGraphic;
        NSRect curBounds;
        for (i=1; i<c; i++) {
            curGraphic = [selection objectAtIndex:i];
            curBounds = [curGraphic bounds];
            if (curBounds.size.height != firstBounds.size.height) {
                curBounds.size.height = firstBounds.size.height;
                [curGraphic setBounds:curBounds];
            }
        }
        [[self undoManager] setActionName:NSLocalizedStringFromTable(@"Make Same Width", @"UndoStrings", @"Action name for make same width.")];
    }
}

- (IBAction)makeNaturalSize:(id)sender {
    NSArray *selection = [self selectedGraphics];
    if ([selection count] > 0) {
        [selection makeObjectsPerformSelector:@selector(makeNaturalSize)];
        [[self undoManager] setActionName:NSLocalizedStringFromTable(@"Make Natural Size", @"UndoStrings", @"Action name for natural size.")];
    }
}

- (IBAction)snapsToGridMenuAction:(id)sender {
    [self setSnapsToGrid:([sender state] ? NO : YES)];
    // Menu item will get state fixed up in validateMenuItem:
    [[SKTGridPanelController sharedGridPanelController] updatePanel];
}

- (IBAction)showsGridMenuAction:(id)sender {
    [self setShowsGrid:([sender state] ? NO : YES)];
    // Menu item will get state fixed up in validateMenuItem:
    [[SKTGridPanelController sharedGridPanelController] updatePanel];
}

- (IBAction)gridSelectedGraphicsAction:(id)sender {
    NSArray *selection = [self selectedGraphics];
    unsigned i, c = [selection count];
    if (c > 0) {
        SKTGraphic *curGraphic;
        NSRect curBounds;
        NSPoint curMaxPoint;
        float spacing = [self gridSpacing];
        
        for (i=0; i<c; i++) {
            curGraphic = [selection objectAtIndex:i];
            curBounds = [curGraphic bounds];
            curMaxPoint = NSMakePoint(NSMaxX(curBounds), NSMaxY(curBounds));
            curBounds.origin.x = floor((curBounds.origin.x / spacing) + 0.5) * spacing;
            curBounds.origin.y = floor((curBounds.origin.y / spacing) + 0.5) * spacing;
            curMaxPoint.x = floor((curMaxPoint.x / spacing) + 0.5) * spacing;
            curMaxPoint.y = floor((curMaxPoint.y / spacing) + 0.5) * spacing;
            curBounds.size.width = curMaxPoint.x - curBounds.origin.x;
            curBounds.size.height = curMaxPoint.y - curBounds.origin.y;
            [curGraphic setBounds:curBounds];
        }
        [[self undoManager] setActionName:NSLocalizedStringFromTable(@"Grid Selected Graphics", @"UndoStrings", @"Action name for grid selected graphics.")];
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)item {
    SEL action = [item action];

    if (action == @selector(snapsToGridMenuAction:)) {
        [item setState:([self snapsToGrid] ? NSOnState : NSOffState)];
        return YES;
    } else if (action == @selector(showsGridMenuAction:)) {
        [item setState:([self showsGrid] ? NSOnState : NSOffState)];
        return YES;
    } else if (action == @selector(makeNaturalSize:)) {
        // Return YES if we have at least one selected graphic that has a natural size.
        NSArray *selectedGraphics = [self selectedGraphics];
        unsigned i, c = [selectedGraphics count];
        if (c > 0) {
            for (i=0; i<c; i++) {
                if ([[selectedGraphics objectAtIndex:i] hasNaturalSize]) {
                    return YES;
                }
            }
        }
        return NO;
    } else if ((action == @selector(gridSelectedGraphicsAction:)) || (action == @selector(delete:)) || (action == @selector(bringToFront:)) || (action == @selector(sendToBack:)) || (action == @selector(cut:)) || (action == @selector(copy:))) {
        // These only apply if there is a selection
        return (([[self selectedGraphics] count] > 0) ? YES : NO);
    } else if ((action == @selector(alignLeftEdges:)) || (action == @selector(alignRightEdges:)) || (action == @selector(alignTopEdges:)) || (action == @selector(alignBottomEdges:)) || (action == @selector(alignHorizontalCenters:)) || (action == @selector(alignVerticalCenters:)) || (action == @selector(alignTextBaselines:)) || (action == @selector(makeSameWidth:)) || (action == @selector(makeSameHeight:))) {
        // These only apply to multiple selection
        return (([[self selectedGraphics] count] > 1) ? YES : NO);
    } else {
        return YES;
    }
}

- (IBAction)copy:(id)sender {
    NSArray *orderedSelection = [self orderedSelectedGraphics];
    if ([orderedSelection count] > 0) {
        SKTDrawDocument *document = [self drawDocument];
        NSPasteboard *pboard = [NSPasteboard generalPasteboard];

        [pboard declareTypes:[NSArray arrayWithObjects:SKTDrawDocumentType, NSTIFFPboardType, NSPDFPboardType, nil] owner:nil];
        [pboard setData:[document drawDocumentDataForGraphics:orderedSelection] forType:SKTDrawDocumentType];
        [pboard setData:[document TIFFRepresentationForGraphics:orderedSelection error:NULL] forType:NSTIFFPboardType];
        [pboard setData:[document PDFRepresentationForGraphics:orderedSelection] forType:NSPDFPboardType];
        _pasteboardChangeCount = [pboard changeCount];
        _pasteCascadeNumber = 1;
        _pasteCascadeDelta = NSMakePoint(SKTDefaultPasteCascadeDelta, SKTDefaultPasteCascadeDelta);
    }
}

- (IBAction)cut:(id)sender {
    [self copy:sender];
    [self delete:sender];
    [[self undoManager] setActionName:NSLocalizedStringFromTable(@"Cut", @"UndoStrings", @"Action name for cut.")];
}

- (IBAction)paste:(id)sender {
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:SKTDrawDocumentType, NSFilenamesPboardType, nil]];

    if (type) {
        if ([type isEqualToString:SKTDrawDocumentType]) {

	    // You can't trust anything that might have been put on the pasteboard by another application, so be ready for -[SKTDrawDocument drawDocumentDictionaryFromData:error:] to fail and return nil.
	    NSError *error;
	    SKTDrawDocument *document = [self drawDocument];
            NSDictionary *docDict = [document drawDocumentDictionaryFromData:[pboard dataForType:type] error:&error];
	    if (docDict) {
		NSArray *array = [document graphicsFromDrawDocumentDictionary:docDict];
		int i = [array count];
		int currentChangeCount = [pboard changeCount];
		
		if (_pasteboardChangeCount != currentChangeCount) {
		    _pasteboardChangeCount = currentChangeCount;
		    _pasteCascadeNumber = 0;
		    _pasteCascadeDelta = NSMakePoint(SKTDefaultPasteCascadeDelta, SKTDefaultPasteCascadeDelta);
		}

		if (i > 0) {
		    id curGraphic;
		    NSPoint savedPasteCascadeDelta = _pasteCascadeDelta;
		    
		    [self clearSelection];
		    while (i-- > 0) {
			curGraphic = [array objectAtIndex:i];
			if (_pasteCascadeNumber > 0) {
			    [curGraphic moveBy:NSMakePoint(_pasteCascadeNumber * savedPasteCascadeDelta.x, _pasteCascadeNumber * savedPasteCascadeDelta.y)];
			}
			[document insertGraphic:curGraphic atIndex:0];
			[self selectGraphic:curGraphic];
		    }
		    _pasteCascadeNumber++;
		    _pasteCascadeDelta = savedPasteCascadeDelta;
		    [[self undoManager] setActionName:NSLocalizedStringFromTable(@"Paste", @"UndoStrings", @"Action name for paste.")];
		}
	    } else {

		// Something went wrong? Present the error to the user in a sheet. It was entirely -[NSDocument drawDocumentDictionaryFromData:error:]'s responsibility to set error to something when it returned nil. It was also entirely responsible for not crashing if we had passed in error:NULL.
		[self presentError:error modalForWindow:[self window] delegate:nil didPresentSelector:NULL contextInfo:NULL];

	    }

	} else if ([type isEqualToString:NSFilenamesPboardType]) {
            NSArray *filenames = [pboard propertyListForType:NSFilenamesPboardType];
            if ([filenames count] == 1) {
                NSString *filename = [filenames objectAtIndex:0];
                if ([self makeNewImageFromContentsOfFile:filename atPoint:NSMakePoint(50, 50)]) {
                    [[self undoManager] setActionName:NSLocalizedStringFromTable(@"Paste", @"UndoStrings", @"Action name for paste.")];
                }
            }
        }
    } else if ([self makeNewImageFromPasteboard:pboard atPoint:NSMakePoint(50, 50)]) {
        [[self undoManager] setActionName:NSLocalizedStringFromTable(@"Paste", @"UndoStrings", @"Action name for paste.")];
    }
}

// Keyboard commands
- (void)keyDown:(NSEvent *)event {
    // Pass on the key binding manager.  This will end up calling insertText: or some command selector.
    [self interpretKeyEvents:[NSArray arrayWithObject:event]];
}

- (void)insertText:(NSString *)str {
    NSBeep();
}

- (void)hideKnobsMomentarily {
    if (_unhideKnobsTimer) {
        [_unhideKnobsTimer invalidate];
        _unhideKnobsTimer = nil;
    }
    _unhideKnobsTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(unhideKnobs:) userInfo:nil repeats:NO];
    _gvFlags.knobsHidden = YES;
    [self invalidateGraphics:[self selectedGraphics]];
}

- (void)unhideKnobs:(NSTimer *)timer {
    _gvFlags.knobsHidden = NO;
    [self invalidateGraphics:[self selectedGraphics]];
    [_unhideKnobsTimer invalidate];
    _unhideKnobsTimer = nil;
}

- (void)moveSelectedGraphicsByPoint:(NSPoint)delta {
    NSArray *selection = [self selectedGraphics];
    unsigned i, c = [selection count];
    if (c > 0) {
        [self hideKnobsMomentarily];
        for (i=0; i<c; i++) {
            [[selection objectAtIndex:i] moveBy:delta];
        }
        [[self undoManager] setActionName:NSLocalizedStringFromTable(@"Nudge", @"UndoStrings", @"Action name for nudge keyboard commands.")];
    }
}

- (void)moveLeft:(id)sender {
    [self moveSelectedGraphicsByPoint:NSMakePoint(-1.0, 0.0)];
}

- (void)moveRight:(id)sender {
    [self moveSelectedGraphicsByPoint:NSMakePoint(1.0, 0.0)];
}

- (void)moveUp:(id)sender {
    [self moveSelectedGraphicsByPoint:NSMakePoint(0.0, -1.0)];
}

- (void)moveDown:(id)sender {
    [self moveSelectedGraphicsByPoint:NSMakePoint(0.0, 1.0)];
}

- (void)moveForwardAndModifySelection:(id)sender {
    // We will use this to move by the grid spacing.
    [self moveSelectedGraphicsByPoint:NSMakePoint([self gridSpacing], 0.0)];
}

- (void)moveBackwardAndModifySelection:(id)sender {
    // We will use this to move by the grid spacing.
    [self moveSelectedGraphicsByPoint:NSMakePoint(-[self gridSpacing], 0.0)];
}

- (void)moveUpAndModifySelection:(id)sender {
    // We will use this to move by the grid spacing.
    [self moveSelectedGraphicsByPoint:NSMakePoint(0.0, -[self gridSpacing])];
}

- (void)moveDownAndModifySelection:(id)sender {
    // We will use this to move by the grid spacing.
    [self moveSelectedGraphicsByPoint:NSMakePoint(0.0, [self gridSpacing])];
}

- (void)deleteForward:(id)sender {
    [self delete:sender];
}

- (void)deleteBackward:(id)sender {
    [self delete:sender];
}

// Grid settings
- (BOOL)snapsToGrid {
    return _gvFlags.snapsToGrid;
}

- (void)setSnapsToGrid:(BOOL)flag {
    _gvFlags.snapsToGrid = flag;
}

- (BOOL)showsGrid {
    return _gvFlags.showsGrid;
}

- (void)setShowsGrid:(BOOL)flag {
    if (_gvFlags.showsGrid != flag) {
        _gvFlags.showsGrid = flag;
        [self setNeedsDisplay:YES];
    }
}

- (float)gridSpacing {
    return _gridSpacing;
}

- (void)setGridSpacing:(float)spacing {
    if (_gridSpacing != spacing) {
        _gridSpacing = spacing;
        [self setNeedsDisplay:YES];
    }
}

- (NSColor *)gridColor {
    return (_gridColor ? _gridColor : [NSColor lightGrayColor]);
}

- (void)setGridColor:(NSColor *)color {
    if (_gridColor != color) {
        [_gridColor release];
        _gridColor = [color retain];
        [self setNeedsDisplay:YES];
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
