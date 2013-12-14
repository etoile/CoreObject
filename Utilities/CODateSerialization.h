/*
    Copyright (C) 2013 Eric Wasylishen

    Author:  Eric Wasylishen <ewasylishen@gmail.com>
    Date:  October 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>

/**
 * Returns an NSNumber wrapping a long long value for the Java timestamp
 * nearest to the given NSDate. A Java timestamp is in milliseconds since
 * 1970-Jan-01 00:00 GMT.
 *
 * Throws an excepetion if given nil.
 */
NSNumber *CODateToJavaTimestamp(NSDate *date);

/**
 * Converts the given NSNumber containing a Java timestamp to an NSDate. 
 * A Java timestamp is in milliseconds since 1970-Jan-01 00:00 GMT.
 *
 * Throws an excepetion if given nil.
 */
NSDate *CODateFromJavaTimestamp(NSNumber *date);