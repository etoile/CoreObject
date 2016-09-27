/*
    Copyright (C) 2011 Eric Wasylishen

    Date:  November 2011
    License:  MIT  (see COPYING)
 */

#import "COPath.h"
#import <EtoileFoundation/Macros.h>
#import <EtoileFoundation/ETUUID.h>

@interface COBrokenPath : COPath
@end


@implementation COPath

@synthesize persistentRoot = _persistentRoot;
@synthesize branch = _branch;

- (COPath *)initWithPersistentRoot: (ETUUID *)aRoot
                            branch: (ETUUID *)aBranch
{
    SUPERINIT;
    NILARG_EXCEPTION_TEST(aRoot);
    _persistentRoot = aRoot;
    _branch = aBranch;
    return self;
}

+ (COPath *)pathWithPersistentRoot: (ETUUID *)aRoot
{
    return [[self alloc] initWithPersistentRoot: aRoot branch: nil];
}

+ (COPath *)pathWithPersistentRoot: (ETUUID *)aRoot
                            branch: (ETUUID *)aBranch
{
    return [[self alloc] initWithPersistentRoot: aRoot branch: aBranch];
}

+ (COPath *)brokenPath
{
    return [COBrokenPath new];
}

+ (COPath *)pathWithString: (NSString *)pathString
{
    NILARG_EXCEPTION_TEST(pathString);

    ETUUID *branch = nil;
    ETUUID *persistentRoot = nil;

    if (pathString.length > 0)
    {
        NSArray *components = [pathString componentsSeparatedByString: @":"];
        switch (components.count)
        {
            case 2:
                branch = [ETUUID UUIDWithString: components[1]];
            case 1:
                persistentRoot = [ETUUID UUIDWithString: components[0]];
                break;
            default:
                [NSException raise: NSInvalidArgumentException
                            format: @"unsupported COPath string '%@'",
                                    pathString];
        }
    }
    return [COPath pathWithPersistentRoot: persistentRoot branch: branch];
}

- (id)copyWithZone: (NSZone *)zone
{
    return self;
}

- (BOOL)isBroken
{
    return NO;
}

- (NSString *)stringValue
{
    if (_branch == nil)
    {
        return [_persistentRoot stringValue];
    }
    else
    {
        return [NSString stringWithFormat: @"%@:%@", _persistentRoot, _branch];
    }
}

- (NSUInteger)hash
{
    return _branch.hash ^ _persistentRoot.hash;
}

- (BOOL)isEqual: (id)anObject
{
    if (anObject == self)
        return YES;

    if (![anObject isKindOfClass: [COPath class]])
        return NO;

    COPath *otherPath = anObject;
    if (![_persistentRoot isEqual: otherPath->_persistentRoot])
        return NO;

    if (!((_branch == nil && otherPath->_branch == nil)
          || [_branch isEqual: otherPath->_branch]))
        return NO;

    return YES;
}

- (NSString *)description
{
    return self.stringValue;
}

@end


@implementation COBrokenPath

- (BOOL)isBroken
{
    return YES;
}

- (id)copyWithZone: (NSZone *)zone
{
    return self;
}

- (NSString *)stringValue
{
    return @"COBrokenPath";
}

- (NSUInteger)hash
{
    return (NSUInteger)self;
}

- (BOOL)isEqual: (id)anObject
{
    return NO;
}

- (NSString *)description
{
    return self.stringValue;
}

@end
