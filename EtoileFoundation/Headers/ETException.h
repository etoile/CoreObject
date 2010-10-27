#import <Foundation/Foundation.h>

/**
 * Type of exception.  Used as the return type from exception handlers.  Abort
 * causes stack unwinding.  Resume continues execution after the line that
 * raised the exception and retry causes the block that caused the exception to
 * be retried, if it was declared as restartable.
 */
typedef enum {EXCEPTION_ABORT, EXCEPTION_RESUME, EXCEPTION_RETRY} ETExceptionType;
ETExceptionType GLOBAL_EXCEPTION_STATE;

/**
 * Prototype for exception handler function.
 */
typedef ETExceptionType (*ETHandler)(NSException * userInfo);

@interface NSException (ETException)
/**
 * Adds aHandler to the top of the exception handling stack for exceptions
 * named aName.  Any exceptions called with the specified name will cause this
 * handler to be invoked while it is on top of the exception handling stack.
 */
+ (void) pushHandler:(ETHandler)aHandler forException:(NSString*)aName;
/**
 * Removes the top exception handler from the stack corresponding to the name.
 */
+ (void) popHandlerForException:(NSString*)aName;
@end
/**
 * Adds the specified handler for the named exception for the duraction of the
 * current lexical scope.
 */
#define SET_HANDLER(exception, handler) \
	[NSException pushHandler:handler forException:exception];\
	NSString *  __attribute__((cleanup(pophandler))) wibble##handler = exception;
/**
 * Function installed as a cleanup function by SET_HANDLER to pop the added
 * exception off the stack when the current lexical scope is exited.
 */
extern void pophandler(void* exception);

/**
 * Version of NS_DURING which permits restarts to occur if restartable
 * exception is issued.  In the event of a restartable exception being raised,
 * control will jump to the start of this block.  Care must be taken to avoid
 * infinite loops and memory leaks.
 */
#define NS_RESTARTABLE_DURING { __label__ retry_exception; retry_exception: NS_DURING
/**
 * End a restartable exception block.  Equivalent to NS_HANDLER to be used with
 * NS_RESTARTABLE_DURING.
 */
#define NS_RESTARTABLE_HANDLER \
		NS_HANDLER\
		if(GLOBAL_EXCEPTION_STATE == EXCEPTION_RETRY)\
		{\
			goto retry_exception;\
		}}
