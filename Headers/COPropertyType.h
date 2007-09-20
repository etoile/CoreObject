/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>

#define kCOMultiValueMask 0x100

typedef enum _COPropertyType {
   kCOErrorInProperty           = 0x0,
   kCOStringProperty            = 0x1,
   kCOIntegerProperty           = 0x2,
   kCORealProperty              = 0x3,
   kCODateProperty              = 0x4,
   kCOArrayProperty             = 0x5,
   kCODictionaryProperty        = 0x6,
   kCODataProperty              = 0x7,
   kCOMultiStringProperty       = kCOMultiValueMask | kCOStringProperty,
   kCOMultiIntegerProperty      = kCOMultiValueMask | kCOIntegerProperty,
   kCOMultiRealProperty         = kCOMultiValueMask | kCORealProperty,
   kCOMultiDateProperty         = kCOMultiValueMask | kCODateProperty,
   kCOMultiArrayProperty        = kCOMultiValueMask | kCOArrayProperty,
   kCOMultiDictionaryProperty   = kCOMultiValueMask | kCODictionaryProperty,
   kCOMultiDataProperty         = kCOMultiValueMask | kCODataProperty
} COPropertyType;

