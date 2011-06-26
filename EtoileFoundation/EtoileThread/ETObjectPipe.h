#import <Foundation/NSObject.h>
#import <Foundation/NSLock.h>

/**
 * The ETObjectPipe class encapsulates a connection between two filters. 
 *
 * Conceptually, the pipe provides an asynchronous request-response mechanism
 * between two threads.  The pipe is partially thread-safe.  Each end must only
 * be held by one thread, unless protected externally by a lock.  One end sends
 * requests and receives replies, the other receives requests and sends
 * replies.
 *
 * Every request must have corresponding reply sent, although this may be nil.
 * The intended use for this is to allow a small set of buffers to be recycled
 * between a cooperating pair of filters.  
 */
@interface ETObjectPipe : NSObject {
	/** The ring buffer. */
	id *queue;
	/** Producer free-running counter for requests. */
	uint32_t requestProducer;
	/** Consumer free-running counter for requests. */
	uint32_t requestConsumer;
	/** Producer free-running counter for replies. */
	uint32_t replyProducer;
	/** Consumer free-running counter for replies. */
	uint32_t replyConsumer;
	/** 
	 * Condition variable used to signal a transition from locked to lockless
	 * mode for requests.
	 */
	NSCondition *requestCondition;
	/** 
	 * Condition variable used to signal a transition from locked to lockless
	 * mode for replies.
	 */
	NSCondition *replyCondition;
	/** Flag used to interrupt the object in locked mode */
	volatile BOOL disconnect;
}
/**
 * Disconnects the pipe.  This prevents either end from blocking waiting for
 * data that will never arrive.  There is no mechanism for reconnecting a
 * disconnected pipe: you must create a new pipe and connect it to both filters.
 *
 * Note that only one end of the connection is required to call -disconnect.
 * There are no ill effects from calling it twice, however, so it is generally
 * good practice to call -disconnect before you call -release on a connected pipe.
 */
- (void)disconnect;
/**
 * Insert anObject into the ring buffer as a request.
 */
- (void)sendRequest: (id)anObject;
/**
 * Retrieve the next request from the ring buffer.
 */
- (id)nextRequest;
/**
 * Returns the next request if there is one waiting, or nil if this pipe is
 * empty.
 */
- (id)pollForRequest;
/**
 * Returns the next reply if there is one waiting.  If the pipe is full, this
 * blocks until a reply is available.  If the pipe is not full, but there are
 * no replies waiting this returns nil.  You can use this to automatically wait
 * when the pipe is full by inserting new requests when this method returns
 * nil.
 */
- (id)pollForReply;
/**
 * Insert a reply into the ring buffer.
 */
- (void)sendReply: (id)anObject;
/**
 * Retrieve the next reply from the buffer.
 */
- (id)nextReply;
/**
 * Returns YES if the pipe is completely full, NO otherwise.
 */
- (BOOL)isPipeFull;
/**
 * Returns the condition variable used to block when waiting for a request.
 */
- (NSCondition*)requestCondition;
/**
 * Sets the condition variable used to block when waiting for a request.  Note
 * that this method should only ever be called from the thread which handles
 * requests.  
 *
 * This method can be used to share a condition variable between several pipes,
 * allowing a single filter to wait for data on any of them.
 */
- (void)setRequestCondition: (NSCondition*)aCondition;
@end
