/*
    Copyright (C) 2014 Quentin Mathe

    Date:  July 2014
    License:  MIT  (see COPYING)
 */

#import "CODistributedNotificationCenter.h"

@implementation CODistributedNotificationCenter

static CODistributedNotificationCenter *defaultCenter = nil;

+ (void)initialize
{
    if ([self class] != self)
        return;

    defaultCenter = [[self alloc] init];
}

+ (CODistributedNotificationCenter *)defaultCenter
{
    return defaultCenter;
}

- (void)addObserver: (id)observer 
           selector: (SEL)aSelector 
               name: (nullable NSNotificationName)aName 
             object: (nullable NSString *)anObject
{
#if !(SANDBOXED) && !(TARGET_OS_IPHONE)
    [[NSDistributedNotificationCenter defaultCenter] 
        addObserver: observer
           selector: aSelector
               name: aName
             object: anObject];
#else
    [[NSNotificationCenter defaultCenter] 
        addObserver: observer
           selector: aSelector
               name: aName
             object: anObject]; 
#endif
}

- (id <NSObject>)addObserverForName: (NSNotificationName)aName
                             object: (id)anObject
                              queue: (NSOperationQueue *)aQueue
                         usingBlock: (void (^)(NSNotification *notification))block
{
#if !(SANDBOXED) && !(TARGET_OS_IPHONE)
    return [[NSDistributedNotificationCenter defaultCenter]
        addObserverForName: aName
                    object: anObject
                     queue: aQueue
                usingBlock: block];
#else
    return [[NSNotificationCenter defaultCenter]
        addObserverForName: aName
                    object: anObject
                     queue: aQueue
                usingBlock: block];
#endif
}

- (void)removeObserver: (id)observer {
#if !(SANDBOXED) && !(TARGET_OS_IPHONE)
    [[NSDistributedNotificationCenter defaultCenter] removeObserver: observer];
#else
    [[NSNotificationCenter defaultCenter] removeObserver: observer];
#endif
}

- (void)postNotificationName: (nullable NSNotificationName)aName
                      object: (nullable NSString *)aSender
                    userInfo: (nullable NSDictionary *)userInfo
          deliverImmediately: (BOOL)deliverImmediately
{
#if !(SANDBOXED) && !(TARGET_OS_IPHONE)
    [[NSDistributedNotificationCenter defaultCenter] 
        postNotificationName: aName 
                      object: aSender 
                    userInfo: userInfo
          deliverImmediately: deliverImmediately];
#else
    [[NSNotificationCenter defaultCenter] 
        postNotificationName: aName 
                      object: aSender 
                    userInfo: userInfo];
#endif
}

@end
