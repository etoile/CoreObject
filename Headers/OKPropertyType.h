/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>

#define kOKMultiValueMask 0x100

typedef enum _OKPropertyType {
   kOKErrorInProperty           = 0x0,
   kOKStringProperty            = 0x1,
   kOKIntegerProperty           = 0x2,
   kOKRealProperty              = 0x3,
   kOKDateProperty              = 0x4,
   kOKArrayProperty             = 0x5,
   kOKDictionaryProperty        = 0x6,
   kOKDataProperty              = 0x7,
   kOKMultiStringProperty       = kOKMultiValueMask | kOKStringProperty,
   kOKMultiIntegerProperty      = kOKMultiValueMask | kOKIntegerProperty,
   kOKMultiRealProperty         = kOKMultiValueMask | kOKRealProperty,
   kOKMultiDateProperty         = kOKMultiValueMask | kOKDateProperty,
   kOKMultiArrayProperty        = kOKMultiValueMask | kOKArrayProperty,
   kOKMultiDictionaryProperty   = kOKMultiValueMask | kOKDictionaryProperty,
   kOKMultiDataProperty         = kOKMultiValueMask | kOKDataProperty
} OKPropertyType;

