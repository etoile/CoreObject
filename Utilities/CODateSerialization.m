/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  October 2013
    License:  MIT  (see COPYING)
 */

#import "CODateSerialization.h"

/**
 * Rationale for presisting dates in Java's format (milliseconds since 1970-Jan-01):
 * - widely used
 * - int64_t, so can write exactly in base 10 unlike a double
 * - millisecond precision is good enough for our needs
 */
NSNumber *CODateToJavaTimestamp(NSDate *aDate)
{
    if (aDate == nil)
        [NSException raise: NSInvalidArgumentException
                    format: @"CODateToJavaTimestamp() requires a non-nil date"];

    const long long int javaDate = llrint(aDate.timeIntervalSince1970 * 1000.0);

    return @(javaDate);
}

NSDate *CODateFromJavaTimestamp(NSNumber *aNumber)
{
    if (aNumber == nil)
        [NSException raise: NSInvalidArgumentException
                    format: @"CODateFromJavaTimestamp() requires a non-nil date"];

    const long long int javaDate = aNumber.longLongValue;

    return [NSDate dateWithTimeIntervalSince1970: javaDate / 1000.0];
}
