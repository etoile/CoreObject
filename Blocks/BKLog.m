//
//  BKLog.m
//  Blocks
//
//  Created by Jesse Grosjean on 3/29/05.
//  Copyright 2005 Hog Bay Software. All rights reserved.
//

#import "BKLog.h"


@implementation BKLog

static BKLoggingLevel LoggingLevel = BKLoggingWarn;

+ (BKLoggingLevel)loggingLevel {
	return LoggingLevel;
}

+ (void)setLoggingLevel:(BKLoggingLevel)level {
	LoggingLevel = level;
}

+ (BOOL)isDebugEnabled {
	return YES;
}

+ (BOOL)isInfoEnabled {
	return YES;
}

+ (void)debug:(NSString *)message lineNumber:(int)lineNumber fileName:(char *)fileName methodName:(char *)methodName {
	if ([self loggingLevel] <= BKLoggingDebug)
		[self log:@"DEBUG" message:message lineNumber:lineNumber fileName:fileName methodName:methodName];
}

+ (void)info:(NSString *)message lineNumber:(int)lineNumber fileName:(char *)fileName methodName:(char *)methodName {
	if ([self loggingLevel] <= BKLoggingInfo)
		[self log:@"INFO" message:message lineNumber:lineNumber fileName:fileName methodName:methodName];
}

+ (void)warn:(NSString *)message lineNumber:(int)lineNumber fileName:(char *)fileName methodName:(char *)methodName {
	if ([self loggingLevel] <= BKLoggingWarn)
		[self log:@"WARN" message:message lineNumber:lineNumber fileName:fileName methodName:methodName];
}

+ (void)error:(NSString *)message lineNumber:(int)lineNumber fileName:(char *)fileName methodName:(char *)methodName {
	if ([self loggingLevel] <= BKLoggingError)
		[self log:@"ERROR" message:message lineNumber:lineNumber fileName:fileName methodName:methodName];
}

+ (void)error:(NSString *)message exception:(NSException *)exception lineNumber:(int)lineNumber fileName:(char *)fileName methodName:(char *)methodName {
	if ([self loggingLevel] <= BKLoggingError)
		[self log:@"ERROR" message:message lineNumber:lineNumber fileName:fileName methodName:methodName];
}

+ (void)fatal:(NSString *)message lineNumber:(int)lineNumber fileName:(char *)fileName methodName:(char *)methodName {
	if ([self loggingLevel] <= BKLoggingFatal)
		[self log:@"FATAL" message:message lineNumber:lineNumber fileName:fileName methodName:methodName];
}

+ (void)assert:(BOOL)assertion message:(NSString *)message lineNumber:(int)lineNumber fileName:(char *)fileName methodName:(char *)methodName {
	if (!assertion) [self log:@"ASSERT" message:message lineNumber:lineNumber fileName:fileName methodName:methodName];
}

+ (void)log:(NSString *)type message:(NSString *)message lineNumber:(int)lineNumber fileName:(char *)fileName methodName:(char *)methodName {
	NSLog(@"%@ %s - %@", type, methodName, message);
}

@end
