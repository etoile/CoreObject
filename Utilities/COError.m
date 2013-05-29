/*
	Copyright (C) 2012 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  May 2012
	License:  Modified BSD  (see COPYING)

 */

#import "COError.h"

@implementation COError

@synthesize errors, validationResult;

- (id)initWithValidationResult: (ETValidationResult *)aResult errors: (id <ETCollection>)suberrors
{
	NILARG_EXCEPTION_TEST(suberrors);
	
	if (aResult == nil && [suberrors isEmpty])
	{
		[self release];
		return nil;
	}

	BOOL isAggregate = ([suberrors isEmpty] == NO);
	self = [super initWithDomain: kCOCoreObjectErrorDomain 
	                        code: (isAggregate ? kCOValidationMultipleErrorsError : kCOValidationError)
	                    userInfo: nil];
	if (self == nil)
		return nil;

	ASSIGN(validationResult, aResult);
	ASSIGN(errors, [suberrors contentArray]);
	return self;
}

- (void)dealloc
{
	DESTROY(errors);
	DESTROY(validationResult);
	[super dealloc];
}

+ (id)errorWithErrors: (id <ETCollection>)errors
{
    return [[[self alloc] initWithValidationResult: nil errors: errors] autorelease];
}

+ (id)errorWithValidationResult: (ETValidationResult *)aResult
{
    return [[[self alloc] initWithValidationResult: aResult errors: [NSArray array]] autorelease];
}

+ (NSArray *)errorsWithValidationResults: (id <ETCollection>)results
{
	NSMutableArray *errors = [NSMutableArray array];

	for (ETValidationResult *result in results)
	{
		[errors addObject: [self errorWithValidationResult: result]];
	}
	return errors;
}

+ (COError *)errorWithValidationResults: (NSArray *)results
{
	return [self errorWithErrors: [self errorsWithValidationResults: results]];
}

@end

NSString *kCOCoreObjectErrorDomain = @"kCOCoreObjectErrorDomain";
NSInteger kCOValidationError = 0;
NSInteger kCOValidationMultipleErrorsError = 1;
