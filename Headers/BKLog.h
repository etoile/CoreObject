//
//  BKLog.h
//  Blocks
//
//  Created by Jesse Grosjean on 3/29/05.
//  Copyright 2005 Hog Bay Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define LOCATION_PARAMETERS lineNumber:__LINE__ fileName:(char *)__FILE__ methodName:(char *)__PRETTY_FUNCTION__

#define logDebug(message) if([BKLog isDebugEnabled]) [BKLog debug:(message) LOCATION_PARAMETERS]
#define logInfo(message) if([BKLog isInfoEnabled]) [BKLog info:(message) LOCATION_PARAMETERS]
#define logWarn(message)  [BKLog warn:(message) LOCATION_PARAMETERS]
#define logError(message) [BKLog error:(message) LOCATION_PARAMETERS]
#define logErrorWithException(message,e) [BKLog error:(message) exception:e LOCATION_PARAMETERS]
#define logFatal(message) [BKLog fatal:(message) LOCATION_PARAMETERS]

#define logAssert(assertion,aMessage) [BKLog assert:assertion message:(aMessage) LOCATION_PARAMETERS]

typedef enum _BKLoggingLevel {
    BKLoggingDebug = 0,
    BKLoggingInfo = 10,
    BKLoggingWarn = 20,
    BKLoggingError = 30,
    BKLoggingFatal = 40
} BKLoggingLevel;

@interface BKLog : NSObject {

}

+ (BKLoggingLevel)loggingLevel;
+ (void)setLoggingLevel:(BKLoggingLevel)level;
+ (BOOL)isDebugEnabled;
+ (BOOL)isInfoEnabled;

+ (void)debug:(NSString *)message lineNumber:(int)lineNumber fileName:(char *)fileName methodName:(char *)methodName;
+ (void)info:(NSString *)message lineNumber:(int)lineNumber fileName:(char *)fileName methodName:(char *)methodName;
+ (void)warn:(NSString *)message lineNumber:(int)lineNumber fileName:(char *)fileName methodName:(char *)methodName;
+ (void)error:(NSString *)message lineNumber:(int)lineNumber fileName:(char *)fileName methodName:(char *)methodName;
+ (void)error:(NSString *)message exception:(NSException *)exception lineNumber:(int)lineNumber fileName:(char *)fileName methodName:(char *)methodName;
+ (void)fatal:(NSString *)message lineNumber:(int)lineNumber fileName:(char *)fileName methodName:(char *)methodName;
+ (void)assert:(BOOL)assertion message:(NSString *)message lineNumber:(int)lineNumber fileName:(char *)fileName methodName:(char *)methodName;
+ (void)log:(NSString *)type message:(NSString *)message lineNumber:(int)lineNumber fileName:(char *)fileName methodName:(char *)methodName;

@end
