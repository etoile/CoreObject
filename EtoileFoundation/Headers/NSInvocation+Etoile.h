/** <title>NSInvocation+Etoile</title>

	<abstract>NSInvocation additions.</abstract>

	Copyright (C) 2008 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  April 2008
	Licence:  Modified BSD (see COPYING)
  */

#import <Foundation/Foundation.h>


@interface NSInvocation (Etoile)
+ (id) invocationWithTarget: (id)target
                   selector: (SEL)selector
                  arguments: (NSArray *)args;
@end

