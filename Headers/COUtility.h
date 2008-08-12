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

// TODO: Move these macros into EtoileFoundation. Ugly hack to workaround 
// multiple definition warnings when both CoreObject and EtoileUI are used
#ifndef ETDebugLog
#ifdef DEBUG_LOG
#define ETDebugLog ETLog
#else
#define ETDebugLog(format, args...)
#endif
#endif

#define RECORD(...) \
int __prevObjectVersion = _objectVersion; \
if (_isPersistencyEnabled) \
{ \
	NSArray *argArray = A(__VA_ARGS__); \
	ETDebugLog(@" ++ Will try record %@ on %@ with %@", NSStringFromSelector(_cmd), self, argArray); \
	_objectVersion = [[self objectContext] recordInvocation: \
	                 [NSInvocation invocationWithTarget: self \
	                                           selector: _cmd \
	                                          arguments: argArray]]; \
}

#define END_RECORD \
if (__prevObjectVersion != _objectVersion) \
	[[self objectContext] endRecord];
//id context = [object coreObjectContext];
//if ([context containsObject: [context lastRecordedObject]] == NO)
//	record

#define ETBinarySerializerBackend ETSerializerBackendBinary
#define ETBinaryDeserializerBackend ETDeserializerBackendBinary
