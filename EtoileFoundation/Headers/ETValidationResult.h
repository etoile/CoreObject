/*
 ETValidationResult.h

 Copyright (C) 2009 Eric Wasylishen
 
 Author:  Eric Wasylishen <ewasylishen@gmail.com>
 Date:  July 2009
 License:  Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>

/**
 * Helper class used as the return value of a validation, rather than passing
 * pointers to objects and modifying them.
 */
@interface ETValidationResult : NSObject
{
	id _object;
	NSString *_error;
	BOOL _isValid;
}
+ (id) validResult: (id)value;
+ (id) invalidResultWithError: (NSString *)error;
+ (id) validationResultWithValue: (id)value
                         isValid: (BOOL)isValid
                           error: (NSString *)error;
- (id) initWithValue: (id)value
             isValid: (BOOL)isValid
               error: (NSString *)error;
- (id) value;
- (BOOL) isValid;
- (NSString *) error;

@end
