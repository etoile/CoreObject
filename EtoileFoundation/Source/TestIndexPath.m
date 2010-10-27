/*
	Copyright (C) 2008 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  July 2008
	License: Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "NSIndexPath+Etoile.h"
#import "EtoileCompatibility.h"

@interface TestIndexPath : NSObject <UKTest>
@end

@implementation TestIndexPath

- (void) testIndexPathByRemovingFirstIndex
{
	id indexPath1 = [[NSIndexPath indexPathWithIndex: 5] indexPathByAddingIndex: 2];
	id indexPath2 = [indexPath1 indexPathByRemovingFirstIndex];

	UKIntsEqual(2, [indexPath2 firstIndex]);
	UKIntsEqual(NSNotFound, [[indexPath2 indexPathByRemovingFirstIndex] firstIndex]);
}

- (void) testIndexPathByJoiningIndexWithSeparator
{
	id indexPath1 = [NSIndexPath indexPathWithIndex: 5];
	id indexPath2 = [indexPath1 indexPathByAddingIndex: 0];
	id indexPath3 = [indexPath2 indexPathByAddingIndex: 7];

	UKStringsEqual(@"", [[NSIndexPath indexPath] stringByJoiningIndexPathWithSeparator: @"."]);

	UKStringsEqual(@"5", [indexPath1 stringByJoiningIndexPathWithSeparator: @"."]);
	UKStringsEqual(@"5.0", [indexPath2 stringByJoiningIndexPathWithSeparator: @"."]);
	
	UKStringsEqual(@"5", [indexPath1 stringByJoiningIndexPathWithSeparator: @"/"]);
	UKStringsEqual(@"5/0/7", [indexPath3 stringByJoiningIndexPathWithSeparator: @"/"]);

	UKStringsEqual(@"5", [indexPath1 stringByJoiningIndexPathWithSeparator: @""]);
	UKStringsEqual(@"507", [indexPath3 stringByJoiningIndexPathWithSeparator: @""]);

	UKStringsEqual(@"5", [indexPath1 stringByJoiningIndexPathWithSeparator: @"2-34.."]);
	UKStringsEqual(@"52-34..0", [indexPath2 stringByJoiningIndexPathWithSeparator: @"2-34.."]);
}

@end

