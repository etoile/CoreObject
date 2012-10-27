/** 
   Copyright (C) 2005 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date:	Nov 2005
   
   This file is part of the Performance Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   $Date$ $Revision$
   */ 

#ifndef	INCLUDED_GSTicker_H
#define	INCLUDED_GSTicker_H

@class	NSDate;

/**
 * Returns the timestamp of the most recent call to GSTickerTimeNow().
 */
extern NSTimeInterval GSTickerTimeLast();

/**
 * Convenience function to provide timing information quickly.<br />
 * This returns the current date/time, and stores the value for use
 * by the GSTickerTimeLast() function.
 */
extern NSTimeInterval	GSTickerTimeNow();

/**
 * This returns the timestamp from which GSTicker was first used.
 */
extern NSTimeInterval	GSTickerTimeStart();

/**
 * A convenience method to return the current clock 'tick' ... which is
 * the current second based on the time we started.  This does <em>not</em>
 * check the current time, but relies on GSTickerTimeLast() returning an
 * up to date value (so if you need an accurate tick, you should ensure
 * that GSTickerTimeNow() is called at least once a second).<br />
 * The returned value is always greater than zero, and is basically
 * calculated as (GSTickerTimeLast() - GSTickerTimeStart() + 1).<br />
 * In the event that the system clock is reset into the past, the value
 * of GSTickerTimeStart() is automatically adjusted to ensure that the
 * result of a call to GSTickerTimeTick() is never less than the result
 * of any earlier call to the function.
 */
extern unsigned	GSTickerTimeTick();


@protocol	GSTicker<NSObject>
/**
 * Sent to tell observers that the ticker has noticed that a new
 * second has occurred.  The tick argument is the user information
 * provided in when registering the observer.<br />
 * This message is sent to each registered observer when the timeout
 * for the thread occurs.  It is not guaranteed to be called every
 * second ... other processing in the thread may delay it.
 */
- (void) newSecond: (id)userInfo;
@end

/**
 * Wrapper round the more efficient ticker functions ... this class
 * provides convenience methods to get NSDate objects, and also
 * provides support for registering observers ofr second by second
 * ticks.
 */
@interface	GSTicker : NSObject <GSTicker>
{
}

/**
 * Calls GSTickerTimeLast() and returns the result as an NSDate.
 */
+ (NSDate*) last;

/**
 * A dummy method ... does nothing, but allows the GSTicker class itsself
 * to act as an observer of regular timeouts.<br />
 * Thus, you may register the class as its own observer in order to set
 * up a timer to ensure that date/time information is updated at the
 * start of every second.
 */
+ (void) newSecond: (id)userInfo;

/**
 * Calls GSTickerTimeNow() and returns the result as an NSDate.
 */
+ (NSDate*) now;

/**
 * Registers an object to receive a [(GSTicker)-newSecond:] message
 * at the start of every second.<br />
 * Also starts a timer in the current thread (unless one is already
 * running) to notify registered objects of new seconds.<br />
 * The observer and the userInfo are retained by the ticker.<br />
 * Adding an observer more than once has no effect.<br />
 * NB. You must not add or remove observers inside the callback routine.
 */
+ (void) registerObserver: (id<GSTicker>)anObject
		 userInfo: (id)userInfo;

/**
 * Returns the result of GSTickerTimeStart() as an NSDate.
 */
+ (NSDate*) start;

/**
 * Calls GSTickerTimeTick() and returns the result.
 */
+ (unsigned) tick;

/**
 * Unregisters an observer previously set in the current thread using
 * the +registerObserver:userInfo: method.<br />
 * If all observers in a thread are removed, the timer for the thread
 * is cancelled at the start of the next second.
 */
+ (void) unregisterObserver: (id<GSTicker>)anObject;

/**
 * Calls GSTickerTimeNow();
 */
+ (void) update;

/**
 * Calls GSTickerTimeLast() and returns the result as an NSDate.
 */
- (NSDate*) last;

/**
 * See +newSecond:
 */
- (void) newSecond: (id)userInfo;

/**
 * Calls GSTickerTimeNow() and returns the result as an NSDate.
 */
- (NSDate*) now;

/**
 * Returns the result of GSTickerTimeStart() as an NSDate.
 */
- (NSDate*) start;

/**
 * Calls GSTickerTimeTick() and returns the result.
 */
- (unsigned) tick;

/**
 * Calls GSTickerTimeNow();
 */
- (void) update;

@end

#endif

