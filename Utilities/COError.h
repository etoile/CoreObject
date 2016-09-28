/**
    Copyright (C) 2012 Quentin Mathe

    Date:  May 2012
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

/** 
 * @group Utilities
 * @abstract NSError subclass to report multiple errors or a validation result
 *
 * <list>
 * <item>An aggregate error contains suberrors in -errors (a suberror can 
 * contain other suberrors).</item>
 * <item>A validation error contains a validation issue in -validationResult.</item>
 * </list>
 *
 * COError is used by CoreObject validation support such as 
 * -[COObject validate] and COEditingContext commit methods such as 
 * -[COEditingContext commitWithIdentifier:metadata:undoTrack:error:].
 *
 * -[COError domain] returns kCOCoreObjectErrorDomain.
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
 *
 * Returns nil when the error array is empty.
 */
+ (instancetype)errorWithErrors: (id <ETCollection>)suberrors;
/**
 * Returns a new autoreleased error based on a validation result.
 */
+ (instancetype)errorWithValidationResult: (ETValidationResult *)aResult;
/**
 * Returns new autoreleased error array where every error corresponds to 
 * validation result.
 */
+ (NSArray *)errorsWithValidationResults: (id <ETCollection>)errors;
/**
 * Returns a new autoreleased error that includes validations results put into 
 * suberrors.
 */
+ (instancetype)errorWithValidationResults: (id <ETCollection>)errors;


/** @taskunit Basic Properties */


/**
 * Returns the suberrors.
 *
 * An error that reports a -validationResult will return always an empty array.
 *
 * When the suberrors are validation errors, -code returns   
 * kCOValidationMultipleErrorsError.
 */
@property (nonatomic, readonly) NSArray *errors;
/**
 * Returns a validation result.
 *
 * An error that contains suberrors with -errors will always return nil.
 *
 * When the validation result is not nil, -code returns kCOValidationError.
 */
@property (nonatomic, readonly) ETValidationResult *validationResult;

@end

/**
 * The error domain to identity errors emitted by CoreObject itself, and not 
 * some other layers such as Foundation or POSIX.
 */
extern NSString *kCOCoreObjectErrorDomain;
/**
 * See -[COError validationResult].
 */
extern NSInteger kCOValidationError;
/**
 * See -[COError errors].
 */
extern NSInteger kCOValidationMultipleErrorsError;
