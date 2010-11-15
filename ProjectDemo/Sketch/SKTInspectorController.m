// SKTInspectorController.m
// Sketch Example
//

#import "SKTInspectorController.h"
#import "SKTDrawWindowController.h"
#import "SKTGraphicView.h"
#import "SKTGraphic.h"

@interface SKTInspectorController (Private)
- (void) updateUI;
@end

@implementation SKTInspectorController

+ (id)sharedInspectorController {
    static SKTInspectorController *_sharedInspectorController = nil;

    if (!_sharedInspectorController) {
        _sharedInspectorController = [[SKTInspectorController allocWithZone:[self zone]] init];
    }
    return _sharedInspectorController;
}

- (id)init {
    self = [self initWithWindowNibName:@"Inspector"];
    if (self) {
        [self setWindowFrameAutosaveName:@"Inspector"];
        needsUpdate = NO;
#ifdef GNUSTEP
		[self updateUI];
#endif
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)setMainWindow:(NSWindow *)mainWindow {
    NSWindowController *controller = [mainWindow windowController];

    if (controller && [controller isKindOfClass:[SKTDrawWindowController class]]) {
        _inspectingGraphicView = [(SKTDrawWindowController *)controller graphicView];
    } else {
        _inspectingGraphicView = nil;
    }
    needsUpdate = YES;
#ifdef GNUSTEP
	[self updateUI];
#endif
}

- (void)windowDidLoad {
    [super windowDidLoad];
    [self setMainWindow:[NSApp mainWindow]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mainWindowChanged:) name:NSWindowDidBecomeMainNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mainWindowResigned:) name:NSWindowDidResignMainNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(graphicChanged:) name:SKTGraphicDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectionChanged:) name:SKTGraphicViewSelectionDidChangeNotification object:nil];
}

- (void)mainWindowChanged:(NSNotification *)notification {
    [self setMainWindow:[notification object]];
}

- (void)mainWindowResigned:(NSNotification *)notification {
    [self setMainWindow:nil];
}

- (void)graphicChanged:(NSNotification *)notification {
    if (_inspectingGraphicView) {
        if ([[_inspectingGraphicView selectedGraphics] containsObject:[notification object]]) {
            needsUpdate = YES;
#ifdef GNUSTEP
/* When multiple objects is selected, fields in inspector 
 * will change to mixed status, which lead chaning of graphics,
 * which then changing the fields in inspector again.
 * So we don't updateUI here */
//			[self updateUI];
#endif
        }
    }
}

- (void)selectionChanged:(NSNotification *)notification {
    if ([notification object] == _inspectingGraphicView) {
        needsUpdate = YES;
#ifdef GNUSTEP
		[self updateUI];
#endif
    }
}

- (void)windowDidUpdate:(NSNotification *)notification {
/* NOTE: GNUstep post this notification when subclass is updated,
 * which creates a recursive situation.
 * We use '#ifdef GNUSTEP' here to show the difference of implementation.
 */
#ifndef GNUSTEP
	[self updateUI];
#endif
}

- (IBAction)fillCheckboxAction:(id)sender {
    NSArray *selectedGraphics = [_inspectingGraphicView selectedGraphics];
    unsigned i, c = [selectedGraphics count];
    if (c > 0) {
        int state = [sender state];

        for (i=0; i<c; i++) {
            [[selectedGraphics objectAtIndex:i] setDrawsFill:((state == NSOnState) ? YES : NO)];
            if ([[selectedGraphics objectAtIndex:i] fillColor] == nil) {
                [[selectedGraphics objectAtIndex:i] setFillColor:[NSColor whiteColor]];
            }
        }
        [[_inspectingGraphicView undoManager] setActionName:NSLocalizedStringFromTable(@"Set Fill Color", @"UndoStrings", @"Action name for set fill color.")];
    }
}

