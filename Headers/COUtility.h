/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <EtoileFoundation/Macros.h>

#define DEFAULTS [NSUserDefaults standardUserDefaults]
#define FM [NSFileManager defaultManager]

#define IGNORE_CHANGES \
([[self objectContext] shouldIgnoreChangesToObject: self])

#define TEST_IGNORE_CHANGES(returnValue) \
if (IGNORE_CHANGES) return (returnValue);

#ifndef ETDebugLog
#define ETDebugLog ETLog
#endif

#define RECORD(...) \
NSArray *argArray = A(__VA_ARGS__); \
int __prevObjectVersion = _objectVersion; \
_objectVersion = [[self objectContext] recordInvocation: \
	                 [NSInvocation invocationWithTarget: self \
	                                           selector: _cmd \
	                                          arguments: argArray]];

// ETDebugLog(@" ++ Will try record %@ on %@ with %@", NSStringFromSelector(_cmd), self, argArray);

#define END_RECORD \
if (__prevObjectVersion != _objectVersion) \
	[[self objectContext] endRecord];
//id context = [object coreObjectContext];
//if ([context containsObject: [context lastRecordedObject]] == NO)
//	record

#define ETBinarySerializerBackend ETSerializerBackendBinary
#define ETBinaryDeserializerBackend ETDeserializerBackendBinary
