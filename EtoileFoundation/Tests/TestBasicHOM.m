/*
	Copyright (C) 2009 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  June 2009
	License: Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "NSObject+HOM.h"
#import "EtoileCompatibility.h"

@interface TestHOM : NSObject <UKTest>
@end

@implementation TestHOM

- (NSString *) bark
{
	return @"Ouaf";
}

- (void) testIfResponds
{
	id otherObject = AUTORELEASE([[NSObject alloc] init]);

	UKObjectsEqual([self bark], [[self ifResponds] bark]);
	UKNil([[otherObject ifResponds] bark]);

	/* NSProxy implements -description and -class but -className is only 
	   implemented on NSObject (Cocoa scripting addition). */
	UKObjectsNotEqual([self description], [[self ifResponds] description]);
	UKObjectsEqual(NSClassFromString(@"ETIfRespondsProxy"), [[self ifResponds] class]);
	UKObjectsEqual([self className], [[self ifResponds] className]);
}

@end
