/*
	Copyright (C) 2011 Quentin Mathe

	Date:  November 2011
	License:  MIT  (see COPYING)
 */

#import "COQuery.h"

@implementation COQuery

@synthesize predicate, SQLString, matchesAgainstObjectsInMemory;

+ (COQuery *)queryWithPredicate: (NSPredicate *)aPredicate
{
	COQuery *query = [[COQuery alloc] init];
	query.predicate = aPredicate;
	return query;
}

#ifndef GNUSTEP
+ (COQuery *)queryWithPredicateBlock: (BOOL (^)(id object, NSDictionary *bindings))aBlock
{
	COQuery *query = [[COQuery alloc] init];
	query.predicate = [NSPredicate predicateWithBlock: aBlock];
	return query;
}
#endif

+ (COQuery *)queryWithSQLString: (NSString *)aSQLString
{
	COQuery *query = [[COQuery alloc] init];
	query->SQLString =  aSQLString;
	return query;
}

- (NSString *) SQLString
{
	if (SQLString != nil)
		return SQLString;

	// TODO: Generate a SQL representation
	return nil;
}

@end