- (IBAction)fillColorWellAction:(id)sender {
    NSArray *selectedGraphics = [_inspectingGraphicView selectedGraphics];
    unsigned i, c = [selectedGraphics count];
    if (c > 0) {
        NSColor *color = [sender color];

        for (i=0; i<c; i++) {
            [[selectedGraphics objectAtIndex:i] setFillColor:color];
        }
        [[_inspectingGraphicView undoManager] setActionName:NSLocalizedStringFromTable(@"Set Fill Color", @"UndoStrings", @"Action name for set fill color.")];
    }
}

- (IBAction)lineCheckboxAction:(id)sender {
    NSArray *selectedGraphics = [_inspectingGraphicView selectedGraphics];
    unsigned i, c = [selectedGraphics count];
    if (c > 0) {
        int state = [sender state];

        for (i=0; i<c; i++) {
            [[selectedGraphics objectAtIndex:i] setDrawsStroke:((state == NSOnState) ? YES : NO)];
            if ([[selectedGraphics objectAtIndex:i] strokeColor] == nil) {
                [[selectedGraphics objectAtIndex:i] setStrokeColor:[NSColor blackColor]];
            }
        }
        [[_inspectingGraphicView undoManager] setActionName:NSLocalizedStringFromTable(@"Set Stroke Color", @"UndoStrings", @"Action name for set stroke color.")];
    }
}

- (IBAction)lineColorWellAction:(id)sender {
    NSArray *selectedGraphics = [_inspectingGraphicView selectedGraphics];
    unsigned i, c = [selectedGraphics count];
    if (c > 0) {
        NSColor *color = [sender color];

        for (i=0; i<c; i++) {
            [[selectedGraphics objectAtIndex:i] setStrokeColor:color];
        }
        [[_inspectingGraphicView undoManager] setActionName:NSLocalizedStringFromTable(@"Set Stroke Color", @"UndoStrings", @"Action name for set stroke color.")];
    }
}

- (IBAction)lineWidthSliderAction:(id)sender {
    NSArray *selectedGraphics = [_inspectingGraphicView selectedGraphics];
    unsigned i, c = [selectedGraphics count];
    if (c > 0) {
        float lineWidth = [sender floatValue];

        for (i=0; i<c; i++) {
            [[selectedGraphics objectAtIndex:i] setStrokeLineWidth:lineWidth];
        }
        [lineWidthTextField setFloatValue:lineWidth];
        [[_inspectingGraphicView undoManager] setActionName:NSLocalizedStringFromTable(@"Set Line Width", @"UndoStrings", @"Action name for set line width.")];
    }
}

- (IBAction)lineWidthTextFieldAction:(id)sender {
    NSArray *selectedGraphics = [_inspectingGraphicView selectedGraphics];
    unsigned i, c = [selectedGraphics count];
    if (c > 0) {
        float lineWidth = [sender floatValue];

        for (i=0; i<c; i++) {
            [[selectedGraphics objectAtIndex:i] setStrokeLineWidth:lineWidth];
        }
        [[_inspectingGraphicView undoManager] setActionName:NSLocalizedStringFromTable(@"Set Line Width", @"UndoStrings", @"Action name for set line width.")];
    }
}

- (IBAction)dimensionTextFieldAction:(id)sender {
    NSArray *selectedGraphics = [_inspectingGraphicView selectedGraphics];
    unsigned i, c = [selectedGraphics count];
    if (c > 0) {
        NSRect bounds = NSMakeRect([xTextField floatValue], [yTextField floatValue], [widthTextField floatValue], [heightTextField floatValue]);

        for (i=0; i<c; i++) {
            [[selectedGraphics objectAtIndex:i] setBounds:bounds];
        }
        [[_inspectingGraphicView undoManager] setActionName:NSLocalizedStringFromTable(@"Set Bounds", @"UndoStrings", @"Action name for numerically setting bounds.")];
    }
}

@end

