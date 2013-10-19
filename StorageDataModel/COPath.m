#import "COPath.h"
#import <EtoileFoundation/Macros.h>
#import <EtoileFoundation/ETUUID.h>

@implementation COPath

@synthesize persistentRoot = persistentRoot_;
@synthesize branch = branch_;
@synthesize innerObject = innerObject_;

- (BOOL) isCrossPersistentRoot
{
    return persistentRoot_ != nil;
}

- (COPath *) initWithPersistentRoot: (ETUUID *)aRoot
							 branch: (ETUUID*)aBranch
					embdeddedObject: (ETUUID *)anObject
{	
	SUPERINIT;
	NILARG_EXCEPTION_TEST(aRoot);
	persistentRoot_ =  aRoot;
	branch_ =  aBranch;
	innerObject_ =  anObject;
	return self;
}


+ (COPath *) pathWithPersistentRoot: (ETUUID *)aRoot
{
	return [self pathWithPersistentRoot:aRoot branch: nil];
}

+ (COPath *) pathWithPersistentRoot: (ETUUID *)aRoot
							 branch: (ETUUID*)aBranch
{
	return [self pathWithPersistentRoot:aRoot branch:aBranch embdeddedObject:nil];
}

+ (COPath *) pathWithPersistentRoot: (ETUUID *)aRoot
							 branch: (ETUUID*)aBranch
					embdeddedObject: (ETUUID *)anObject
{
	return [[self alloc] initWithPersistentRoot: aRoot branch: aBranch embdeddedObject: anObject];
}

+ (COPath *) pathWithString: (NSString*) pathString
{
	NILARG_EXCEPTION_TEST(pathString);
	
	ETUUID *innerObject = nil;
	ETUUID *branch = nil;
	ETUUID *persistentRoot = nil;
	
	if ([pathString length] > 0)
	{
		NSArray *components = [pathString componentsSeparatedByCharactersInSet:
							   [NSCharacterSet characterSetWithCharactersInString: @":."]];
		switch ([components count])
		{
			case 3:
				innerObject = [ETUUID UUIDWithString: [components objectAtIndex: 2]];
			case 2:
				branch = [ETUUID UUIDWithString: [components objectAtIndex: 1]];
			case 1:
				persistentRoot = [ETUUID UUIDWithString: [components objectAtIndex: 0]];
				break;
			default:
				[NSException raise: NSInvalidArgumentException format: @"unsupported COPath string '%@'", pathString];
		}
	}
	return [COPath pathWithPersistentRoot: persistentRoot branch: branch embdeddedObject: innerObject];
}

- (COPath *) pathWithNameMapping: (NSDictionary *)aMapping
{
	ETUUID *innerObject = innerObject_;
	ETUUID *branch = branch_;
	ETUUID *persistentRoot = persistentRoot_;
    
    if (innerObject != nil
        && [aMapping objectForKey: innerObject])
    {
        innerObject = [aMapping objectForKey: innerObject];
    }
    
    if (branch != nil
        && [aMapping objectForKey: branch])
    {
        branch = [aMapping objectForKey: branch];
    }
    
    if (persistentRoot != nil
        && [aMapping objectForKey: persistentRoot])
    {
        persistentRoot = [aMapping objectForKey: persistentRoot];
    }
    
    return [COPath pathWithPersistentRoot: persistentRoot
                                   branch: branch
                          embdeddedObject: innerObject];
}

- (id) copyWithZone: (NSZone *)zone
{
	return self;
}

- (NSString *) stringValue
{
	NSMutableString *value = [NSMutableString stringWithString: [persistentRoot_ stringValue]];
	
	if (branch_ != nil)
	{
		[value appendFormat: @":%@", branch_];
	}
	if (innerObject_ != nil)
	{
		[value appendFormat: @".%@", innerObject_];
	}
	
	return [NSString stringWithString: value];
}

- (NSUInteger) hash
{
	return [[self stringValue] hash];
}

- (BOOL) isEqual: (id)anObject
{
	return [anObject isKindOfClass: [self class]] &&
	[[self stringValue] isEqualToString: [anObject stringValue]];
}

- (NSString*) description
{
	return [self stringValue];
}

@end
