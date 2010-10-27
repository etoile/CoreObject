/*
 ETValidationResult.m
 
 Copyright (C) 2009 Eric Wasylishen
 
 Author:  Eric Wasylishen <ewasylishen@gmail.com>
 Date:  July 2009
 License:  Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>
#import "ETValidationResult.h"
#import "Macros.h"
#import "EtoileCompatibility.h"

/**
 * Helper class used as the return value of a validation, rather than passing
 * pointers to objects and modifying them.
 */
@implementation ETValidationResult
+ (id) validResult: (id)value
{
	return [[[ETValidationResult alloc] initWithValue: value
											  isValid: YES
												error: nil] autorelease];
}
+ (id) invalidResultWithError: (NSString *)error
{
	return [[[ETValidationResult alloc] initWithValue: nil
											  isValid: NO
												error: error] autorelease];
}
+ (id) validationResultWithValue: (id)value
                         isValid: (BOOL)isValid
                           error: (NSString *)error
{
	return [[[ETValidationResult alloc] initWithValue: value
											  isValid: isValid
												error: error] autorelease];
}
- (id) initWithValue: (id)value
             isValid: (BOOL)isValid
               error: (NSString *)error
{
	SUPERINIT;
	ASSIGN(_object, value);
	_isValid = isValid;
	ASSIGN(_error, error);
	return self;
}
- (void) dealloc
{
	DESTROY(_object);
	DESTROY(_error);
	[super dealloc];
}
- (id) value
{
	return _object;
}
- (BOOL) isValid
{
	return _isValid;
}
- (NSString *) error
{
	return _error;
}

@end
