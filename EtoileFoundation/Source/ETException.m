#import "ETException.h"

void pophandler(void* exception)
{
	[NSException popHandlerForException:*(NSString**)exception];
}

@implementation NSException (ETException)
+ (void) pushHandler:(ETHandler)aHandler forException:(NSString*)aName
{
	NSMutableDictionary * threadDict = [[NSThread currentThread] threadDictionary];
	NSMutableDictionary * handlers = [threadDict objectForKey:@"ExceptionHandlers"];
	if(handlers == nil)
	{
		handlers = [[NSMutableDictionary alloc] init];
		[threadDict setObject:handlers forKey:@"ExceptionHandlers"];
		[handlers release];
	}
	NSMutableArray * stack = [handlers objectForKey:aName];
	if(stack == nil)
	{
		stack = [[NSMutableArray alloc] init];
		[handlers setObject:stack forKey:aName];
	}
	[stack addObject:[NSValue valueWithPointer:aHandler]];
}
+ (void) popHandlerForException:(NSString*)aName
{
	NSMutableDictionary * threadDict = [[NSThread currentThread] threadDictionary];
	NSMutableDictionary * handlers = [threadDict objectForKey:@"ExceptionHandlers"];
	NSMutableArray * stack = [handlers objectForKey:aName];
	[stack removeLastObject];
}
@end

@interface ETException : NSException {
}
@end
@implementation ETException
+ (void) load
{
	[self poseAsClass:[NSException class]];
}
- (void) raise
{
	NSMutableDictionary * threadDict = [[NSThread currentThread] threadDictionary];
	NSMutableDictionary * handlers = [threadDict objectForKey:@"ExceptionHandlers"];
	NSValue * handler = [[handlers objectForKey:[self name]] lastObject];
	if(handler != nil)
	{
		ETHandler h = (ETHandler)[handler pointerValue];
		switch(h(self))
		{
			case EXCEPTION_RESUME:
				return;
			case EXCEPTION_RETRY:
				GLOBAL_EXCEPTION_STATE = EXCEPTION_RETRY;
				break;
			case EXCEPTION_ABORT:
			default:
				GLOBAL_EXCEPTION_STATE = EXCEPTION_ABORT;
		}
	}
	[super raise];
}
@end

#define NS_RESTARTABLE_DURING { __label__ retry_exception; retry_exception: NS_DURING
#define NS_RESTARTABLE_HANDLER \
		NS_HANDLER\
		if(GLOBAL_EXCEPTION_STATE == EXCEPTION_RETRY)\
		{\
			goto retry_exception;\
		}}
