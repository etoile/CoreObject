/**
    Copyright (C) 2015 Quentin Mathe

    Date:  January 2015
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>

/**
 * The exception raised by COJSONObjectWithData() and CODataWithJSONObject() 
 * on a serialization or deserialization error, when the error is not handled.
 */
extern NSString * const COJSONSerializationException;

/**
 * Deserializes the given data into a JSON object.
 *
 * For a NULL error argument, raises a COJSONSerializationException on an error,
 * otherwise returns the error by reference.
 */
id COJSONObjectWithData(NSData *data, NSError **anError);

/**
 * Serializes the given JSON object into data.
 *
 * For a NULL error argument, raises a COJSONSerializationException on an error, 
 * otherwise returns the error by reference.
 */
NSData *CODataWithJSONObject(id JSONObject, NSError **anError);
