/**	<title>NSURL+Etoile</title>
	
	<abstract>NSURL additions.</abstract>
 
	Copyright (C) 2008 Quentin Mathe
 
	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  March 2008
	License: Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>


@interface NSURL (Etoile)

- (NSURL *) parentURL;
- (NSString *) lastPathComponent;
- (NSURL *) URLByAppendingPath: (NSString *)aPath;

@end

