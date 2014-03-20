/*
    Copyright (C) 2014 Eric Wasylishen
 
    Date:  February 2014
    License:  MIT  (see COPYING)
 */

#import "EWAppDelegate.h"
#import "EWDocument.h"
#import "EWUndoManager.h"
#import "EWTypewriterWindowController.h"
#import <EtoileFoundation/Macros.h>

#import <CoreObject/CoreObject.h>
#import <CoreObject/COEditingContext+Private.h>

@implementation EWDocument

@synthesize editingContext = ctx;
@synthesize libraryPersistentRoot = library;

#pragma mark - initialization

- (instancetype) initWithStoreURL: (NSURL *)aURL
{
	self = [super init];
	
    ctx = [COEditingContext contextWithURL: aURL];
	
	NSSet *libraryPersistentRoots = [[ctx persistentRoots] filteredSetUsingPredicate:
									 [NSPredicate predicateWithBlock: ^(id object, NSDictionary *bindings)
									  {
										  COPersistentRoot *persistentRoot = object;
										  return [[persistentRoot rootObject] isKindOfClass: [COLibrary class]];
									  }]];
	
	if ([libraryPersistentRoots count] == 0)
	{
		library = [ctx insertNewPersistentRootWithEntityName: @"COTagLibrary"];
		[ctx commit];
	}
	else if ([libraryPersistentRoots count] == 1)
	{
		library = [libraryPersistentRoots anyObject];
	}
	else
	{
		[NSException raise: NSGenericException format: @"Expected only a single library"];
	}
	
	NSLog(@"Library is %@", library);

	return self;
}

+ (NSURL *) defaultDocumentURL
{
	NSArray *libraryDirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
	
    NSString *dir = [[[libraryDirs objectAtIndex: 0]
                      stringByAppendingPathComponent: @"CoreObjectTypewriter"]
					 stringByAppendingPathComponent: @"Store.coreobjectstore"];
	
    [[NSFileManager defaultManager] createDirectoryAtPath: dir
                              withIntermediateDirectories: YES
                                               attributes: nil
                                                    error: NULL];
	
	return [NSURL fileURLWithPath: dir isDirectory: YES];
}

- (id)init
{
    return [self initWithStoreURL: [[self class] defaultDocumentURL]];
}

#pragma mark - NSDocument overrides

- (void)makeWindowControllers
{
    EWTypewriterWindowController *windowController = [[EWTypewriterWindowController alloc] initWithWindowNibName: [self windowNibName]];
    [self addWindowController: windowController];
}

- (NSString *)windowNibName
{
    return @"Document";
}

#pragma mark - NSDocument data writing

- (NSData *) dataOfType: (NSString *)typeName error: (NSError **)outError
{
	if ([typeName isEqualToString: @"public.html"])
	{
		EWTypewriterWindowController *windowController = [[NSApp mainWindow] windowController];
		if (![windowController isKindOfClass: [EWTypewriterWindowController class]])
			return nil;
		
		COAttributedStringWrapper *ts = windowController.textStorage;
		
		NSDictionary *dict = @{ NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType };
		NSData *data = [ts dataFromRange: NSMakeRange(0, [ts length]) documentAttributes: dict error: outError];

		if (data == nil
			&& outError != NULL)
		{
			*outError = [NSError errorWithDomain: NSCocoaErrorDomain
											code: NSFileWriteUnknownError
										userInfo: nil];
		}
		return data;
	}
	else
	{
		[NSException raise: NSGenericException format: @"Unsupported writing type %@", typeName];
		return nil;
	}
}

@end
