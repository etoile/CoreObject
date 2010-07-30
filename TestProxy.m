/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <UnitKit/UnitKit.h>
#import "COProxy.h"
#import "COObjectContext.h"
#import "COObjectServer.h"
#import "COMetadataServer.h"
#import "COUtility.h"

#define NEW(X) (AUTORELEASE([[X alloc] init]))

@interface COObjectServer (Test)
+ (void) makeNewDefaultServer;
@end

/* For testing subclass */
@interface BasicModel : NSObject
{
	NSString *whoami;
	NSMutableArray *otherObjects;
}
- (NSArray *) persistencyMethodNames;
- (NSString *) whoAmI;
- (void) setWhoAmI: (NSString *)aString;
- (NSMutableArray *) otherObjects;
- (void) addOtherObject: (id)anObject;
- (void) removeOtherObject: (id)anObject;
@end

@interface TestProxy : NSObject <UKTest>
{
	id proxy;
}

@end


@implementation TestProxy

- (id) initForTest
{
	SUPERINIT
	[COObjectServer makeNewDefaultServer];
	[COObjectContext setCurrentContext: NEW(COObjectContext)];

	proxy = [[COProxy alloc] initWithObject: NEW(BasicModel)];

	return self;
}

- (void) releaseForTest
{
	[COObjectServer makeNewDefaultServer];
	[COObjectContext setCurrentContext: NEW(COObjectContext)];

	DESTROY(proxy);

	[super release];
}

- (void) testInit
{
	UKNotNil([proxy UUID]);
	UKNotNil([proxy objectContext]);
	UKIntsEqual(0, [proxy objectVersion]);
	UKObjectsEqual([COProxy class], ((COProxy *)proxy)->isa);
}

- (void) testInitAsFaultWhenAlreadyLoaded
{
	id metadataServer = [[COObjectServer defaultServer] metadataServer];
	id faultDesc = [metadataServer faultDescriptionForUUID: [proxy UUID]];
	id fault = [[COProxy alloc] initWithFaultDescription: faultDesc futureClassName: nil];

	UKObjectsSame(proxy, fault);
}

- (void) testInitAsFaultAndLoad
{
	int objectVersion = [proxy objectVersion];

	[[proxy objectContext] unregisterObject: proxy];

	/* Paranoid check */
	UKNil([[COObjectServer defaultServer] cachedObjectForUUID: [proxy UUID]]);

	id metadataServer = [[COObjectServer defaultServer] metadataServer];
	id faultDesc = [metadataServer faultDescriptionForUUID: [proxy UUID]]; 
	id fault = [[COProxy alloc] initWithFaultDescription: faultDesc futureClassName: nil];

	UKObjectsNotSame(proxy, fault);
	UKTrue([fault isFault]);
	UKIntsEqual(-1, [fault objectVersion]);
	UKObjectsEqual([COObjectContext currentContext], [fault objectContext]);
	UKTrue([[[COObjectContext currentContext] registeredObjects] containsObject: fault]);

	[(COProxy *)fault load];

	UKFalse([fault isFault]);
	UKIntsEqual(objectVersion, [fault objectVersion]);
	UKObjectsEqual([COObjectContext currentContext], [fault objectContext]);
	UKTrue([[[COObjectContext currentContext] registeredObjects] containsObject: fault]);

	/* Test real object is ready and persistency selectors have been restored */
	UKStringsEqual(@"Nobody", [fault whoAmI]);
	UKIntsEqual(objectVersion, [fault objectVersion]);
}

- (void) testRespondsToSelector
{
	
}

- (void) testIntrospection
{
	
}

- (void) testDoesNotRecognizeSelector
{
	
}

- (void) testForwardInvocation
{
	UKStringsEqual(@"Nobody", [proxy whoAmI]);
	[proxy removeOtherObject: @"New York"];

	UKIntsEqual(0, [proxy objectVersion]);
	UKIntsEqual(1, [[proxy objectContext] version]);
}

- (void) testRecordInvocation
{
	COObjectContext *ctxt = [proxy objectContext];
	int contextVersion = [ctxt version];

	[proxy addOtherObject: @"One"];

	UKIntsEqual(1, [proxy objectVersion]);
	UKIntsEqual(contextVersion + 1, [ctxt version]);
	UKObjectsEqual(A(@"New York", @"One"), [proxy otherObjects]);

	[proxy setWhoAmI: @"Fox"];
	
	UKIntsEqual(2, [proxy objectVersion]);
	UKIntsEqual(contextVersion + 2, [ctxt version]);
	UKStringsEqual(@"Fox", [proxy whoAmI]);
}

- (void) testRestoreObjectToVersion
{
	[proxy addOtherObject: @"One"];
	[proxy setWhoAmI: @"Fox"];
	[proxy setWhoAmI: @"Vulture"]; // v3

	COObjectContext *ctxt = [proxy objectContext];
	int contextVersion = [ctxt version];
	
	[proxy restoreObjectToVersion: 2]; // v4

	UKIntsEqual(4, [proxy objectVersion]);
	UKIntsEqual(contextVersion + 1, [ctxt version]);
	UKStringsEqual(@"Fox", [proxy whoAmI]);
	UKObjectsEqual(A(@"New York", @"One"), [proxy otherObjects]);

	[proxy addOtherObject: @"Huh"]; // v5 and increment contextVersion by one
	[proxy restoreObjectToVersion: 0];// v6 and increment contextVersion by one

	UKIntsEqual(6, [proxy objectVersion]);
	UKIntsEqual(contextVersion + 3, [ctxt version]);
	UKStringsEqual(@"Nobody", [proxy whoAmI]);
	UKObjectsEqual(A(@"New York"), [proxy otherObjects]);

	[proxy restoreObjectToVersion: 5]; // v7 

	UKIntsEqual(7, [proxy objectVersion]);
	UKIntsEqual(contextVersion + 4, [ctxt version]);
	UKStringsEqual(@"Fox", [proxy whoAmI]); // Fox and not Vulture because we restored v2 at v4
	UKObjectsEqual(A(@"New York", @"One", @"Huh"), [proxy otherObjects]);

}

@end


/* NSObject subclass */
		
@implementation BasicModel

- (id) init
{
	SUPERINIT
	whoami = @"Nobody";
	otherObjects = [[NSMutableArray alloc] initWithObjects: @"New York", nil];
	return self;
}

DEALLOC(DESTROY(whoami); DESTROY(otherObjects);)

- (NSArray *) persistencyMethodNames 
{
	// NOTE: We don't include -removeOtherObject: to test whether it is well 
	// ignored in -testForwardInvocation.
	return A(@"setWhoAmI:", @"addOtherObject:"); 
}

- (NSString *) whoAmI { return whoami; }

- (void) setWhoAmI: (NSString *)aString 
{ 
	ASSIGN(whoami, aString);
}

- (NSMutableArray *) otherObjects { return otherObjects; }

- (void) addOtherObject: (id)anObject 
{ 
	[otherObjects addObject: anObject];
}

- (void) removeOtherObject: (id)anObject
{
	[otherObjects removeObject: anObject];	
}

@end
