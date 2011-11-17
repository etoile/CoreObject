/*
	Copyright (C) 2011 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>, Yen-Ju Chen
	Date:  November 2011
	License:  Modified BSD  (see COPYING)
	
	COObjectMatching protocol and its concrete implementations are based on 
	MIT-licensed code by Yen-Ju Chen <yjchenx gmail> from the previous CoreObject.
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


@implementation COObject (COObjectMatching)

- (BOOL)matchesPredicate: (NSPredicate *)aPredicate
{
	NILARG_EXCEPTION_TEST(aPredicate);

	BOOL result = NO;

	if ([aPredicate isKindOfClass: [NSCompoundPredicate class]])
	{
		NSCompoundPredicate *cp = (NSCompoundPredicate *)aPredicate;
		NSArray *subs = [cp subpredicates];
		int i, count = [subs count];

		switch ([cp compoundPredicateType])
		{
			case NSNotPredicateType:
				result = ![self matchesPredicate: [subs objectAtIndex: 0]];
				break;
			case NSAndPredicateType:
				result = YES;
				for (i = 0; i < count; i++)
				{
					result = result && [self matchesPredicate: [subs objectAtIndex: i]];
				}
				break;
			case NSOrPredicateType:
				result = NO;
				for (i = 0; i < count; i++)
				{
					result = result || [self matchesPredicate: [subs objectAtIndex: i]];
				}
				break;
			default: 
				ETLog(@"Error: Unknown compound predicate type");
		}
	}
	else if ([aPredicate isKindOfClass: [NSComparisonPredicate class]])
	{
		NSComparisonPredicate *cp = (NSComparisonPredicate *)aPredicate;
		id lv = [[cp leftExpression] expressionValueWithObject: self context: nil];
		id rv = [[cp rightExpression] expressionValueWithObject: self context: nil];
		NSArray *array = nil;

		if ([lv isKindOfClass: [NSArray class]] == NO)
		{
			array = [NSArray arrayWithObjects: lv, nil];
		}
		else
		{
			array = (NSArray *) lv;
		}
		NSEnumerator *e = [array objectEnumerator];
		id v = nil;
		while ((v = [e nextObject]))
		{
			switch ([cp predicateOperatorType])
			{
				case NSLessThanPredicateOperatorType:
					return ([v compare: rv] == NSOrderedAscending);
				case NSLessThanOrEqualToPredicateOperatorType:
					return ([v compare: rv] != NSOrderedDescending);
				case NSGreaterThanPredicateOperatorType:
				return ([v compare: rv] == NSOrderedDescending);
				case NSGreaterThanOrEqualToPredicateOperatorType:
					return ([v compare: rv] != NSOrderedAscending);
				case NSEqualToPredicateOperatorType:
					return [v isEqual: rv];
				case NSNotEqualToPredicateOperatorType:
					return ![v isEqual: rv];
				case NSMatchesPredicateOperatorType:
					{
						// FIXME: regular expression
						return NO;
					}
				case NSLikePredicateOperatorType:
					{
						// FIXME: simple regular expression
						return NO;
					}
				case NSBeginsWithPredicateOperatorType:
					return [[v description] hasPrefix: [rv description]];
				case NSEndsWithPredicateOperatorType:
					return [[v description] hasSuffix: [rv description]];
				case NSInPredicateOperatorType:
					// NOTE: it is the reverse CONTAINS
					return ([[rv description] rangeOfString: [v description]].location != NSNotFound);;
				case NSCustomSelectorPredicateOperatorType:
					{
						// FIXME: use NSInvocation
						return NO;
					}
				default:
					NSLog(@"Error: Unknown predicate operator");
			}
		}
	}
	return result;
}

- (NSArray *)objectsMatchingQuery: (COQuery *)aQuery
{
	return ([self matchesPredicate: [aQuery predicate]] ? A(self) : [NSArray array]);
}

@end


@implementation COGroup (COObjectMatching)

- (NSArray *)objectsMatchingQuery: (COQuery *)aQuery
{
	NSMutableArray *result = [NSMutableArray array];

	for (COObject *object in [self content])
	{
		if ([object matchesPredicate: [aQuery predicate]])
		{
			[result addObject: object];
		}
	}

	return result;
}

@end
