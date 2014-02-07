/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@interface COSynchronizerJSONUtils : NSObject

+ (NSString *) serializePropertyList: (id)plist;
+ (id) deserializePropertyList: (NSString *)aString;

+ (id) propertyListForRevisionsArray: (NSArray *)revs;
+ (NSArray *) revisionsArrayForPropertyList: (id)aPropertylist;

+ (COAttachmentID *) searchForFirstMissingAttachmentIDInGraph: (id<COItemGraph>)aGraph store: (COSQLiteStore *)aStore;

@end
