/**
    Copyright (C) 2013 Quentin Mathe

    Date:  March 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class COEditingContext;

// I'm skeptical that there is ever a legitimate case where code is working
// with an id<COPersistentObjectContext> and doesn't know whether it's an
// editing context or persistent root... but I guess it's harmless to keep for
// now --Eric

/**
 * @group Core
 * Protocol to support managing either persistent roots or inner objects
 * inside an object graph context without knowing the context type in advance.
 *
 * For example, based on -[ETController persistentObjectContext:], a 
 * ETController object can instantiate either persistent roots or inner objects.
 */
@protocol COPersistentObjectContext <NSObject>
@optional
/**
 * See -[NSObject isEditingContext].
 */
@property (nonatomic, readonly) BOOL isEditingContext;
/**
 * See -[NSObject isObjectGraphContext].
 */
@property (nonatomic, readonly) BOOL isObjectGraphContext;
@required
/**
 * Returns the editing context for the receiver.
 *
 * Either returns self or a parent context.
 *
 * See COEditingContext and -[COPersistentRoot parentContext].
 */
@property (nonatomic, readonly) COEditingContext *editingContext;
/**
 * See -[COEditingContext discardAllChanges], -[COPersistentRoot discardAllChanges], 
 * -[COBranch discardAllChanges] and -[COObjectGraphContext discardAllChanges].
 */
- (void)discardAllChanges;
/**
 * See -[COEditingContext hasChanges], -[COPersistentRoot hasChanges], 
 *  -[COBranch hasChanges] and -[COObjectGraphContext hasChanges].
 */
@property (nonatomic, readonly) BOOL hasChanges;
@end

/** 
 * @group Core
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
@property (nonatomic, readonly) BOOL isEditingContext;
/**
 * Returns whether the receiver is a persistent root or not.
 *
 * See also -[COPersistentRoot isPersistentRoot].
 */
@property (nonatomic, readonly) BOOL isPersistentRoot;
/**
 * Returns whether the receiver is an object graph context or not.
 *
 * See also -[COObjectGraphContext isObjectGraphContext].
 */
@property (nonatomic, readonly) BOOL isObjectGraphContext;

@end
