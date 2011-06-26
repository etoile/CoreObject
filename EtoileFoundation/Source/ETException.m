#import "ETException.h"
#import "objc/runtime.h"

void pophandler(void* exception)
{
	[NSException popHandlerForException:*(NSString**)exception];
}

IMP nsexception_raise;

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
+ (void)enableEtoileExceptions
{
	if (0 != nsexception_raise) { return; }
	Class nsexception = objc_getClass("NSException");
	SEL raise = @selector(raise);
	nsexception_raise = class_getMethodImplementation(nsexception, raise);
	Method m = class_getInstanceMethod(self, raise);
	class_replaceMethod(nsexception,
	                    raise,
	                    method_getImplementation(m),
	                    method_getTypeEncoding(m));
}
@end

@interface ETException : NSException {
}
@end
@implementation ETException
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
	nsexception_raise(self, _cmd);
}
@end

#define NS_RESTARTABLE_DURING { __label__ retry_exception; retry_exception: NS_DURING
#define NS_RESTARTABLE_HANDLER \
		NS_HANDLER\
		if(GLOBAL_EXCEPTION_STATE == EXCEPTION_RETRY)\
		{\
			goto retry_exception;\
		}}
