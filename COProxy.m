#import "COProxy.h"
#import "ETSerializer.h"
#import "ETSerializerBackend.h"
#import "ETDeserializer.h"

static const int FULL_SAVE_INTERVAL = 100;
static id logBackend;

@implementation COProxy 
+ (void) initialize
{
	//Use this for debugging
	logBackend = [[ETSerializer serializerWithBackend:NSClassFromString(@"ETSerializerBackendExample")
								 			  forURL:nil] retain];
}
- (id) initWithObject:(id)anObject
           serializer:(Class)aSerializer
			forBundle:(NSURL*)anURL
{
	//Set a default URL for temporary objects
	if(anURL == nil)
	{
		anURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@ (%@).CoreObject",
			  NSTemporaryDirectory(),
			  [[NSProcessInfo processInfo] processName],
			  [[NSDate date] description]]];
	}
	//Only local file URLs are supported so far:
	if(![anURL isFileURL] || anObject == nil)
	{
		NSLog(@"Proxy creation failed.");
		[self release];
		return nil;
	}
	ASSIGN(object, anObject);
	//Find the correct proxy class:
	Class objectClass = [object class];
	Class proxyClass = Nil;
	while(objectClass != Nil)
	{
		if(Nil != (proxyClass = NSClassFromString([NSString stringWithFormat:@"COProxy_%s", objectClass->name])))
		{
			self->isa = proxyClass;
			break;
		}
		objectClass = objectClass->super_class;
	}
	ASSIGN(baseURL,anURL);
	if(aSerializer == nil)
	{
		//TODO: Move this into a default
		aSerializer = NSClassFromString(@"ETSerializerBackendBinary");
	}
	backend = aSerializer;
	serializer = [[ETSerializer serializerWithBackend:aSerializer 
								 			  forURL:baseURL] retain];
	[serializer serializeObject:object withName:@"BaseVersion"];
	NSString * path = [NSString stringWithFormat:@"%@/FullSaves",
					 [baseURL path]];
	NSURL * fullsaveURL = [NSURL fileURLWithPath:path];
	fullSave = [[ETSerializer serializerWithBackend:backend
											forURL:fullsaveURL] retain];
	[fullSave setVersion:0];
	[fullSave serializeObject:object withName:@"FullSave"];
	return self;
}
- (int) version
{
	return version;
}
- (int) setVersion:(int)aVersion
{
	//find the full-save version closest to the requested one
	id unFull = [fullSave deserializer];
	int fullVersion = aVersion;
	while(fullVersion >= 0 && [unFull setVersion:fullVersion] != fullVersion)
	{
		fullVersion--;
	}
	if(fullVersion < 0)
	{
		NSLog(@"Failed to find full save");
		return -1;
	}
	id new = [unFull restoreObjectGraph];
	//Play back each of the subsequent invocations
	id unDelta = [serializer deserializer];
	for(int v=fullVersion + 1 ; v<=aVersion ; v++)
	{
		[unDelta setVersion:v];
		id pool = [NSAutoreleasePool new];
		NSInvocation * invocation = [unDelta restoreObjectGraph];
		[invocation invokeWithTarget:new];
		[invocation release];
		[pool release];
	}
	[object release];
	object = new;
	return version;
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	    return [object methodSignatureForSelector:aSelector];
}
/**
 * Forwards the invocation to the real object after serializing it.  Every few
 * invocations, it will also save a full copy of the object.
 */
- (void)forwardInvocation:(NSInvocation *)anInvocation
{
	version = [serializer newVersion];
	[anInvocation setTarget:nil];
	[serializer serializeObject:anInvocation withName:@"Delta"];
	//[logBackend serializeObject:anInvocation withName:@"Delta"];
	[anInvocation setTarget:object];
	[anInvocation invoke];
	/* Periodically save a full copy */
	if(version % FULL_SAVE_INTERVAL == 0)
	{
		[fullSave setVersion:version];
		[fullSave serializeObject:object withName:@"FullSave"];
	}
}

- (BOOL) isCoreObjectProxy 
{
	return YES; 
}

@end
