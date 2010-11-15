// SKTGridPanelController.m
// Sketch Example
//

#import "SKTGridPanelController.h"
#import "SKTGridView.h"
#import "SKTGraphicView.h"
#import "SKTDrawWindowController.h"
#import <math.h>

@implementation SKTGridPanelController

+ (id)sharedGridPanelController {
    static SKTGridPanelController *sharedGridPanelController = nil;

    if (!sharedGridPanelController) {
        sharedGridPanelController = [[SKTGridPanelController allocWithZone:NULL] init];
    }

    return sharedGridPanelController;
}

- (id)init {
    self = [self initWithWindowNibName:@"GridPanel"];
    if (self) {
        [self setWindowFrameAutosaveName:@"Grid"];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)updatePanel {
    if ([self isWindowLoaded]) {
        BOOL hasGraphicView = ((_inspectingGraphicView == nil) ? NO : YES);
        [snapsToGridCheckbox setState:([self snapsToGrid] ? NSOnState : NSOffState)];
        [showsGridCheckbox setState:([self showsGrid] ? NSOnState : NSOffState)];
        [gridSpacingSlider setIntValue:[self gridSpacing]];
        [gridColorWell setColor:[self gridColor]];
        [snapsToGridCheckbox setEnabled:hasGraphicView];
        [showsGridCheckbox setEnabled:hasGraphicView];
        [gridSpacingSlider setEnabled:hasGraphicView];
        [gridColorWell setEnabled:hasGraphicView];
        [gridView setNeedsDisplay:YES];
    }
}

- (void)setMainWindow:(NSWindow *)mainWindow {
    NSWindowController *controller = [mainWindow windowController];

    if (controller && [controller isKindOfClass:[SKTDrawWindowController class]]) {
        _inspectingGraphicView = [(SKTDrawWindowController *)controller graphicView];
    } else {
        _inspectingGraphicView = nil;
    }
    [self updatePanel];
}

- (void)mainWindowChanged:(NSNotification *)notification {
    [self setMainWindow:[notification object]];
}

- (void)mainWindowResigned:(NSNotification *)notification {
    [self setMainWindow:nil];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    [(NSPanel *)[self window] setFloatingPanel:YES];
    [(NSPanel *)[self window] setBecomesKeyOnlyIfNeeded:YES];
    [self setMainWindow:[NSApp mainWindow]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mainWindowChanged:) name:NSWindowDidBecomeMainNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mainWindowResigned:) name:NSWindowDidResignMainNotification object:nil];
}

- (BOOL)snapsToGrid {
    return (_inspectingGraphicView ? [_inspectingGraphicView snapsToGrid] : NO);
}

- (BOOL)showsGrid {
    return (_inspectingGraphicView ? [_inspectingGraphicView showsGrid] : NO);
}

- (float)gridSpacing {
    return (_inspectingGraphicView ? [_inspectingGraphicView gridSpacing] : 8);
}

- (NSColor *)gridColor {
    return (_inspectingGraphicView ? [_inspectingGraphicView gridColor] : [NSColor lightGrayColor]);
}

- (IBAction)snapsToGridCheckboxAction:(id)sender {
    if (_inspectingGraphicView) {
        [_inspectingGraphicView setSnapsToGrid:[sender state]];
    }
}

- (IBAction)showsGridCheckboxAction:(id)sender {
    if (_inspectingGraphicView) {
        [_inspectingGraphicView setShowsGrid:[sender state]];
    }
}

- (IBAction)gridSpacingSliderAction:(id)sender {
    if (_inspectingGraphicView) {
        [_inspectingGraphicView setGridSpacing:(float)[sender intValue]];
    }
    [gridView setNeedsDisplay:YES];
}

- (IBAction)gridColorWellAction:(id)sender {
    if (_inspectingGraphicView) {
        [_inspectingGraphicView setGridColor:[sender color]];
    }
    [gridView setNeedsDisplay:YES];
}

@end

void SKTDrawGridWithSettingsInRect(float spacing, NSColor *color, NSRect rect, NSPoint gridOrigin) {
    int curLine, endLine;
    NSBezierPath *gridPath = [NSBezierPath bezierPath];

    [color set];

    // Columns
    curLine = ceil((NSMinX(rect) - gridOrigin.x) / spacing);
    endLine = floor((NSMaxX(rect) - gridOrigin.x) / spacing);
    for (; curLine<=endLine; curLine++) {
        [gridPath moveToPoint:NSMakePoint((curLine * spacing) + gridOrigin.x, NSMinY(rect))];
        [gridPath lineToPoint:NSMakePoint((curLine * spacing) + gridOrigin.x, NSMaxY(rect))];
    }

    // Rows
    curLine = ceil((NSMinY(rect) - gridOrigin.y) / spacing);
    endLine = floor((NSMaxY(rect) - gridOrigin.y) / spacing);
    for (; curLine<=endLine; curLine++) {
        [gridPath moveToPoint:NSMakePoint(NSMinX(rect), (curLine * spacing) + gridOrigin.y)];
        [gridPath lineToPoint:NSMakePoint(NSMaxX(rect), (curLine * spacing) + gridOrigin.y)];
    }

    [gridPath setLineWidth:0.0];
    [gridPath stroke];
}



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
