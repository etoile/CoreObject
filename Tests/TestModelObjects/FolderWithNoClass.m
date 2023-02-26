/*
    Copyright (C) 2014 Eric Wasylishen

    Date:  July 2014
    License:  MIT  (see COPYING)
 */

#import "FolderWithNoClass.h"

void registerFolderWithNoClassEntityDescriptionIfNeeded(void)
{
    static BOOL registered;
    if (registered)
        return;

    registered = YES;

    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"FolderWithNoClass"];
    entity.parentName = @"COObject";

    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                             typeName: @"NSString"];
    labelProperty.persistent = YES;

    ETPropertyDescription *contentsProperty =
        [ETPropertyDescription descriptionWithName: @"contents" typeName: @"FolderWithNoClass"];

    contentsProperty.persistent = YES;
    contentsProperty.multivalued = YES;
    contentsProperty.ordered = NO;

    ETPropertyDescription *parentProperty =
        [ETPropertyDescription descriptionWithName: @"parent" typeName: @"FolderWithNoClass"];

    parentProperty.multivalued = NO;
    parentProperty.derived = YES;
    parentProperty.oppositeName = @"FolderWithNoClass.contents";

    entity.propertyDescriptions = @[labelProperty, contentsProperty, parentProperty];

    ETModelDescriptionRepository *repo = [ETModelDescriptionRepository mainRepository];
    [repo addUnresolvedDescription: entity];
    [repo resolveNamedObjectReferences];
}
