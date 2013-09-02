// SKTDrawDocument.m
// Sketch Example
//

#import "SKTDrawDocument.h"
#import "SKTGraphic.h"
#import "SKTRenderingView.h"
#import "SKTRectangle.h"
#import "SKTCircle.h"
#import "SKTLine.h"
#import "SKTTextArea.h"
#import "SKTImage.h"

// Sketch establishes an NSError domain and some error codes. In a bigger app this stuff would of course be declared in a header. Also, in a bigger app the lookup of error description and failure reasons would probably be centralized somewhere instead of scattered all over the source code like in this file.
NSString *const SKTErrorDomain = @"SketchErrorDomain";
enum {
    SKTReadUnknownError = 1,
    SKTWriteCouldntMakeTIFFError = 2
};

NSString *SKTDrawDocumentType = @"Apple Sketch Graphic Format";

@implementation SKTDrawDocument

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"SKTDrawDocument"];
    
    ETPropertyDescription *graphicsProperty = [ETPropertyDescription descriptionWithName: @"graphics"
                                                                                      type: (id)@"SKTGraphic"];
    [graphicsProperty setMultivalued: YES];
    [graphicsProperty setOrdered: YES];
    [graphicsProperty setOpposite: (id)@"SKTGraphic.document"];
    [graphicsProperty setPersistent: YES];
    
    [entity setPropertyDescriptions: A(graphicsProperty)];
    
    return entity;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

@dynamic graphics;

static NSString *SKTGraphicsListKey = @"GraphicsList";
static NSString *SKTDrawDocumentVersionKey = @"DrawDocumentVersion";
static int SKTCurrentDrawDocumentVersion = 1;

- (NSDictionary *)drawDocumentDictionaryForGraphics:(NSArray *)graphics {
    NSMutableDictionary *doc = [NSMutableDictionary dictionary];
    unsigned i, c = [graphics count];
    NSMutableArray *graphicDicts = [NSMutableArray arrayWithCapacity:c];

    for (i=0; i<c; i++) {
        [graphicDicts addObject:[[graphics objectAtIndex:i] propertyListRepresentation]];
    }
    [doc setObject:graphicDicts forKey:SKTGraphicsListKey];
    [doc setObject:[NSString stringWithFormat:@"%d", SKTCurrentDrawDocumentVersion] forKey:SKTDrawDocumentVersionKey];
//    NSLog (@"printInfo: %@", [self printInfo]);
//    [doc setObject:[NSArchiver archivedDataWithRootObject:[self printInfo]] forKey:SKTPrintInfoKey];

    return doc;
}

- (NSData *)drawDocumentDataForGraphics:(NSArray *)graphics {
    NSDictionary *doc = [self drawDocumentDictionaryForGraphics:graphics];
    NSString *string = [doc description];
    return [string dataUsingEncoding:NSASCIIStringEncoding];
}

- (NSDictionary *)drawDocumentDictionaryFromData:(NSData *)data error:(NSError **)outError {

    // If property list parsing fails we have no choice but to admit that we don't know what went wrong. The error description returned by +[NSPropertyListSerialization propertyListFromData:mutabilityOption:format:errorDescription:] would be pretty technical, and not the sort of thing that we should show to a user.
    NSDictionary *properties = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:NULL];
    if (!properties && outError) {

	// An NSError has a bunch of parameters that determine how it's presented to the user. We just specify two of them here.
	NSDictionary *errorUserInfo = [NSDictionary dictionaryWithObjectsAndKeys:

	    // This localized description won't be presented to the user, except maybe by -[SKTGraphicView paste:]. It's a good idea to always provide a decent description that's a full sentence.
	    NSLocalizedStringFromTable(@"Sketch document data could not be read for an unknown reason.", @"ErrorStrings", @"Description of can't-read-Sketch error."), NSLocalizedDescriptionKey,

	    // This localized failure reason will be presented to the user if we're trying to open a document. NSDocumentController will take it and tack it onto the end of a "The document "so-and-so" could not be opened." message and use the whole thing as an error description. Full sentence!
	    NSLocalizedStringFromTable(@"An unknown error occured.", @"ErrorStrings", @"Reason for can't-read-Sketch error."), NSLocalizedFailureReasonErrorKey,
	    
	    nil];

	// In this simple example we know that no one's going to be paying attention to the domain and code that we use here, but don't just fill in junk here. Certainly don't just use NSCocoaErrorDomain and some random error code.
	*outError = [NSError errorWithDomain:SKTErrorDomain code:SKTReadUnknownError userInfo:errorUserInfo];

    }
    return properties;

}

