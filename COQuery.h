/*
	Copyright (C) 2011 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2011
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

/** 
 * @group Query
 * @abstract A NSPredicate-based query to be run in memory or in store as a SQL 
 * statement.
 *
 * COQuery is provided to search the core objects either in store through 
 * -[COStore resultDictionariesForQuery:] or in memory through the 
 * COObjectMatching protocol. 
 *
 * It allows to combine a predicate or a raw SQL query with various additional 
 * constraints, and control how the search results are returned.
 */
@interface COQuery : NSObject
{
	NSPredicate *predicate;
	NSString *SQLString;
	BOOL matchesAgainstObjectsInMemory;
}

/** @taskunit Initialization */

/**
 * Returns a new autoreleased query that uses a predicate.
 */
+ (COQuery *)queryWithPredicate: (NSPredicate *)aPredicate;
/**
 * Returns a new autoreleased query that uses a SQL request.
 */
+ (COQuery *)queryWithSQLString: (NSString *)aSQLString;

/** @taskunit Query Representations */

/**
 * The predicate that expresses the query.
 */
@property (nonatomic, retain) NSPredicate *predicate;
/**
 * Returns a SQL representation that can be passed to the COStore API.
 */
@property (nonatomic, retain, readonly) NSString *SQLString;

/** @taskunit Query Constraints */

/**
 * Determines whether the objects in memory should be searched directly, rather 
 * than turning the predicate into a SQL query and evaluates it against the store.
 *
 * When set to YES, the objects are loaded lazily while traversing the object 
 * graph bound the object on which the query was started with 
 * -[COObjectMatching objectsMatchingQuery:].
 *
 * If no predicate is set, this property is ignored.
 *
 * By default, returns NO.
 *
 * See also -[COObjectMatching matchesPredicate:].
 */
@property (nonatomic, assign) BOOL matchesAgainstObjectsInMemory;

@end

/**
 * Protocol to search objects directly in memory with COQuery.
 */
@protocol COObjectMatching
/**
 * Returns whether the receiver matches the predicate conditions.
 */
- (BOOL)matchesPredicate: (NSPredicate *)aPredicate;
/**
 * Returns the objects matching the query conditions.
 *
 * Must be implemented by recursively traversing the object graph each time 
 * the receiver has a relationship which makes sense to search.
 */
- (NSArray *)objectsMatchingQuery: (COQuery *)aQuery;
@end
