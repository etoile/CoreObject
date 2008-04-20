/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <EtoileFoundation/Macros.h>

#define DEFAULTS [NSUserDefaults defaults]
#define FM [NSFileManager defaultManager]

#define IGNORE_CHANGES \
([[self objectContext] shouldIgnoreChangesToObject: self])

#define TEST_IGNORE_CHANGES(returnValue) \
if (IGNORE_CHANGES) return (returnValue);

#define RECORD(...) \
[[self objectContext] recordInvocation: \
	[NSInvocation invocationWithTarget: self \
	                          selector: _cmd \
	                         arguments: A(__VA_ARGS__)]];

#define END_RECORD [[self objectContext] endRecord];
//id context = [object coreObjectContext];
//if ([context containsObject: [context lastRecordedObject]] == NO)
//	record

#define ETBinarySerializerBackend ETSerializerBackendBinary
#define ETBinaryDeserializerBackend ETDeserializerBackendBinary
