/*
	Copyright (C) 2012 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  May 2012
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

/** 
 * @group Error
 * @abstract NSError subclass to collect and report validation results
 *
 * COError is used by CoreObject validation support such as 
 * -[COObject validateForUpdate] and -[COEditingContext error] which reports 
 * errors related to the last commit attempt.
 */
@interface COError : NSError
{
	@private
	ETValidationResult *validationResult;
	NSArray *errors;
}

/** @taskunit Initialization */

/**
 * Returns a new autoreleased error that includes suberrors.
 */
+ (id)errorWithErrors: (NSArray *)errors;
/**
 * Returns a new autoreleased error based on a validation result.
 */
+ (id)errorWithValidationResult: (ETValidationResult *)aResult;
/**
 * Returns new autoreleased error array where every error corresponds to 
 * validation result.
 */
+ (NSArray *)errorsWithValidationResults: (NSArray *)errors;
/**
 * Returns a new autoreleased error that includes validations results put into 
 * suberrors.
 */
+ (id)errorWithValidationResults: (NSArray *)errors;

/** @taskunit Basic Properties */

/**
 * Returns the suberrors.
 */
@property (nonatomic, readonly) NSArray *errors;
/**
 * Returns an validation result if the receiver is a validation error.
 */
@property (nonatomic, readonly) ETValidationResult *validationResult;

@end


extern NSString *kCOCoreObjectErrorDomain;
extern NSInteger kCOValidationError;
extern NSInteger kCOValidationMultipleErrorsError;
