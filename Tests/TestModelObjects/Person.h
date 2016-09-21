/*
	Copyright (C) 2016 Quentin Mathe

	Date:  January 2016
	License:  MIT  (nonatomic, see COPYING)
 */

#import <Foundation/Foundation.h>
#import <CoreObject/CoreObject.h>

@interface Person : COObject

@property (nonatomic, readwrite, strong) NSString *role;
@property (nonatomic, readwrite, strong) NSString *summary;
@property (nonatomic, readwrite, assign) NSInteger age;
@property (nonatomic, readwrite, strong) NSData *iconData;

@property (nonatomic, readwrite, strong) NSString *streetAddress;
@property (nonatomic, readwrite, strong) NSString *city;
@property (nonatomic, readwrite, strong) NSString *administrativeArea;
@property (nonatomic, readwrite, strong) NSString *postalCode;
@property (nonatomic, readwrite, strong) NSString *country;

@property (nonatomic, readwrite, strong) NSString *phoneNumber;
@property (nonatomic, readwrite, strong) NSString *emailAddress;
@property (nonatomic, readwrite, strong) NSURL *website;

@property (nonatomic, readwrite, strong) NSArray *stuff;
@property (nonatomic, readwrite, strong) NSSet *teachers;
@property (nonatomic, readwrite, strong) NSSet *students;

@end
