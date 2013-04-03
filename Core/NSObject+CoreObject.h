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
 * Returns whether the receiver is a track or not.
 *
 * See also -[COTrack isTrack].
 */
- (BOOL)isTrack;

@end
