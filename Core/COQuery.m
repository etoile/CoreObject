/*
	Copyright (C) 2011 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2011
	License:  Modified BSD  (see COPYING)

 */

#import "COQuery.h"

@implementation COQuery

@synthesize predicate, SQLString, matchesAgainstObjectsInMemory;

+ (COQuery *)queryWithPredicate: (NSPredicate *)aPredicate
{
	COQuery *query = AUTORELEASE([[COQuery alloc] init]);
	[query setPredicate: aPredicate];
	return query;
}

+ (COQuery *)queryWithPredicateBlock: (BOOL (^)(id object, NSDictionary *bindings))aBlock
{
	COQuery *query = AUTORELEASE([[COQuery alloc] init]);
	[query setPredicate: [NSPredicate predicateWithBlock: aBlock]];
	return query;
}

+ (COQuery *)queryWithSQLString: (NSString *)aSQLString
{
	COQuery *query = AUTORELEASE([[COQuery alloc] init]);
	ASSIGN(query->SQLString, aSQLString);
	return query;
}

- (void)dealloc
{
	DESTROY(predicate);
	DESTROY(SQLString);
	[super dealloc];
}

- (NSString *) SQLString
{
	if (SQLString != nil)
		return SQLString;

	// TODO: Generate a SQL representation
	return nil;
}

@end
