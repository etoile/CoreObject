// SKTGraphic.h
// Sketch Example
//

#import <AppKit/AppKit.h>

@class SKTGraphicView;
@class SKTDrawDocument;

enum {
    NoKnob = 0,
    UpperLeftKnob,
    UpperMiddleKnob,
    UpperRightKnob,
    MiddleLeftKnob,
    MiddleRightKnob,
    LowerLeftKnob,
    LowerMiddleKnob,
    LowerRightKnob,
};

enum {
    NoKnobsMask = 0,
    UpperLeftKnobMask = 1 << UpperLeftKnob,
    UpperMiddleKnobMask = 1 << UpperMiddleKnob,
    UpperRightKnobMask = 1 << UpperRightKnob,
    MiddleLeftKnobMask = 1 << MiddleLeftKnob,
    MiddleRightKnobMask = 1 << MiddleRightKnob,
    LowerLeftKnobMask = 1 << LowerLeftKnob,
    LowerMiddleKnobMask = 1 << LowerMiddleKnob,
    LowerRightKnobMask = 1 << LowerRightKnob,
    AllKnobsMask = 0xffffffff,
};

extern NSString *SKTGraphicDidChangeNotification;

@interface SKTGraphic : NSObject <NSCopying> {
    @private
    SKTDrawDocument *_document;
    NSRect _bounds;
    NSRect _origBounds;
    float _lineWidth;
    NSColor *_fillColor;
    NSColor *_strokeColor;
    struct __gFlags {
        unsigned int drawsFill:1;
        unsigned int drawsStroke:1;
        unsigned int manipulatingBounds:1;
        unsigned int _pad:29;
    } _gFlags;
}

- (id)init;

// ========================= Document accessors and conveniences =========================
- (void)setDocument:(SKTDrawDocument *)document;
- (SKTDrawDocument *)document;
- (NSUndoManager *)undoManager;

// =================================== Primitives ===================================
- (void)didChange;
    // This sends the did change notification.  All change primitives should call it.

- (void)setBounds:(NSRect)bounds;
- (NSRect)bounds;
- (void)setDrawsFill:(BOOL)flag;
- (BOOL)drawsFill;
- (void)setFillColor:(NSColor *)fillColor;
- (NSColor *)fillColor;
- (void)setDrawsStroke:(BOOL)flag;
- (BOOL)drawsStroke;
- (void)setStrokeColor:(NSColor *)strokeColor;
- (NSColor *)strokeColor;
- (void)setStrokeLineWidth:(float)width;
- (float)strokeLineWidth;

// =================================== Extended mutation ===================================
- (void)startBoundsManipulation;
- (void)stopBoundsManipulation;
- (void)moveBy:(NSPoint)vector;
- (void)flipHorizontally;
- (void)flipVertically;
- (int)resizeByMovingKnob:(int)knob toPoint:(NSPoint)point;
- (void)makeNaturalSize;

// =================================== Subclass capabilities ===================================
- (BOOL)canDrawStroke;
- (BOOL)canDrawFill;
- (BOOL)hasNaturalSize;

// =================================== Persistence ===================================
- (NSMutableDictionary *)propertyListRepresentation;
+ (id)graphicWithPropertyListRepresentation:(NSDictionary *)dict;
- (void)loadPropertyListRepresentation:(NSDictionary *)dict;

@end

@interface SKTGraphic (SKTDrawing)

- (NSRect)drawingBounds;
- (NSBezierPath *)bezierPath;
- (void)drawInView:(SKTGraphicView *)view isSelected:(BOOL)flag;
- (unsigned)knobMask;
- (int)knobUnderPoint:(NSPoint)point;
- (void)drawHandleAtPoint:(NSPoint)point inView:(SKTGraphicView *)view;
- (void)drawHandlesInView:(SKTGraphicView *)view;

@end

@interface SKTGraphic (SKTEventHandling)

+ (NSCursor *)creationCursor;

- (BOOL)createWithEvent:(NSEvent *)theEvent inView:(SKTGraphicView *)view;

- (BOOL)isEditable;
- (void)startEditingWithEvent:(NSEvent *)event inView:(SKTGraphicView *)view;
- (void)endEditingInView:(SKTGraphicView *)view;

- (BOOL)hitTest:(NSPoint)point isSelected:(BOOL)isSelected;

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
