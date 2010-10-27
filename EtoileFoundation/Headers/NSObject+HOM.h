/**	<title>NSObject HOM Category</title>

	<abstract>A category which extends NSObject with various High Order 
	Messages.</abstract>

	Copyright (C) 2009 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  June 2009
	License: Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>
#import "NSObject+HOM.h"


@interface NSObject (HOM)

/** Returns the receiver itself when it can respond to the next message that 
follows -ifResponds, otherwise returns nil.

If we suppose the Cat class doesn't implement -bark, then -ifResponds would 
return nil and thereby -bark be discarded:
<code>
[[cat ifResponds] bark];
</code>

Now let's say the Dog class implement -bark, the -ifResponds will return 'dog' 
and -bark be executed:
<code>
[[dog ifResponds] bark];
</code> */
- (id) ifResponds;

@end
