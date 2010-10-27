/** <title>ETStackTraceRecorder</title>

	<abstract>A debug utility to record stack traces in relation to an 
	instance.</abstract>

	Copyright (C) 2010 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  June 2010
	License:  Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>


/** A stack trace recorder allows to snapshot the call stack symbols and 
inspect these snapshots later on.

You invoke -recordForObject: to snapshot the current call stack symbols and 
-recordedStackTracesForObject: to get all the call stack traces recorded until 
now. 

A stack trace recorder is very handy to debug memory management issues. e.g. 
You can easily discover where an over-released object was allocated in a vein 
similar to malloc_history on Mac OS X.<br />
Take note that +enableAllocationRecordingForClass: is only available on GNUstep 
and the example detailed below doesn't apply to Mac OS X where you must use 
malloc_history instead.<br />
To get meaningfull backtrace on GNUstep, you must install the GNU bin utils 
(e.g. binutils-dev package on Ubuntu) and configure GNUstep Base with 
'--enable-bfd'. 
Be aware that the resulting gnustep-base library will be GPL-licensed and 
transively all the code that links it will become GPL-licensed too.

For a retain/release crash, note the instance class that got double-released, 
then add in main() or equivalent:
<code>[[ETStackTraceRecorder sharedInstance] enableAllocationRecordingForClass: [MyClass class]];</code>
To prevent the instance to be deallocated, set NSZombieEnabled to YES (e.g. 
'export NSZombieEnabled YES' in the shell). Finally compile and run the program 
in GDB and at crash time, type on the GDB prompt:
<code>po [[ETStackTraceRecorder sharedInstance] recordedStackTracesForObject: instance] firstObject]</code>
Where 'instance' is the instance address or a variable pointing on the instance. 
Then GDB prints the stack trace which points back to the code that allocated 
the instance.<br />
You can also put a breakpoint on -[NSZombie forwardInvocation:], but take note 
that NSZombie doesn't respond to -recordedStackTraces (at least on GNUstep).

ETStackTraceRecorder is thread-safe (not fully yet), multiple threads can invoke 
-recordForObject:. */
@interface ETStackTraceRecorder : NSObject
{
	NSMapTable *_tracesByObject;
	NSThread *_recordThread;
	NSLock *_lock;
	NSMutableSet *_allocMonitoredClasses;
}

+ (id) sharedInstance;

#ifdef GNUSTEP
- (void) enableAllocationRecordingForClass: (Class)aClass;
- (void) disableAllocationRecordingForClass: (Class)aClass;
#endif

- (void) recordForObject: (id)anObject;
- (NSArray *) recordedStackTracesForObject: (id)anObject;

@end

/** Some conveniency methods which makes easier to work with the shared stack 
trace recorder instance.

For example, in GDB you can type [self recordStackTrace] to keep a trace of the 
current call stack.<br />
And you can print all the stack traces recorded for the current object with 
'po [[self recordedStackTraces] stringValue]'. */
@interface NSObject (ETStackTraceRecorderConveniency)
- (void) recordStackTrace;
- (NSArray *) recordedStackTraces;
@end


/** Represents a stack trace built from an array of call stack symbols.

You usually don't need to instantiate stack trace objects directly, 
ETStackTraceRecorder does it. */
@interface ETStackTrace : NSObject
{
	NSArray *_callStackSymbols;
}

- (id) init;
- (NSUInteger) numberOfFrames;

@end
