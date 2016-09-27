/*
    Copyright (C) 2016 Quentin Mathe

    Date:  January 2016
    License:  MIT  (nonatomic, see COPYING)
 */

#import <Foundation/Foundation.h>
#import <CoreObject/CoreObject.h>

@interface Person : COObject

@property (nonatomic, readwrite, copy) NSString *role;
@property (nonatomic, readwrite, copy) NSString *summary;
@property (nonatomic, readwrite, assign) NSInteger age;
@property (nonatomic, readwrite, strong) NSData *iconData;

@property (nonatomic, readwrite, copy) NSString *streetAddress;
@property (nonatomic, readwrite, copy) NSString *city;
@property (nonatomic, readwrite, copy) NSString *administrativeArea;
@property (nonatomic, readwrite, copy) NSString *postalCode;
@property (nonatomic, readwrite, copy) NSString *country;

@property (nonatomic, readwrite, copy) NSString *phoneNumber;
@property (nonatomic, readwrite, copy) NSString *emailAddress;
@property (nonatomic, readwrite, copy) NSURL *website;

@property (nonatomic, readwrite, copy) NSArray *stuff;
@property (nonatomic, readwrite, copy) NSSet *teachers;
@property (nonatomic, readwrite, copy) NSSet *students;

@end