- (NSArray *)graphicsFromDrawDocumentDictionary:(NSDictionary *)doc {
    NSArray *graphicDicts = [doc objectForKey:SKTGraphicsListKey];
    unsigned i, c = [graphicDicts count];
    NSMutableArray *graphics = [NSMutableArray arrayWithCapacity:c];

    for (i=0; i<c; i++) {
        [graphics addObject:[SKTGraphic graphicWithPropertyListRepresentation:[graphicDicts objectAtIndex:i]]];
    }

    return graphics;
}

- (NSRect)boundsForGraphics:(NSArray *)graphics {
    NSRect rect = NSZeroRect;
    unsigned i, c = [graphics count];
    for (i=0; i<c; i++) {
        if (i==0) {
            rect = [[graphics objectAtIndex:i] bounds];
        } else {
            rect = NSUnionRect(rect, [[graphics objectAtIndex:i] bounds]);
        }
    }
    return rect;
}

- (NSRect)drawingBoundsForGraphics:(NSArray *)graphics {
    NSRect rect = NSZeroRect;
    unsigned i, c = [graphics count];
    for (i=0; i<c; i++) {
        if (i==0) {
            rect = [[graphics objectAtIndex:i] drawingBounds];
        } else {
            rect = NSUnionRect(rect, [[graphics objectAtIndex:i] drawingBounds]);
        }
    }
    return rect;
}

- (NSSize)documentSize
{
	return [self drawingBoundsForGraphics: [self graphics]].size;
}

- (NSData *)TIFFRepresentationForGraphics:(NSArray *)graphics error:(NSError **)outError {

    // How big a of a TIFF are we going to make?
    NSData *tiffData;
    NSRect bounds = [self drawingBoundsForGraphics:graphics];
    if (!NSIsEmptyRect(bounds)) {

	// Create a new image and prepare to draw in it. Get the graphics context for it after we lock focus, not before.
	NSImage *image = [[NSImage alloc] initWithSize:bounds.size];
	[image setFlipped:YES];
	[image lockFocus];
	NSGraphicsContext *currentContext = [NSGraphicsContext currentContext];

	// We're not drawing a page image here, just the rectangle that contains the graphics being drawn, so make sure they get drawn in the right place.
	NSAffineTransform *transform = [NSAffineTransform transform];
	[transform translateXBy:(0.0f - bounds.origin.x) yBy:(0.0f - bounds.origin.y)];
	[transform concat];
	
	// Draw the graphics back to front.
	unsigned int graphicIndex = [graphics count];
	while (graphicIndex-->0) {

	    // The only reason a Sketch graphic knows what view it is drawing in is so that it can draw differently when being created or edited or selected. Specify a nil view to tell it to draw in the standard way.
	    SKTGraphic *graphic = [graphics objectAtIndex:graphicIndex];
	    [currentContext saveGraphicsState];
	    [NSBezierPath clipRect:[graphic drawingBounds]];
	    [graphic drawInView:nil isSelected:NO];
	    [currentContext restoreGraphicsState];

	}

	// We're done drawing.
	[image unlockFocus];
	tiffData = [image TIFFRepresentation];
	[image release];

    } else {

	// Regardless of what NSImage supports, Sketch doesn't support the creation of TIFFs that are 0 by 0 pixels. (We have to demonstrate a custom saving error somewhere, and this is an easy place to do it...)
	tiffData = nil;

	// Return an error that will be presented to the user by NSDocument if the user was attempting to save to a TIFF file. Notice that we're not allowed to assume that outError!=NULL.
	// There are lots of places to catch this situation earlier. For example, we could have overridden -writableTypesForSaveOperation: and made it not return NSTIFFPboardType, but then the user would have no idea why TIFF isn't showing up in the save panel's File Format popup. This way we can present a nice descriptive errror message.
	if (outError) {

	    // An NSError has a bunch of parameters that determine how it's presented to the user. We just specify two of them here.
	    NSDictionary *errorUserInfo = [NSDictionary dictionaryWithObjectsAndKeys:

		// This localized description won't be presented to the user. In code that's more reusable it might be though, so it's a good idea to always provide a decent one that's a full sentence.
		NSLocalizedStringFromTable(@"A TIFF image could not be made because it would be empty.", @"ErrorStrings", @"Description of can't-make-TIFF error."), NSLocalizedDescriptionKey,
		
		// This localized failure reason _will_ be presented to the user. NSDocument will take it and tack it onto the end of a "The document "so-and-so" could not be saved." message and use the whole thing as an error description. Full sentence!
		NSLocalizedStringFromTable(@"The TIFF image would be empty.", @"ErrorStrings", @"Reason for can't-make-TIFF error."), NSLocalizedFailureReasonErrorKey,

		nil];

	    // In this simple example we know that no one's going to be paying attention to the domain and code that we use here, but don't just fill in junk here. Certainly don't just use NSCocoaErrorDomain and some random error code.
	    *outError = [NSError errorWithDomain:SKTErrorDomain code:SKTWriteCouldntMakeTIFFError userInfo:errorUserInfo];

	}
    }
    return tiffData;

}

