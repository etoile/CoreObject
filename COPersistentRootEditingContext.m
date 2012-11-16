#import "COPersistentRootEditingContext.h"
#import "COEditingContext.h"
#import "COError.h"
#import "COObject.h"
#import "COStore.h"
#import "CORevision.h"
#import "COCommitTrack.h"

@implementation COPersistentRootEditingContext

@synthesize persistentRootUUID, parentContext, commitTrack, rootObject, revision;

- (id)initWithPersistentRootUUID: (ETUUID *)aUUID
				 commitTrackUUID: (ETUUID *)aTrackUUID
					  rootObject: (COObject *)aRootObject
				   parentContext: (COEditingContext *)aCtxt
{
	SUPERINIT;
	ASSIGN(persistentRootUUID, aUUID);
	// TODO: Use the track UUID and the root object as no editing context at all
	// when the initializer is called.
	//ASSIGN(commitTrack, [COCommitTrack trackWithObject: aRootObject]);
	ASSIGN(rootObject, aRootObject);
	parentContext = aCtxt;
	return self;
}

- (void)dealloc
{
	//DESTROY(commitTrack);
	DESTROY(rootObject);
	DESTROY(revision);
	[super dealloc];
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
	if (parentContext != nil && [parentContext respondsToSelector: aSelector])
	{
		//NSLog(@"Will forward selector %@", NSStringFromSelector(aSelector));
		return parentContext;
	}
	return [super forwardingTargetForSelector: aSelector];
}

- (id)objectWithUUID: (ETUUID *)uuid
{
	return [parentContext objectWithUUID: uuid];
}

- (COObject *)objectWithUUID: (ETUUID *)uuid entityName: (NSString *)name atRevision: (CORevision *)rev
{
	return [parentContext objectWithUUID: uuid entityName: name atRevision: rev];
}

- (void)reloadAtRevision: (CORevision *)rev
{
	[[self parentContext] reloadRootObjectTree: [self rootObject] atRevision: rev];
}

- (void)unload
{
	[[self parentContext] unloadRootObjectTree: [self rootObject]];
}

@end