#import "ETObjectPipe.h"
#import <EtoileFoundation/EtoileFoundation.h>

/**
 * The size of the ring buffer.  Defined statically so the masking is easy.  We
 * could make this dynamic in future though...
 *
 * For most things in MediaKit, low latency is important.  Having a large ring
 * buffer will make latency worse.  It will, however, increase buffering, so
 * will cause fewer frames to be dropped in high CPU load times.  This will
 * need some tweaking.
 *
 * Note, RING_BUFFER_SIZE must be a power of two.
 */
#define RING_BUFFER_SIZE 16
#define RING_BUFFER_MASK (RING_BUFFER_SIZE - 1)

/**
 * GCC 4.1 provides atomic operations which impose memory barriers.  These are
 * not needed on x86, but might be on other platforms (anything that does not
 * enforce strong ordering of memory operations, e.g. Itanium or Alpha).
 */
#if __GNUC__ < 4 || (__GNUC__ == 4 && __GNUC_MINOR__ < 1)
#warning Potentially unsafe memory operations being used
static inline void __sync_fetch_and_add(unsigned long *ptr, unsigned int value)
{
	*ptr += value;
}
#endif

/**
 * Check how much space is in the queue.  The number of used elements in the
 * queue is always equal to producer - consumer.   Producer will always
 * overflow before consumer (because you can't remove objects that have not
 * been inserted.  In this case, the subtraction will be something along the
 * lines of (0 - (2^32 - 14)).  This will be -(2^32 - 14), however this value
 * can't be represented in a 32-bit integer and so will overflow to 14, giving
 * the correct result, irrespective of overflow.  
 */
#define SPACE(producer, consumer) (RING_BUFFER_SIZE - (producer - consumer))
/**
 * The buffer is full if there is no space in it.
 */
#define ISFULL(producer, consumer) (SPACE(producer, consumer) == 0)
/**
 * The buffer is empty if there is no data in it.
 */
#define ISEMPTY(producer, consumer) ((producer - consumer) == 0)
/**
 * Converting the free running counters to array indexes is a masking
 * operation.  For this to work, the buffer size must be a power of two.
 * RING_BUFFER_MASK = RING_BUFFER_SIZE - 1.  If RING_BUFFER_SIZE is 256, we
 * want the lowest 8 bits of the index, which is obtained by ANDing the value
 * with 255.  Any power of two may be selected.  Non power-of-two values could
 * be used if a more complex mapping operation were chosen, but this one is
 * nice and cheap.
 */
#define MASK(index) ((index) & RING_BUFFER_MASK)
/**
 * Inserting an element into the queue involves the following steps:
 *
 * 1) Check that there is space in the buffer.
 *     Spin if there isn't any.
 * 2) Add the invocation and optionally the proxy containing the return value
 * (nil for none) to the next two elements in the ring buffer.
 * 3) Increment the producer counter (by two, since we are adding two elements).
 * 4) If the queue was previously empty, we need to transition back to lockless
 * mode.  This is done by signalling the condition variable that the other
 * thread will be waiting on if it is in blocking mode.
 *
 * If the queue is full then we poke the condition variable periodically.  This
 * is not required when the condition variable is not shared, but when it is
 * more than one 
 */
#define INSERT(x,direction) do {\
	int count = 0;\
	/* Wait for space in the buffer */\
	while (ISFULL(direction ## Producer, direction ## Consumer))\
	{\
		if (count % 20 == 0)\
		{\
			[direction ## Condition signal];\
		}\
		sched_yield();\
	}\
	queue[MASK(direction ## Producer)] = x;\
	__sync_fetch_and_add(&direction ## Producer, 1);\
	if (direction ## Producer - direction ## Consumer == 1)\
	{\
		[direction ## Condition lock];\
		[direction ## Condition signal];\
		[direction ## Condition unlock];\
	}\
} while(0);
/**
 * Removing an element from the queue involves the following steps:
 *
 * 1) Wait until the queue has messages waiting.  If there are none, enter
 * blocking mode.  The additional test inside the mutex ensures that a
 * transition from blocking to non-blocking mode will not be missed, since the
 * condition variable can only be signalled when the producer thread has the
 * mutex.  
 * 2) Read the invocation and return proxy from the buffer.
 * 3) Increment the consumer counter.
 */
#define REMOVE(x,direction) do {\
	if (ISEMPTY(direction ## Producer, direction ## Consumer))\
	{\
		if (disconnect) { return nil; }\
		else\
		{\
			[direction ## Condition lock];\
			if (ISEMPTY(direction ## Producer, direction ## Consumer))\
			{\
				[direction ## Condition wait];\
			}\
			[direction ## Condition unlock];\
		}\
	}\
	x = queue[MASK(direction ## Consumer)];\
	queue[MASK(direction ## Consumer)] = nil;\
	__sync_fetch_and_add(&direction ## Consumer, 1);\
} while(0);

@implementation ETObjectPipe
- (id)init
{
	SUPERINIT;
	queue = calloc(sizeof(id), RING_BUFFER_SIZE);
	requestCondition  = [NSCondition new];
	replyCondition  = [NSCondition new];
	if (NULL == queue || nil == replyCondition || nil == requestCondition)
	{
		[self release];
		return nil;
	}
	return self;
}
- (void)dealloc
{
	for (unsigned int i=0 ; i<RING_BUFFER_SIZE ; i++)
	{
		[queue[i] release];
	}
	free(queue);
	[requestCondition release];
	[replyCondition release];
	[super dealloc];
}
- (void)sendRequest: (id)anObject
{
	if (disconnect) { return; }
	INSERT(anObject, request);
}
- (id)nextRequest
{
	id obj;
	REMOVE(obj, request);
	return obj;
}
- (id)pollForRequest
{
	if (ISEMPTY(requestProducer, requestConsumer))
	{
		return nil;
	}
	id obj = queue[MASK(requestConsumer)];
	queue[MASK(requestConsumer)] = nil;
	__sync_fetch_and_add(&requestConsumer, 1);
	return obj;
}
- (BOOL)isPipeFull
{
	return ISFULL(requestProducer, replyConsumer);
}
- (id)pollForReply
{
	// If there is a reply waiting, get it without blocking
	if (replyConsumer < replyProducer)
	{
		id reply = queue[MASK(replyConsumer)];
		queue[MASK(replyConsumer)] = nil;
		__sync_fetch_and_add(&replyConsumer, 1);
		return reply;
	}
	// If the queue is not full, return and let the caller create a new request
	// object to insert.
	else if (!ISFULL(requestProducer, replyConsumer))
	{
		return nil;
	}
	// If the queue is full, block until the other end produces a reply.
	return [self nextReply];
}
- (NSCondition*)requestCondition
{
	return requestCondition;
}
- (void)setRequestCondition: (NSCondition*)aCondition
{
	ASSIGN(requestCondition, aCondition);
}
- (void)sendReply: (id)anObject
{
	if (disconnect) { return; }
	INSERT(anObject, reply);
}
- (id)nextReply
{
	id obj;
	REMOVE(obj, reply);
	return obj;
}
- (void)disconnect
{
	disconnect = YES;
	// Wake up any threads that are waiting on either end.
	[requestCondition broadcast];
	[replyCondition broadcast];
}
@end
