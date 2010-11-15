// SKTGraphicView.h
// Sketch Example
//

#import <AppKit/AppKit.h>

@class SKTDrawWindowController;
@class SKTDrawDocument;
@class SKTGraphic;

#define SKT_HALF_HANDLE_WIDTH 3.0
#define SKT_HANDLE_WIDTH (SKT_HALF_HANDLE_WIDTH * 2.0)


@interface SKTGraphicView : NSView {
    @private
    IBOutlet SKTDrawWindowController *controller;
    NSMutableArray *_selectedGraphics;
    SKTGraphic *_creatingGraphic;
    NSRect _rubberbandRect;
    NSSet *_rubberbandGraphics;
    SKTGraphic *_editingGraphic;
    NSView *_editorView;
    int _pasteboardChangeCount;
    int _pasteCascadeNumber;
    NSPoint _pasteCascadeDelta;
    float _gridSpacing;
    NSColor *_gridColor;
    NSTimer *_unhideKnobsTimer;
    struct __gvFlags {
        unsigned int rubberbandIsDeselecting:1;
        unsigned int initedRulers:1;
        unsigned int snapsToGrid:1;
        unsigned int showsGrid:1;
        unsigned int knobsHidden:1;
        unsigned int _pad:27;
    } _gvFlags;
    NSRect _verticalRulerLineRect;
    NSRect _horizontalRulerLineRect;
}

// SKTDrawWindowController accessors and convenience methods
- (void)setDrawWindowController:(SKTDrawWindowController *)theController;
- (SKTDrawWindowController *)drawWindowController;
- (SKTDrawDocument *)drawDocument;
- (NSArray *)graphics;

// Display invalidation
- (void)invalidateGraphic:(SKTGraphic *)graphic;

// Selection primitives
- (NSArray *)selectedGraphics;
- (NSArray *)orderedSelectedGraphics;
- (BOOL)graphicIsSelected:(SKTGraphic *)graphic;
- (void)selectGraphic:(SKTGraphic *)graphic;
- (void)deselectGraphic:(SKTGraphic *)graphic;
- (void)clearSelection;

// Managing editoring graphics
- (void)setEditingGraphic:(SKTGraphic *)graphic editorView:(NSView *)editorView;
- (SKTGraphic *)editingGraphic;
- (NSView *)editorView;
- (void)startEditingGraphic:(SKTGraphic *)graphic withEvent:(NSEvent *)event;
- (void)endEditing;

// Geometry calculations
- (SKTGraphic *)graphicUnderPoint:(NSPoint)point;
- (NSSet *)graphicsIntersectingRect:(NSRect)rect;

// Drawing and mouse tracking
- (void)drawRect:(NSRect)rect;

- (void)beginEchoingMoveToRulers:(NSRect)echoRect;
- (void)continueEchoingMoveToRulers:(NSRect)echoRect;
- (void)stopEchoingMoveToRulers;

- (void)createGraphicOfClass:(Class)theClass withEvent:(NSEvent *)theEvent;
- (SKTGraphic *)creatingGraphic;
- (void)trackKnob:(int)knob ofGraphic:(SKTGraphic *)graphic withEvent:(NSEvent *)theEvent;
- (void)rubberbandSelectWithEvent:(NSEvent *)theEvent;
- (void)moveSelectedGraphicsWithEvent:(NSEvent *)theEvent;
- (void)selectAndTrackMouseWithEvent:(NSEvent *)theEvent;
- (void)mouseDown:(NSEvent *)theEvent;

// Dragging
- (unsigned int)dragOperationForDraggingInfo:(id <NSDraggingInfo>)sender;
- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender;
- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender;
- (void)draggingExited:(id <NSDraggingInfo>)sender;
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

// Ruler support
- (void)updateRulers;
- (BOOL)rulerView:(NSRulerView *)ruler shouldMoveMarker:(NSRulerMarker *)marker;
- (float)rulerView:(NSRulerView *)ruler willMoveMarker:(NSRulerMarker *)marker toLocation:(float)location;
- (void)rulerView:(NSRulerView *)ruler didMoveMarker:(NSRulerMarker *)marker;
- (BOOL)rulerView:(NSRulerView *)ruler shouldRemoveMarker:(NSRulerMarker *)marker;

// Action methods and other UI entry points
- (void)changeColor:(id)sender;

- (IBAction)selectAll:(id)sender;
- (IBAction)deselectAll:(id)sender;

- (IBAction)delete:(id)sender;
- (IBAction)bringToFront:(id)sender;
- (IBAction)sendToBack:(id)sender;
- (IBAction)alignLeftEdges:(id)sender;
- (IBAction)alignRightEdges:(id)sender;
- (IBAction)alignTopEdges:(id)sender;
- (IBAction)alignBottomEdges:(id)sender;
- (IBAction)alignHorizontalCenters:(id)sender;
- (IBAction)alignVerticalCenters:(id)sender;
- (IBAction)makeSameWidth:(id)sender;
- (IBAction)makeSameHeight:(id)sender;
- (IBAction)makeNaturalSize:(id)sender;
- (IBAction)snapsToGridMenuAction:(id)sender;
- (IBAction)showsGridMenuAction:(id)sender;
- (IBAction)gridSelectedGraphicsAction:(id)sender;

// Grid settings
- (BOOL)snapsToGrid;
- (void)setSnapsToGrid:(BOOL)flag;
- (BOOL)showsGrid;
- (void)setShowsGrid:(BOOL)flag;
- (float)gridSpacing;
- (void)setGridSpacing:(float)spacing;
- (NSColor *)gridColor;
- (void)setGridColor:(NSColor *)color;

@end

extern NSString *SKTGraphicViewSelectionDidChangeNotification;

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
