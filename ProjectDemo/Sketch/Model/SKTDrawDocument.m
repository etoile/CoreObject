// SKTDrawDocument.m
// Sketch Example
//

#import "SKTDrawDocument.h"
#import "SKTDrawWindowController.h"
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

- (id)init {
    self = [super init];
    if (self) {
        _graphics = [[NSMutableArray allocWithZone:[self zone]] init];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_graphics release];
    
    [super dealloc];
}

- (void)makeWindowControllers {
    SKTDrawWindowController *myController = [[SKTDrawWindowController allocWithZone:[self zone]] init];
    [self addWindowController:myController];
    [myController release];
}

static NSString *SKTGraphicsListKey = @"GraphicsList";
static NSString *SKTDrawDocumentVersionKey = @"DrawDocumentVersion";
static int SKTCurrentDrawDocumentVersion = 1;
static NSString *SKTPrintInfoKey = @"PrintInfo";


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

- (NSData *)dataRepresentationOfType: (NSString*) typeName
{
	return [self dataOfType: typeName error: NULL];
}

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

// This method will only be invoked on Mac 10.4 and later. If you're writing an application that has to run on 10.3.x and earlier you should override -loadDataRepresentation:ofType: instead.
//
- (BOOL) loadDataRepresentation: (NSData*) data ofType: (NSString*) typeName
{
	return [self readFromData: data ofType: typeName error: NULL];
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {

    // This application's Info.plist only declares one document type, SKTDrawDocumentType, for which it can play the "editor" role, and none for which it can play the "viewer" role, so the type better be SKTDrawDocumentType.
    NSParameterAssert([typeName isEqualToString:SKTDrawDocumentType]);

    // Read in the property list.
    NSDictionary *properties = [self drawDocumentDictionaryFromData:data error:outError];
    if (properties) {

	// Get the graphics and set them. Strictly speaking the property list of an empty document should have an empty graphics array, not no graphics array, but we cope easily with either. It wouldn't be good practice to invoke [self setGraphics:nil] though (passing or returning nil collection pointers rarely is).
	NSArray *graphics = [self graphicsFromDrawDocumentDictionary:properties];
	if (!graphics) {
	    graphics = [NSArray array];
	}
        [self setGraphics:graphics];
	
	// There's no point in considering the opening of the document to have failed" if we can't get print info. A more finished app might present a panel warning the user that something's fishy though.
	NSData *printInfoData = [properties objectForKey:SKTPrintInfoKey];
	if (printInfoData) {
            NSPrintInfo *printInfo = [NSUnarchiver unarchiveObjectWithData:printInfoData];
            if (printInfo) {
                [self setPrintInfo:printInfo];

		// -[NSDocument setPrintInfo:] registered an undo action, but that wasn't appropriate in this case.
		[[self undoManager] removeAllActions];

            }
	}

    } // else it was -drawDocumentDictionaryFromData:error:'s responsibility to set *outError to something good.
    return properties ? YES : NO;

}

- (NSSize)documentSize {
    NSPrintInfo *printInfo = [self printInfo];
    NSSize paperSize = [printInfo paperSize];
    paperSize.width -= ([printInfo leftMargin] + [printInfo rightMargin]);
    paperSize.height -= ([printInfo topMargin] + [printInfo bottomMargin]);
    return paperSize;
}

// This method will only be invoked on Mac 10.4 and later. If you're writing an application that has to run on 10.3.x and earlier you should override -printShowingPrintPanel: instead.
- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings error:(NSError **)outError {
    
    // Create a view that will be used just for printing.
    NSSize documentSize = [self documentSize];
    SKTRenderingView *renderingView = [[SKTRenderingView alloc] initWithFrame:NSMakeRect(0.0, 0.0, documentSize.width, documentSize.height) graphics:[self graphics]];
    
    // Create a print operation.
    NSPrintOperation *printOperation = [NSPrintOperation printOperationWithView:renderingView printInfo:[self printInfo]];
    [renderingView release];
    
    // Specify that the print operation can run in a separate thread. This will cause the print progress panel to appear as a sheet on the document window.
    [printOperation setCanSpawnSeparateThread:YES];
    
    // Set any print settings that might have been specified in a Print Document Apple event. We do it this way because we shouldn't be mutating the result of [self printInfo] here, and using the result of [printOperation printInfo], a copy of the original print info, means we don't have to make yet another temporary copy of [self printInfo].
    [[[printOperation printInfo] dictionary] addEntriesFromDictionary:printSettings];
    
    // We don't have to autorelease the print operation because +[NSPrintOperation printOperationWithView:printInfo:] of course already autoreleased it. Nothing in this method can fail, so we never return nil, so we don't have to worry about setting *outError.
    return printOperation;
    
}

- (void)setPrintInfo:(NSPrintInfo *)printInfo {
    
    // Do the regular Cocoa thing...
    [super setPrintInfo:printInfo];

    // ...and then make sure that all of the graphic views know the new document size, if it changed.
    [[self windowControllers] makeObjectsPerformSelector:@selector(setUpGraphicView)];

}

- (NSArray *)graphics {
    return _graphics;
}

- (void)setGraphics:(NSArray *)graphics {
    unsigned i = [_graphics count];
    while (i-- > 0) {
        [self removeGraphicAtIndex:i];
    }
    i = [graphics count];
    while (i-- > 0) {
        [self insertGraphic:[graphics objectAtIndex:i] atIndex:0];
    }
}

- (void)invalidateGraphic:(SKTGraphic *)graphic {
    NSArray *windowControllers = [self windowControllers];

    [windowControllers makeObjectsPerformSelector:@selector(invalidateGraphic:) withObject:graphic];
}

- (void)insertGraphic:(SKTGraphic *)graphic atIndex:(unsigned)index {
    [[[self undoManager] prepareWithInvocationTarget:self] removeGraphicAtIndex:index];
    [_graphics insertObject:graphic atIndex:index];
    [graphic setDocument:self];
    [self invalidateGraphic:graphic];
}

- (void)removeGraphicAtIndex:(unsigned)index {
    id graphic = [[_graphics objectAtIndex:index] retain];
    [_graphics removeObjectAtIndex:index];
    [self invalidateGraphic:graphic];
    [[[self undoManager] prepareWithInvocationTarget:self] insertGraphic:graphic atIndex:index];
    [graphic release];
}

- (void)removeGraphic:(SKTGraphic *)graphic {
    unsigned index = [_graphics indexOfObjectIdenticalTo:graphic];
    if (index != NSNotFound) {
        [self removeGraphicAtIndex:index];
    }
}

- (void)moveGraphic:(SKTGraphic *)graphic toIndex:(unsigned)newIndex {
    unsigned curIndex = [_graphics indexOfObjectIdenticalTo:graphic];
    if (curIndex != newIndex) {
        [[[self undoManager] prepareWithInvocationTarget:self] moveGraphic:graphic toIndex:((curIndex > newIndex) ? curIndex+1 : curIndex)];
        if (curIndex < newIndex) {
            newIndex--;
        }
        [graphic retain];
        [_graphics removeObjectAtIndex:curIndex];
        [_graphics insertObject:graphic atIndex:newIndex];
        [graphic release];
        [self invalidateGraphic:graphic];
    }
}

@end

@implementation SKTDrawDocument (SKTScriptingExtras)

// These are methods that we probably wouldn't bother with if we weren't scriptable.

// graphics and setGraphics: are already implemented above.

- (void)addInGraphics:(SKTGraphic *)graphic {
    [self insertGraphic:graphic atIndex:[[self graphics] count]];
}

- (void)insertInGraphics:(SKTGraphic *)graphic atIndex:(unsigned)index {
    [self insertGraphic:graphic atIndex:index];
}

- (void)removeFromGraphicsAtIndex:(unsigned)index {
    [self removeGraphicAtIndex:index];
}

- (void)replaceInGraphics:(SKTGraphic *)graphic atIndex:(unsigned)index {
    [self removeGraphicAtIndex:index];
    [self insertGraphic:graphic atIndex:index];
}

- (NSArray *)graphicsWithClass:(Class)theClass {
    NSArray *graphics = [self graphics];
    NSMutableArray *result = [NSMutableArray array];
    unsigned i, c = [graphics count];
    id curGraphic;

    for (i=0; i<c; i++) {
        curGraphic = [graphics objectAtIndex:i];
        if ([curGraphic isKindOfClass:theClass]) {
            [result addObject:curGraphic];
        }
    }
    return result;
}

- (NSArray *)rectangles {
    return [self graphicsWithClass:[SKTRectangle class]];
}

- (NSArray *)circles {
    return [self graphicsWithClass:[SKTCircle class]];
}

- (NSArray *)lines {
    return [self graphicsWithClass:[SKTLine class]];
}

- (NSArray *)textAreas {
    return [self graphicsWithClass:[SKTTextArea class]];
}

- (NSArray *)images {
    return [self graphicsWithClass:[SKTImage class]];
}

- (void)setRectangles:(NSArray *)rects {
    // We won't allow wholesale setting of these subset keys.
    [NSException raise: @"NSOperationNotSupportedForKeyException" format:@"Setting 'rectangles' key is not supported."];
}

- (void)addInRectangles:(SKTGraphic *)graphic {
    [self addInGraphics:graphic];
}

- (void)insertInRectangles:(SKTGraphic *)graphic atIndex:(unsigned)index {
    // MF:!!! This is not going to be ideal.  If we are being asked to, say, "make a new rectangle at after rectangle 2", we will be after rectangle 2, but we may be after some other stuff as well since we will be asked to insertInRectangles:atIndex:3...
    NSArray *rects = [self rectangles];
    if (index == [rects count]) {
        [self addInGraphics:graphic];
    } else {
        NSArray *graphics = [self graphics];
        int newIndex = [graphics indexOfObjectIdenticalTo:[rects objectAtIndex:index]];
        if (newIndex != NSNotFound) {
            [self insertGraphic:graphic atIndex:newIndex];
        } else {
            // Shouldn't happen.
            [NSException raise:NSRangeException format:@"Could not find the given rectangle in the graphics."];
        }
    }
}

- (void)removeFromRectanglesAtIndex:(unsigned)index {
    NSArray *rects = [self rectangles];
    NSArray *graphics = [self graphics];
    int newIndex = [graphics indexOfObjectIdenticalTo:[rects objectAtIndex:index]];
    if (newIndex != NSNotFound) {
        [self removeGraphicAtIndex:newIndex];
    } else {
        // Shouldn't happen.
        [NSException raise:NSRangeException format:@"Could not find the given rectangle in the graphics."];
    }
}

- (void)replaceInRectangles:(SKTGraphic *)graphic atIndex:(unsigned)index {
    NSArray *rects = [self rectangles];
    NSArray *graphics = [self graphics];
    int newIndex = [graphics indexOfObjectIdenticalTo:[rects objectAtIndex:index]];
    if (newIndex != NSNotFound) {
        [self removeGraphicAtIndex:newIndex];
        [self insertGraphic:graphic atIndex:newIndex];
    } else {
        // Shouldn't happen.
        [NSException raise:NSRangeException format:@"Could not find the given rectangle in the graphics."];
    }
}

- (void)setCircles:(NSArray *)circles {
    // We won't allow wholesale setting of these subset keys.
    [NSException raise: @"NSOperationNotSupportedForKeyException" format:@"Setting 'circles' key is not supported."];
}

- (void)addInCircles:(SKTGraphic *)graphic {
    [self addInGraphics:graphic];
}

- (void)insertInCircles:(SKTGraphic *)graphic atIndex:(unsigned)index {
    // MF:!!! This is not going to be ideal.  If we are being asked to, say, "make a new rectangle at after rectangle 2", we will be after rectangle 2, but we may be after some other stuff as well since we will be asked to insertInCircles:atIndex:3...
    NSArray *circles = [self circles];
    if (index == [circles count]) {
        [self addInGraphics:graphic];
    } else {
        NSArray *graphics = [self graphics];
        int newIndex = [graphics indexOfObjectIdenticalTo:[circles objectAtIndex:index]];
        if (newIndex != NSNotFound) {
            [self insertGraphic:graphic atIndex:newIndex];
        } else {
            // Shouldn't happen.
            [NSException raise:NSRangeException format:@"Could not find the given circle in the graphics."];
        }
    }
}

- (void)removeFromCirclesAtIndex:(unsigned)index {
    NSArray *circles = [self circles];
    NSArray *graphics = [self graphics];
    int newIndex = [graphics indexOfObjectIdenticalTo:[circles objectAtIndex:index]];
    if (newIndex != NSNotFound) {
        [self removeGraphicAtIndex:newIndex];
    } else {
        // Shouldn't happen.
        [NSException raise:NSRangeException format:@"Could not find the given circle in the graphics."];
    }
}

- (void)replaceInCircles:(SKTGraphic *)graphic atIndex:(unsigned)index {
    NSArray *circles = [self circles];
    NSArray *graphics = [self graphics];
    int newIndex = [graphics indexOfObjectIdenticalTo:[circles objectAtIndex:index]];
    if (newIndex != NSNotFound) {
        [self removeGraphicAtIndex:newIndex];
        [self insertGraphic:graphic atIndex:newIndex];
    } else {
        // Shouldn't happen.
        [NSException raise:NSRangeException format:@"Could not find the given circle in the graphics."];
    }
}

- (void)setLines:(NSArray *)lines {
    // We won't allow wholesale setting of these subset keys.
    [NSException raise: @"NSOperationNotSupportedForKeyException" format:@"Setting 'lines' key is not supported."];
}

- (void)addInLines:(SKTGraphic *)graphic {
    [self addInGraphics:graphic];
}

- (void)insertInLines:(SKTGraphic *)graphic atIndex:(unsigned)index {
    // MF:!!! This is not going to be ideal.  If we are being asked to, say, "make a new rectangle at after rectangle 2", we will be after rectangle 2, but we may be after some other stuff as well since we will be asked to insertInLines:atIndex:3...
    NSArray *lines = [self lines];
    if (index == [lines count]) {
        [self addInGraphics:graphic];
    } else {
        NSArray *graphics = [self graphics];
        int newIndex = [graphics indexOfObjectIdenticalTo:[lines objectAtIndex:index]];
        if (newIndex != NSNotFound) {
            [self insertGraphic:graphic atIndex:newIndex];
        } else {
            // Shouldn't happen.
            [NSException raise:NSRangeException format:@"Could not find the given line in the graphics."];
        }
    }
}

- (void)removeFromLinesAtIndex:(unsigned)index {
    NSArray *lines = [self lines];
    NSArray *graphics = [self graphics];
    int newIndex = [graphics indexOfObjectIdenticalTo:[lines objectAtIndex:index]];
    if (newIndex != NSNotFound) {
        [self removeGraphicAtIndex:newIndex];
    } else {
        // Shouldn't happen.
        [NSException raise:NSRangeException format:@"Could not find the given line in the graphics."];
    }
}

- (void)replaceInLines:(SKTGraphic *)graphic atIndex:(unsigned)index {
    NSArray *lines = [self lines];
    NSArray *graphics = [self graphics];
    int newIndex = [graphics indexOfObjectIdenticalTo:[lines objectAtIndex:index]];
    if (newIndex != NSNotFound) {
        [self removeGraphicAtIndex:newIndex];
        [self insertGraphic:graphic atIndex:newIndex];
    } else {
        // Shouldn't happen.
        [NSException raise:NSRangeException format:@"Could not find the given line in the graphics."];
    }
}

- (void)setTextAreas:(NSArray *)textAreas {
    // We won't allow wholesale setting of these subset keys.
    [NSException raise: @"NSOperationNotSupportedForKeyException" format:@"Setting 'textAreas' key is not supported."];
}

- (void)addInTextAreas:(SKTGraphic *)graphic {
    [self addInGraphics:graphic];
}

- (void)insertInTextAreas:(SKTGraphic *)graphic atIndex:(unsigned)index {
    // MF:!!! This is not going to be ideal.  If we are being asked to, say, "make a new rectangle at after rectangle 2", we will be after rectangle 2, but we may be after some other stuff as well since we will be asked to insertInTextAreas:atIndex:3...
    NSArray *textAreas = [self textAreas];
    if (index == [textAreas count]) {
        [self addInGraphics:graphic];
    } else {
        NSArray *graphics = [self graphics];
        int newIndex = [graphics indexOfObjectIdenticalTo:[textAreas objectAtIndex:index]];
        if (newIndex != NSNotFound) {
            [self insertGraphic:graphic atIndex:newIndex];
        } else {
            // Shouldn't happen.
            [NSException raise:NSRangeException format:@"Could not find the given text area in the graphics."];
        }
    }
}

- (void)removeFromTextAreasAtIndex:(unsigned)index {
    NSArray *textAreas = [self textAreas];
    NSArray *graphics = [self graphics];
    int newIndex = [graphics indexOfObjectIdenticalTo:[textAreas objectAtIndex:index]];
    if (newIndex != NSNotFound) {
        [self removeGraphicAtIndex:newIndex];
    } else {
        // Shouldn't happen.
        [NSException raise:NSRangeException format:@"Could not find the given text area in the graphics."];
    }
}

- (void)replaceInTextAreas:(SKTGraphic *)graphic atIndex:(unsigned)index {
    NSArray *textAreas = [self textAreas];
    NSArray *graphics = [self graphics];
    int newIndex = [graphics indexOfObjectIdenticalTo:[textAreas objectAtIndex:index]];
    if (newIndex != NSNotFound) {
        [self removeGraphicAtIndex:newIndex];
        [self insertGraphic:graphic atIndex:newIndex];
    } else {
        // Shouldn't happen.
        [NSException raise:NSRangeException format:@"Could not find the given text area in the graphics."];
    }
}

- (void)setImages:(NSArray *)images {
    // We won't allow wholesale setting of these subset keys.
    [NSException raise: @"NSOperationNotSupportedForKeyException" format:@"Setting 'images' key is not supported."];
}

- (void)addInImages:(SKTGraphic *)graphic {
    [self addInGraphics:graphic];
}

- (void)insertInImages:(SKTGraphic *)graphic atIndex:(unsigned)index {
    // MF:!!! This is not going to be ideal.  If we are being asked to, say, "make a new rectangle at after rectangle 2", we will be after rectangle 2, but we may be after some other stuff as well since we will be asked to insertInImages:atIndex:3...
    NSArray *images = [self images];
    if (index == [images count]) {
        [self addInGraphics:graphic];
    } else {
        NSArray *graphics = [self graphics];
        int newIndex = [graphics indexOfObjectIdenticalTo:[images objectAtIndex:index]];
        if (newIndex != NSNotFound) {
            [self insertGraphic:graphic atIndex:newIndex];
        } else {
            // Shouldn't happen.
            [NSException raise:NSRangeException format:@"Could not find the given image in the graphics."];
        }
    }
}

- (void)removeFromImagesAtIndex:(unsigned)index {
    NSArray *images = [self images];
    NSArray *graphics = [self graphics];
    int newIndex = [graphics indexOfObjectIdenticalTo:[images objectAtIndex:index]];
    if (newIndex != NSNotFound) {
        [self removeGraphicAtIndex:newIndex];
    } else {
        // Shouldn't happen.
        [NSException raise:NSRangeException format:@"Could not find the given image in the graphics."];
    }
}

- (void)replaceInImages:(SKTGraphic *)graphic atIndex:(unsigned)index {
    NSArray *images = [self images];
    NSArray *graphics = [self graphics];
    int newIndex = [graphics indexOfObjectIdenticalTo:[images objectAtIndex:index]];
    if (newIndex != NSNotFound) {
        [self removeGraphicAtIndex:newIndex];
        [self insertGraphic:graphic atIndex:newIndex];
    } else {
        // Shouldn't happen.
        [NSException raise:NSRangeException format:@"Could not find the given image in the graphics."];
    }
}

// The following "indicesOf..." methods are in support of scripting.  They allow more flexible range and relative specifiers to be used with the different graphic keys of a SKTDrawDocument.
// The scripting engine does not know about the fact that the "rectangles" key is really just a subset of the "graphics" key, so script code like "rectangles from circle 1 to line 4" don't make sense to it.  But Sketch does know and can answer such questions itself, with a little work.
/*
- (NSArray *)indicesOfObjectsByEvaluatingRangeSpecifier:(NSRangeSpecifier *)rangeSpec {
    NSString *key = [rangeSpec key];

    if ([key isEqual:@"graphics"] || [key isEqual:@"rectangles"] || [key isEqual:@"circles"] || [key isEqual:@"lines"] || [key isEqual:@"textAreas"] || [key isEqual:@"images"]) {
        // This is one of the keys we might want to deal with.
        NSScriptObjectSpecifier *startSpec = [rangeSpec startSpecifier];
        NSScriptObjectSpecifier *endSpec = [rangeSpec endSpecifier];
        NSString *startKey = [startSpec key];
        NSString *endKey = [endSpec key];
        NSArray *graphics = [self graphics];

        if ((startSpec == nil) && (endSpec == nil)) {
            // We need to have at least one of these...
            return nil;
        }
        if ([graphics count] == 0) {
            // If there are no graphics, there can be no match.  Just return now.
            return [NSArray array];
        }

        if ((!startSpec || [startKey isEqual:@"graphics"] || [startKey isEqual:@"rectangles"] || [startKey isEqual:@"circles"] || [startKey isEqual:@"lines"] || [startKey isEqual:@"textAreas"] || [startKey isEqual:@"images"]) && (!endSpec || [endKey isEqual:@"graphics"] || [endKey isEqual:@"rectangles"] || [endKey isEqual:@"circles"] || [endKey isEqual:@"lines"] || [endKey isEqual:@"textAreas"] || [endKey isEqual:@"images"])) {
            int startIndex;
            int endIndex;

            // The start and end keys are also ones we want to handle.

            // The strategy here is going to be to find the index of the start and stop object in the full graphics array, regardless of what its key is.  Then we can find what we're looking for in that range of the graphics key (weeding out objects we don't want, if necessary).

            // First find the index of the first start object in the graphics array
            if (startSpec) {
                id startObject = [startSpec objectsByEvaluatingSpecifier];
                if ([startObject isKindOfClass:[NSArray class]]) {
                    if ([startObject count] == 0) {
                        startObject = nil;
                    } else {
                        startObject = [startObject objectAtIndex:0];
                    }
                }
                if (!startObject) {
                    // Oops.  We could not find the start object.
                    return nil;
                }
                startIndex = [graphics indexOfObjectIdenticalTo:startObject];
                if (startIndex == NSNotFound) {
                    // Oops.  We couldn't find the start object in the graphics array.  This should not happen.
                    return nil;
                }
            } else {
                startIndex = 0;
            }

            // Now find the index of the last end object in the graphics array
            if (endSpec) {
                id endObject = [endSpec objectsByEvaluatingSpecifier];
                if ([endObject isKindOfClass:[NSArray class]]) {
                    unsigned endObjectsCount = [endObject count];
                    if (endObjectsCount == 0) {
                        endObject = nil;
                    } else {
                        endObject = [endObject objectAtIndex:(endObjectsCount-1)];
                    }
                }
                if (!endObject) {
                    // Oops.  We could not find the end object.
                    return nil;
                }
                endIndex = [graphics indexOfObjectIdenticalTo:endObject];
                if (endIndex == NSNotFound) {
                    // Oops.  We couldn't find the end object in the graphics array.  This should not happen.
                    return nil;
                }
            } else {
                endIndex = [graphics count] - 1;
            }

            if (endIndex < startIndex) {
                // Accept backwards ranges gracefully
                int temp = endIndex;
                endIndex = startIndex;
                startIndex = temp;
            }

            {
                // Now startIndex and endIndex specify the end points of the range we want within the graphics array.
                // We will traverse the range and pick the objects we want.
                // We do this by getting each object and seeing if it actually appears in the real key that we are trying to evaluate in.
                NSMutableArray *result = [NSMutableArray array];
                BOOL keyIsGraphics = [key isEqual:@"graphics"];
                NSArray *rangeKeyObjects = (keyIsGraphics ? nil : [self valueForKey:key]);
                id curObj;
                unsigned curKeyIndex, i;

                for (i=startIndex; i<=endIndex; i++) {
                    if (keyIsGraphics) {
                        [result addObject:[NSNumber numberWithInt:i]];
                    } else {
                        curObj = [graphics objectAtIndex:i];
                        curKeyIndex = [rangeKeyObjects indexOfObjectIdenticalTo:curObj];
                        if (curKeyIndex != NSNotFound) {
                            [result addObject:[NSNumber numberWithInt:curKeyIndex]];
                        }
                    }
                }
                return result;
            }
        }
    }
    return nil;
}

- (NSArray *)indicesOfObjectsByEvaluatingRelativeSpecifier:(NSRelativeSpecifier *)relSpec {
    NSString *key = [relSpec key];

    if ([key isEqual:@"graphics"] || [key isEqual:@"rectangles"] || [key isEqual:@"circles"] || [key isEqual:@"lines"] || [key isEqual:@"textAreas"] || [key isEqual:@"images"]) {
        // This is one of the keys we might want to deal with.
        NSScriptObjectSpecifier *baseSpec = [relSpec baseSpecifier];
        NSString *baseKey = [baseSpec key];
        NSArray *graphics = [self graphics];
        NSRelativePosition relPos = [relSpec relativePosition];

        if (baseSpec == nil) {
            // We need to have one of these...
            return nil;
        }
        if ([graphics count] == 0) {
            // If there are no graphics, there can be no match.  Just return now.
            return [NSArray array];
        }

        if ([baseKey isEqual:@"graphics"] || [baseKey isEqual:@"rectangles"] || [baseKey isEqual:@"circles"] || [baseKey isEqual:@"lines"] || [baseKey isEqual:@"textAreas"] || [baseKey isEqual:@"images"]) {
            int baseIndex;

            // The base key is also one we want to handle.

            // The strategy here is going to be to find the index of the base object in the full graphics array, regardless of what its key is.  Then we can find what we're looking for before or after it.

            // First find the index of the first or last base object in the graphics array
            // Base specifiers are to be evaluated within the same container as the relative specifier they are the base of.  That's this document.
            id baseObject = [baseSpec objectsByEvaluatingWithContainers:self];
            if ([baseObject isKindOfClass:[NSArray class]]) {
                int baseCount = [baseObject count];
                if (baseCount == 0) {
                    baseObject = nil;
                } else {
                    if (relPos == NSRelativeBefore) {
                        baseObject = [baseObject objectAtIndex:0];
                    } else {
                        baseObject = [baseObject objectAtIndex:(baseCount-1)];
                    }
                }
            }
            if (!baseObject) {
                // Oops.  We could not find the base object.
                return nil;
            }

            baseIndex = [graphics indexOfObjectIdenticalTo:baseObject];
            if (baseIndex == NSNotFound) {
                // Oops.  We couldn't find the base object in the graphics array.  This should not happen.
                return nil;
            }

            {
                // Now baseIndex specifies the base object for the relative spec in the graphics array.
                // We will start either right before or right after and look for an object that matches the type we want.
                // We do this by getting each object and seeing if it actually appears in the real key that we are trying to evaluate in.
                NSMutableArray *result = [NSMutableArray array];
                BOOL keyIsGraphics = [key isEqual:@"graphics"];
                NSArray *relKeyObjects = (keyIsGraphics ? nil : [self valueForKey:key]);
                id curObj;
                unsigned curKeyIndex, graphicCount = [graphics count];

                if (relPos == NSRelativeBefore) {
                    baseIndex--;
                } else {
                    baseIndex++;
                }
                while ((baseIndex >= 0) && (baseIndex < graphicCount)) {
                    if (keyIsGraphics) {
                        [result addObject:[NSNumber numberWithInt:baseIndex]];
                        break;
                    } else {
                        curObj = [graphics objectAtIndex:baseIndex];
                        curKeyIndex = [relKeyObjects indexOfObjectIdenticalTo:curObj];
                        if (curKeyIndex != NSNotFound) {
                            [result addObject:[NSNumber numberWithInt:curKeyIndex]];
                            break;
                        }
                    }
                    if (relPos == NSRelativeBefore) {
                        baseIndex--;
                    } else {
                        baseIndex++;
                    }
                }

                return result;
            }
        }
    }
    return nil;
}
    
- (NSArray *)indicesOfObjectsByEvaluatingObjectSpecifier:(NSScriptObjectSpecifier *)specifier {
    // We want to handle some range and relative specifiers ourselves in order to support such things as "graphics from circle 3 to circle 5" or "circles from graphic 1 to graphic 10" or "circle before rectangle 3".
    // Returning nil from this method will cause the specifier to try to evaluate itself using its default evaluation strategy.
	
    if ([specifier isKindOfClass:[NSRangeSpecifier class]]) {
        return [self indicesOfObjectsByEvaluatingRangeSpecifier:(NSRangeSpecifier *)specifier];
    } else if ([specifier isKindOfClass:[NSRelativeSpecifier class]]) {
        return [self indicesOfObjectsByEvaluatingRelativeSpecifier:(NSRelativeSpecifier *)specifier];
    }


    // If we didn't handle it, return nil so that the default object specifier evaluation will do it.
    return nil;
}

*/
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
