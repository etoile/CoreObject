/** <title>NSIndexPath+Etoile</title>

	<abstract>Additions to NSIndexPath.</abstract>

	Copyright (C) 2007 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  September 2007
	License:  Modified BSD (see COPYING)
 */
 
#import <Foundation/Foundation.h>


@interface NSIndexPath (Etoile)
+ (NSIndexPath *) indexPath;
- (unsigned int) firstIndex;
- (unsigned int) lastIndex;
- (NSIndexPath *) indexPathByRemovingFirstIndex;
- (NSString *) stringByJoiningIndexPathWithSeparator: (NSString *)separator;
- (NSString *) keyPath;
@end
