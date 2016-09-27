/**
    Copyright (C) 2012 Eric Wasylishen

    Date:  March 2012
    License:  MIT  (see COPYING)
 */

#import "COItemGraphEdit.h"

@interface COSetAttribute : COItemGraphEdit
{
    COType type;
    id value;
}

@property (readonly, nonatomic) COType type;
@property (readonly, nonatomic) id value;

- (instancetype)initWithUUID: (ETUUID *)aUUID
                   attribute: (NSString *)anAttribute
            sourceIdentifier: (id)aSourceIdentifier
                        type: (COType)aType
                       value: (id)aValue NS_DESIGNATED_INITIALIZER;

@end