- (NSData *)PDFRepresentationForGraphics:(NSArray *)graphics {

    // Create a view that will be used just for making PDF.
    NSRect bounds = [self drawingBoundsForGraphics:graphics];
    SKTRenderingView *view = [[SKTRenderingView alloc] initWithFrame:bounds graphics:graphics];
    NSData *pdfData = [view dataWithPDFInsideRect:bounds];
    [view release];
    return pdfData;

}

// This method will only be invoked on Mac OS 10.4 and later. If you're writing an application that has to run on 10.3.x and earlier you should override -dataRepresentationOfType: instead.


- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {

    // This method must be prepared for typeName to be any value that might be in the array returned by any invocation of -writableTypesForSaveOperation:. Because this class:
    // doesn't - override -writableTypesForSaveOperation:, and
    // doesn't - override +writableTypes and +isNativeType: (which the default implementation of -writableTypesForSaveOperation: invokes),
    // and because:
    // - Sketch has a "Save a Copy As..." file menu item that results in NSSaveToOperations,
    // we know that that the type names we have to handle here include:
    // - SKTDrawDocumentType, because this application's Info.plist file declares that instances of this class can play the "editor" role for it, and
    // - NSPDFPboardType and NSTIFFPboardType, because according to the Info.plist an SKTDrawDocumentType document is exportable as them.
    // If we had reason to believe that -PDFRepresentationForGraphics or -drawDocumentDataForGraphics could return nil we would have to arrange for *outError to be set to a real value in that case. If you signal failure in a method that takes an error: parameter and outError!=NULL you must set *outError to something decent.
    NSData *data;
    NSArray *graphics = [self graphics];
    if ([typeName isEqualToString:NSPDFPboardType]) {
	data = [self PDFRepresentationForGraphics:graphics];
    } else if ([typeName isEqualToString:NSTIFFPboardType]) {
        data = [self TIFFRepresentationForGraphics:graphics error:outError];
    } else {
	NSParameterAssert([typeName isEqualToString:SKTDrawDocumentType]);
        data = [self drawDocumentDataForGraphics:graphics];
    }
    return data;

}

- (void)invalidateGraphic:(SKTGraphic *)graphic
{
	// FIXME: call invalidateGraphic: on the graphic view
}

- (void)insertGraphic:(SKTGraphic *)graphic atIndex:(unsigned)index {
    //[[[self undoManager] prepareWithInvocationTarget:self] removeGraphicAtIndex:index];
    
    NSMutableArray *array = [[self.graphics mutableCopy] autorelease];
    [array insertObject: graphic atIndex: index];

    self.graphics = array;
}

- (void)removeGraphicAtIndex:(unsigned)index {
    NSMutableArray *array = [[self.graphics mutableCopy] autorelease];
    [array removeObjectAtIndex: index];
    
    self.graphics = array;
}

- (void)removeGraphic:(SKTGraphic *)graphic {
    NSInteger index = [[self graphics] indexOfObjectIdenticalTo:graphic];
    if (index != NSNotFound) {
        [self removeGraphicAtIndex:index];
    }
}

- (void)moveGraphic:(SKTGraphic *)graphic toIndex:(unsigned)newIndex {
    unsigned curIndex = [[self graphics] indexOfObjectIdenticalTo:graphic];
    if (curIndex != newIndex) {
        if (curIndex < newIndex) {
            newIndex--;
        }
        
        [self removeGraphicAtIndex: curIndex];
        [self insertGraphic: graphic atIndex: newIndex];
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
