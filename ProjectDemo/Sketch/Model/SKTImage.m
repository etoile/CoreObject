// SKTImage.m
// Sketch Example
//

#import "SKTImage.h"

@implementation SKTImage

- (id)init {
    self = [super init];
    if (self) {
        _image = nil;
        _cachedImage = nil;
    }
    return self;
}

- (void)dealloc {
    if (_image != _cachedImage) {
        [_cachedImage release];
    }
    [_image release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone {
    id newObj = [super copyWithZone:zone];

    [newObj setImage:[self image]];
    [newObj setFlippedHorizontally:[self flippedHorizontally]];
    [newObj setFlippedVertically:[self flippedVertically]];

    return newObj;
}

- (void)SKT_clearCachedImage {
    if (_cachedImage != _image) {
        [_cachedImage release];
    }
    _cachedImage = nil;
}

- (void)setImage:(NSImage *)image {
    if (image != _image) {
        [[[self undoManager] prepareWithInvocationTarget:self] setImage:_image];
        [_image release];
        _image = [image retain];
        [self SKT_clearCachedImage];
        [self didChange];
    }
}

- (NSImage *)image {
    return _image;
}

- (NSImage *)transformedImage {
    if (!_cachedImage) {
        NSRect bounds = [self bounds];
        NSImage *image = [self image];
        NSSize imageSize = [image size];
        
        if (NSEqualSizes(bounds.size, imageSize)) {
            _cachedImage = _image;
        } else if (!NSIsEmptyRect(bounds)) {
            BOOL flippedHorizontally = [self flippedHorizontally];
            BOOL flippedVertically = [self flippedVertically];
            
            _cachedImage = [[NSImage allocWithZone:[self zone]] initWithSize:bounds.size];
            if (!NSIsEmptyRect(bounds)) {
                // Only draw in the image if it has any content.
                [_cachedImage lockFocus];

                if (flippedHorizontally || flippedVertically) {
                    // If the image needs flipping, we need to play some games with the transform matrix
                    NSAffineTransform *transform = [NSAffineTransform transform];
                    [transform scaleXBy:([self flippedHorizontally] ? -1.0 : 1.0) yBy:([self flippedVertically] ? -1.0 : 1.0)];
                    [transform translateXBy:([self flippedHorizontally] ? -bounds.size.width : 0.0) yBy:([self flippedVertically] ? -bounds.size.height : 0.0)];
                    [transform concat];
                }

                [[image bestRepresentationForDevice:nil] drawInRect:NSMakeRect(0.0, 0.0, bounds.size.width, bounds.size.height)];
                [_cachedImage unlockFocus];
            }
        }
    }
    return _cachedImage;
}

- (void)setFlippedHorizontally:(BOOL)flag {
    if (_flippedHorizontally != flag) {
        [[[self undoManager] prepareWithInvocationTarget:self] setFlippedHorizontally:_flippedHorizontally];
        _flippedHorizontally = flag;
        [self SKT_clearCachedImage];
        [self didChange];
    }
}

- (BOOL)flippedHorizontally {
    return _flippedHorizontally;
}

- (void)setFlippedVertically:(BOOL)flag {
    if (_flippedVertically != flag) {
        [[[self undoManager] prepareWithInvocationTarget:self] setFlippedVertically:_flippedVertically];
        _flippedVertically = flag;
        [self SKT_clearCachedImage];
        [self didChange];
    }
}

- (BOOL)flippedVertically {
    return _flippedVertically;
}

- (void)flipHorizontally {
    [self setFlippedHorizontally:([self flippedHorizontally] ? NO : YES)];
}

- (void)flipVertically {
    [self setFlippedVertically:([self flippedVertically] ? NO : YES)];
}

- (void)setBounds:(NSRect)bounds {
    if (!NSEqualSizes([self bounds].size, bounds.size)) {
        [self SKT_clearCachedImage];
    }
    [super setBounds:bounds];
}

- (BOOL)drawsStroke {
    // Never draw stroke.
    return NO;
}

- (BOOL)canDrawStroke {
    // Never draw stroke.
    return NO;
}

- (void)drawInView:(SKTGraphicView *)view isSelected:(BOOL)flag {
    NSRect bounds = [self bounds];
    NSImage *image;
    
    if ([self drawsFill]) {
        [[self fillColor] set];
        NSRectFill(bounds);
    }
    image = [self transformedImage];
    if (image) {
        [image compositeToPoint:NSMakePoint(NSMinX(bounds), NSMaxY(bounds)) operation:NSCompositeSourceOver];
    }
    [super drawInView:view isSelected:flag];
}

- (void)makeNaturalSize {
    NSRect bounds = [self bounds];
    NSImage *image = [self image];
    NSSize requiredSize = (image ? [image size] : NSMakeSize(10.0, 10.0));

    bounds.size = requiredSize;
    [self setBounds:bounds];
    [self setFlippedHorizontally:NO];
    [self setFlippedVertically:NO];
}

NSString *SKTImageContentsKey = @"Image";
NSString *SKTFlippedHorizontallyKey = @"FlippedHorizontally";
NSString *SKTFlippedVerticallyKey = @"FlippedVertically";

- (NSMutableDictionary *)propertyListRepresentation {
    NSMutableDictionary *dict = [super propertyListRepresentation];
    [dict setObject:[NSArchiver archivedDataWithRootObject:[self image]] forKey:SKTImageContentsKey];
    [dict setObject:([self flippedHorizontally] ? @"YES" : @"NO") forKey:SKTFlippedHorizontallyKey];
    [dict setObject:([self flippedVertically] ? @"YES" : @"NO") forKey:SKTFlippedVerticallyKey];
    return dict;
}

- (void)loadPropertyListRepresentation:(NSDictionary *)dict {
    id obj;

    [super loadPropertyListRepresentation:dict];

    obj = [dict objectForKey:SKTImageContentsKey];
    if (obj) {
        [self setImage:[NSUnarchiver unarchiveObjectWithData:obj]];
    }
    obj = [dict objectForKey:SKTFlippedHorizontallyKey];
    if (obj) {
        [self setFlippedHorizontally:[obj isEqualToString:@"YES"]];
    }
    obj = [dict objectForKey:SKTFlippedVerticallyKey];
    if (obj) {
        [self setFlippedVertically:[obj isEqualToString:@"YES"]];
    }
    _cachedImage = nil;
}

- (void)setImageFile:(NSString *)filePath {
    NSImage *newImage;
    filePath = [filePath stringByStandardizingPath];
    filePath = [filePath stringByExpandingTildeInPath];
    newImage = [[NSImage allocWithZone:[self zone]] initWithContentsOfFile:filePath];
    if (newImage) {
        [self setImage:newImage];
        [newImage release];
    }
}

- (NSString *)imageFile {
    // This is really a "write-only" attribute used for setting the image for an SKTImage shape from a script.  We don't remember the path so the accessor just returns an empty string.
    return @"";
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
