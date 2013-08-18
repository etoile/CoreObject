#import <Foundation/Foundation.h>

@class FMDatabase;

extern NSString * const kCOUndoStack;
extern NSString * const kCORedoStack;

/**
 * Simple persistent store of named pairs of stacks of NSDictionary (undo and redo stacks).
 * The NSDictionary's are property list representations of COEdit objects
 */
@interface COUndoStackStore : NSObject
{
    FMDatabase *_db;
}

- (NSSet *) stackNames;

- (BOOL) beginTransaction;
- (BOOL) commitTransaction;

- (NSArray *) stackContents: (NSString *)aTable forName: (NSString *)aStack;
- (void) clearStack: (NSString *)aTable forName: (NSString *)aStack;

- (void) popStack: (NSString *)aTable forName: (NSString *)aStack;
- (NSDictionary *) peekStack: (NSString *)aTable forName: (NSString *)aStack;
- (void) pushAction: (NSDictionary *)anAction stack: (NSString *)aTable forName: (NSString *)aStack;

@end
