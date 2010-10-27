/** <title>ETByteSizeFormatter</title>
	
	<abstract>Formatter subclass to convert numbers expressed in bytes to a 
	human-readable format.</abstract>
 
	Copyright (C) 2010 Quentin Mathe
 
	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  January 2010
	License:  Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>

/** ETByteSizeFormatter supports to format NSNumber objects up the terabyte 
unit as detailed in -stringForObjectValue:. */
@interface ETByteSizeFormatter : NSFormatter

- (NSString *) stringForObjectValue: (id)anObject;

@end

