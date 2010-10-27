/**	<title>NSString+Etoile</title>

	<abstract>NSString additions.</abstract>

	Copyright (C) 2007 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  September 2007
	License: Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>


@interface NSString (Etoile)

- (NSString *) firstPathComponent;
- (NSString *) stringByDeletingFirstPathComponent;
- (NSString *) stringBySpacingCapitalizedWords;
- (NSIndexPath *) indexPathBySplittingPathWithSeparator: (NSString *)separator;

@end

