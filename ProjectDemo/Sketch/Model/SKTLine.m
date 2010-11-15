// SKTLine.m
// Sketch Example
//

#import "SKTLine.h"
#import "SKTGraphicView.h"
#import <math.h>

@implementation SKTLine

- (id)copyWithZone:(NSZone *)zone {
    id newObj = [super copyWithZone:zone];

    [newObj setStartsAtLowerLeft:[self startsAtLowerLeft]];

    return newObj;
}

- (void)setStartsAtLowerLeft:(BOOL)flag {
    if (_startsAtLowerLeft != flag) {
        [[[self undoManager] prepareWithInvocationTarget:self] setStartsAtLowerLeft:_startsAtLowerLeft];
        _startsAtLowerLeft = flag;
        [self didChange];
    }
}

- (BOOL)startsAtLowerLeft {
    return _startsAtLowerLeft;
}

- (void)flipHorizontally {
    [self setStartsAtLowerLeft:![self startsAtLowerLeft]];
    return;
}

- (void)flipVertically {
    [self setStartsAtLowerLeft:![self startsAtLowerLeft]];
    return;
}

- (BOOL)drawsFill {
    // SKTLines never draw fill
    return NO;
}

- (BOOL)canDrawFill {
    // SKTLines never draw fill
    return NO;
}

- (BOOL)hasNaturalSize {
    // SKTLines have no "natural" size
    return NO;
}

- (NSBezierPath *)bezierPath {
    NSBezierPath *path = [NSBezierPath bezierPath];
    NSRect bounds = [self bounds];
    
    if ([self startsAtLowerLeft]) {
        [path moveToPoint:NSMakePoint(NSMinX(bounds), NSMaxY(bounds))];
        [path lineToPoint:NSMakePoint(NSMaxX(bounds), NSMinY(bounds))];
    } else {
        [path moveToPoint:NSMakePoint(NSMinX(bounds), NSMinY(bounds))];
        [path lineToPoint:NSMakePoint(NSMaxX(bounds), NSMaxY(bounds))];
    }

    [path setLineWidth:[self strokeLineWidth]];

    return path;
}

- (unsigned)knobMask {
    if ([self startsAtLowerLeft]) {
        return (LowerLeftKnobMask | UpperRightKnobMask);
    } else {
        return (UpperLeftKnobMask | LowerRightKnobMask);
    }
}

- (BOOL)hitTest:(NSPoint)point isSelected:(BOOL)isSelected {
    if (isSelected && ([self knobUnderPoint:point] != NoKnob)) {
        return YES;
    } else {
        NSRect bounds = [self bounds];
        float halfWidth = [self strokeLineWidth] / 2.0;
        halfWidth += 2.0;  // Fudge
        if (bounds.size.width == 0.0) {
            if (fabs(point.x - bounds.origin.x) <= halfWidth) {
                return YES;
            }
        } else {
            BOOL startsAtLowerLeft = [self startsAtLowerLeft];
            float slope = bounds.size.height / bounds.size.width;

            if (startsAtLowerLeft) {
                slope = -slope;
            }

            
            if (fabs(((point.x - bounds.origin.x) * slope) - (point.y - (startsAtLowerLeft ? NSMaxY(bounds) : bounds.origin.y))) <= halfWidth) {
                return YES;
            }
        }
        return NO;
    }
}

NSString *SKTLineStartsAtLowerLeftKey = @"LineStartsAtLowerLeft";

- (NSMutableDictionary *)propertyListRepresentation {
    NSMutableDictionary *dict = [super propertyListRepresentation];
    [dict setObject:([self startsAtLowerLeft] ? @"YES" : @"NO") forKey:SKTLineStartsAtLowerLeftKey];
    return dict;
}

- (void)loadPropertyListRepresentation:(NSDictionary *)dict {
    id obj;
    
    [super loadPropertyListRepresentation:dict];

    obj = [dict objectForKey:SKTLineStartsAtLowerLeftKey];
    if (obj) {
        [self setStartsAtLowerLeft:[obj isEqualToString:@"YES"]];
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
