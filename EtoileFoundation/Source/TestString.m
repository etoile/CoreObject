/*
	Copyright (C) 2008 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  July 2008
	License: Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "NSString+Etoile.h"
#import "EtoileCompatibility.h"

@interface TestString : NSObject <UKTest>
@end

@implementation TestString

- (void) testStringBySpacingCapitalizedWords
{
	id string1 = @"layout";
	id string2 = @"myFunnyLayout";
	UKStringsEqual(string1, [string1 stringBySpacingCapitalizedWords]);
	UKStringsEqual(@"my Funny Layout", [string2 stringBySpacingCapitalizedWords]);

	string1 = @"Layout";
	string2 = @"MyFunnyLayout";
	id string3 = @"MyFunnyLayoutZ";
	UKStringsEqual(string1, [string1 stringBySpacingCapitalizedWords]);
	UKStringsEqual(@"My Funny Layout", [string2 stringBySpacingCapitalizedWords]);
	UKStringsEqual(@"My Funny Layout Z", [string3 stringBySpacingCapitalizedWords]);

	string1 = @"XMLNode";
	string2 = @"unknownXMLNodeURL";
	UKStringsEqual(@"XML Node", [string1 stringBySpacingCapitalizedWords]);
	UKStringsEqual(@"unknown XML Node URL", [string2 stringBySpacingCapitalizedWords]);
}

@end