@implementation SKTInspectorController (Private)
- (void) updateUI {
    if (needsUpdate) {
        NSArray *selectedGraphics = [_inspectingGraphicView selectedGraphics];
        unsigned c = (selectedGraphics ? [selectedGraphics count] : 0);
        SKTGraphic *graphic;

        needsUpdate = NO;
        
        if (c == 1) {
            NSRect bounds;
            BOOL tempFlag;

            graphic = [selectedGraphics objectAtIndex:0];
            bounds = [graphic bounds];
            tempFlag = [graphic drawsFill];
            [fillCheckbox setState:(tempFlag ? NSOnState : NSOffState)];
            [fillCheckbox setEnabled:[graphic canDrawFill]];
            [fillColorWell setColor:([graphic fillColor] ? [graphic fillColor] : [NSColor clearColor])];
            [fillColorWell setEnabled:tempFlag];
            tempFlag = [graphic drawsStroke];
            [lineCheckbox setState:(tempFlag ? NSOnState : NSOffState)];
            [lineCheckbox setEnabled:[graphic canDrawStroke]];
            [lineColorWell setColor:([graphic strokeColor] ? [graphic strokeColor] : [NSColor clearColor])];
            [lineColorWell setEnabled:tempFlag];
            [lineWidthSlider setFloatValue:[graphic strokeLineWidth]];
            [lineWidthSlider setEnabled:tempFlag];
            [lineWidthTextField setFloatValue:[graphic strokeLineWidth]];
            [lineWidthTextField setEnabled:tempFlag];
            [xTextField setFloatValue:bounds.origin.x];
            [xTextField setEnabled:YES];
            [yTextField setFloatValue:bounds.origin.y];
            [yTextField setEnabled:YES];
            [widthTextField setFloatValue:bounds.size.width];
            [widthTextField setEnabled:YES];
            [heightTextField setFloatValue:bounds.size.height];
            [heightTextField setEnabled:YES];
        } else if (c > 1) {
            // MF: Multiple selection should be editable
            [fillCheckbox setState:NSMixedState];
            [fillCheckbox setEnabled:NO];
            [fillColorWell setColor:[NSColor whiteColor]];
            [fillColorWell setEnabled:NO];
            [lineCheckbox setState:NSMixedState];
            [lineCheckbox setEnabled:NO];
            [lineColorWell setColor:[NSColor blackColor]];
            [lineColorWell setEnabled:NO];
            [lineWidthSlider setFloatValue:0.0];
            [lineWidthSlider setEnabled:NO];
            [lineWidthTextField setStringValue:@"--"];
            [lineWidthTextField setEnabled:NO];
            [xTextField setStringValue:@"--"];
            [xTextField setEnabled:NO];
            [yTextField setStringValue:@"--"];
            [yTextField setEnabled:NO];
            [widthTextField setStringValue:@"--"];
            [widthTextField setEnabled:NO];
            [heightTextField setStringValue:@"--"];
            [heightTextField setEnabled:NO];
        } else {
            [fillCheckbox setState:NSOffState];
            [fillCheckbox setEnabled:NO];
            [fillColorWell setColor:[NSColor whiteColor]];
            [fillColorWell setEnabled:NO];
            [lineCheckbox setState:NSOffState];
            [lineCheckbox setEnabled:NO];
            [lineColorWell setColor:[NSColor whiteColor]];
            [lineColorWell setEnabled:NO];
            [lineWidthSlider setFloatValue:0.0];
            [lineWidthSlider setEnabled:NO];
            [lineWidthTextField setFloatValue:0.0];
            [lineWidthTextField setEnabled:NO];
            [xTextField setStringValue:@""];
            [xTextField setEnabled:NO];
            [yTextField setStringValue:@""];
            [yTextField setEnabled:NO];
            [widthTextField setStringValue:@""];
            [widthTextField setEnabled:NO];
            [heightTextField setStringValue:@""];
            [heightTextField setEnabled:NO];
        }
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
