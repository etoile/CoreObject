#import "COUndoStackStore.h"
#import "COUndoStack.h"
#import <EtoileFoundation/EtoileFoundation.h>
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "COPatternUndoStack.h"

NSString * const kCOUndoStack = @"undo";
NSString * const kCORedoStack = @"redo";

@interface COUndoStack ()

- (id) initWithStore: (COUndoStackStore *)aStore name: (NSString *)aName;

@end

@implementation COUndoStackStore

+ (COUndoStackStore *) defaultStore
{
    static COUndoStackStore *store;
    if (store == nil)
    {
        store = [[COUndoStackStore alloc] init];
    }
    return store;
}

- (COUndoStack *) stackForName: (NSString *)aName
{
    return [[COUndoStack alloc] initWithStore: self name: aName];
}

- (COUndoStack *) stackForPattern: (NSString *)aPattern
{
    return [[COPatternUndoStack alloc] initWithStore: self name: aPattern];
}

- (id) init
{
    SUPERINIT;
    
    NSArray *libraryDirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);

    NSString *dir = [[[libraryDirs objectAtIndex: 0]
                      stringByAppendingPathComponent: @"CoreObject"]
                        stringByAppendingPathComponent: @"Undo"];

    [[NSFileManager defaultManager] createDirectoryAtPath: dir
                              withIntermediateDirectories: YES
                                               attributes: nil
                                                    error: nil];
        
    _db = [[FMDatabase alloc] initWithPath: [dir stringByAppendingPathComponent: @"undo.sqlite"]];
    [_db setShouldCacheStatements: YES];
    assert([_db open]);
    
    // Use write-ahead-log mode
    {
        NSString *result = [_db stringForQuery: @"PRAGMA journal_mode=WAL"];
        
        if (![@"wal" isEqualToString: result])
        {
            NSLog(@"Enabling WAL mode failed.");
        }
    }

    [_db executeUpdate: @"CREATE TABLE IF NOT EXISTS undo (idx INTEGER PRIMARY KEY ASC, name STRING, data BLOB)"];
    [_db executeUpdate: @"CREATE TABLE IF NOT EXISTS redo (idx INTEGER PRIMARY KEY ASC, name STRING, data BLOB)"];
    
    return self;
}

- (void) dealloc
{
    [_db close];
}

- (NSSet *) stackNames
{
    NSMutableSet *result = [NSMutableSet set];
    FMResultSet *rs = [_db executeQuery: @"SELECT DISTINCT name FROM undo"];
    while ([rs next])
    {
        [result addObject: [rs stringForColumnIndex: 0]];
    }
    [rs close];
    return result;
}

- (NSArray *) stackContents: (NSString *)aTable forName: (NSString *)aStack
{
    FMResultSet *rs = [_db executeQuery: [NSString stringWithFormat: @"SELECT data FROM %@ WHERE name LIKE ?", aTable], aStack];
    NSMutableArray *result = [NSMutableArray array];
    while ([rs next])
    {
        id obj = [NSJSONSerialization JSONObjectWithData: [rs dataForColumnIndex: 0] options: 0 error: NULL];
        [result addObject: obj];
    }
    [rs close];
    return result;
}

- (BOOL) beginTransaction
{
    return [_db beginTransaction];
}

- (BOOL) commitTransaction
{
    return [_db commit];
}

- (void) clearStack: (NSString *)aTable forName: (NSString *)aStack
{
    [_db executeUpdate: [NSString stringWithFormat: @"DELETE FROM %@ WHERE name LIKE ?", aTable], aStack];
}

- (void) clearStacksForName: (NSString *)aStack
{
    [self clearStack: kCOUndoStack forName: aStack];
    [self clearStack: kCORedoStack forName: aStack];
}

- (void) popStack: (NSString *)aTable forName: (NSString *)aStack
{
    [_db executeUpdate: [NSString stringWithFormat: @"DELETE FROM %@ WHERE idx = (SELECT MAX(idx) FROM %@ WHERE name LIKE ?)", aTable, aTable], aStack];
}

- (NSDictionary *) peekStack: (NSString *)aTable forName: (NSString *)aStack
{
    NSData *data = [_db dataForQuery: [NSString stringWithFormat: @"SELECT data FROM %@ WHERE idx = (SELECT MAX(idx) FROM %@ WHERE name LIKE ?)", aTable, aTable], aStack];
    if (data == nil)
    {
        return nil;
    }
    return [NSJSONSerialization JSONObjectWithData: data options: 0 error: NULL];
}

- (NSString *) peekStackName: (NSString *)aTable forName: (NSString *)aStack
{
    return [_db stringForQuery: [NSString stringWithFormat: @"SELECT name FROM %@ WHERE idx = (SELECT MAX(idx) FROM %@ WHERE name LIKE ?)", aTable, aTable], aStack];
}


- (void) pushAction: (NSDictionary *)anAction stack: (NSString *)aTable forName: (NSString *)aStack
{
    NILARG_EXCEPTION_TEST(aStack);
    
    NSData *aBlob = [NSJSONSerialization dataWithJSONObject: anAction options: 0 error: NULL];
    BOOL ok = [_db executeUpdate: [NSString stringWithFormat: @"INSERT INTO %@ (name, data) VALUES (?, ?)", aTable], aStack, aBlob];
    assert(ok);
}

@end
