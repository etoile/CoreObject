/*
    Copyright (C) 2015 Quentin Mathe

    Date:  January 2015
    License:  MIT  (see COPYING)
 */

#import "COJSONSerialization.h"

NSString *const COJSONSerializationException = @"COJSONSerializationException";

id COJSONObjectWithData(NSData *data, NSError **anError)
{
    NSError *error = nil;
    id JSONObject = [NSJSONSerialization JSONObjectWithData: data options: 0 error: &error];

    if (anError != NULL)
    {
        *anError = error;
    }
    else if (error != nil)
    {
        [NSException raise: COJSONSerializationException
                    format: @"Failed to deserialize JSON due to %@", error];
    }
    return JSONObject;
}

NSData *CODataWithJSONObject(id JSONObject, NSError **anError)
{
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject: JSONObject options: 0 error: &error];

    if (anError != NULL)
    {
        *anError = error;
    }
    else if (error != nil)
    {
        [NSException raise: COJSONSerializationException
                    format: @"Failed to serialize JSON due to %@", error];
    }
    return data;
}
