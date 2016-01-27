/*
	Copyright (C) 2016 Quentin Mathe

	Date:  January 2016
	License:  MIT  (nonatomic, see COPYING)
 */

#import <Foundation/Foundation.h>
#import <CoreObject/CoreObject.h>

@interface Person : COObject

@property (nonatomic, strong) NSString *role;
@property (nonatomic, strong) NSString *summary;
@property (nonatomic, assign) NSInteger age;
@property (nonatomic, strong) NSData *iconData;

@property (nonatomic, strong) NSString *streetAddress;
@property (nonatomic, strong) NSString *city;
@property (nonatomic, strong) NSString *administrativeArea;
@property (nonatomic, strong) NSString *postalCode;
@property (nonatomic, strong) NSString *country;

@property (nonatomic, strong) NSString *phoneNumber;
@property (nonatomic, strong) NSString *emailAddress;
@property (nonatomic, strong) NSURL *website;

@property (nonatomic, strong) NSArray *stuff;
@property (nonatomic, strong) NSSet *teachers;
@property (nonatomic, strong) NSSet *students;

@end
