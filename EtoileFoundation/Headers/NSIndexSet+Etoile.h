/**	
	<abstract>Additions to index set classes.</abstract>

	Copyright (C) 2007 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  August 2007
	License:  Modified BSD (see COPYING)
 */
 
#import <Foundation/Foundation.h>

/** @group Collection Additions */
@interface NSIndexSet (Etoile)

- (NSArray *) indexPaths;

@end

/** @group Collection Additions */
@interface NSMutableIndexSet (Etoile)

- (void) invertIndex: (unsigned int)index;

@end
