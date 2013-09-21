/*
	Copyright (C) 2013 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  March 2013
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

/** 
 * @group Object Collection and Organization
 *
 * I'd like to deprecate this, these encourage bad style (violating the tell-don't-ask principle
 * http://pragprog.com/articles/tell-dont-ask ) and methods should almost never be added to NSObject IMHO.
 */
@interface NSObject (CoreObject)

/** @taskunit Type Querying */

/**
 * Returns whether the receiver is an editing context or not.
 *
 * See also -[COEditingContext isEditingContext].
 */
- (BOOL)isEditingContext;
/**
 * Returns whether the receiver is a persistent root or not.
 *
 * See also -[COPersistentRoot isPersistentRoot].
 */
- (BOOL)isPersistentRoot;
/**
 * Returns whether the receiver is an object graph context or not.
 *
 * See also -[COObjectGraphContext isObjectGraphContext].
 */
- (BOOL)isObjectGraphContext;

@end
