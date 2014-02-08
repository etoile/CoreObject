/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import "COAttachmentID.h"
#import <EtoileFoundation/Macros.h>

@implementation COAttachmentID

- (id) init
{
	[NSException raise: NSGenericException format: @"Must use designated initializer -initWithData:"];
	return nil;
}

- (id) initWithData:(NSData *)aData
{
	SUPERINIT;
	_data = [aData copy];
	return self;
}

- (NSData *) dataValue
{
	return _data;
}

- (NSUInteger) hash
{
	return [_data hash];
}

- (BOOL) isEqual:(id)object
{
	if (![object isKindOfClass: [COAttachmentID class]])
		return NO;
	
	return [_data isEqual: [object dataValue]];
}

- (id) copyWithZone:(NSZone *)zone
{
	return self;
}

@end
