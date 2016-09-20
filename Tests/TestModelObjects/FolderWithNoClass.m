/*
    Copyright (C) 2014 Eric Wasylishen

    Date:  July 2014
    License:  MIT  (see COPYING)
 */

#import "FolderWithNoClass.h"

void registerFolderWithNoClassEntityDescriptionIfNeeded()
{
	static BOOL registered;
	if (registered)
		return;

	registered = YES;
	
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"FolderWithNoClass"];
    entity.parent = (id)@"Anonymous.COObject";
	
    ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
                                                                                 type: (id)@"Anonymous.NSString"];
    [labelProperty setPersistent: YES];
	
	ETPropertyDescription *contentsProperty =
    [ETPropertyDescription descriptionWithName: @"contents" type: (id)@"Anonymous.FolderWithNoClass"];
	
    [contentsProperty setPersistent: YES];
    [contentsProperty setMultivalued: YES];
    [contentsProperty setOrdered: NO];

    ETPropertyDescription *parentProperty =
    [ETPropertyDescription descriptionWithName: @"parent" type: (id)@"Anonymous.FolderWithNoClass"];
    
    [parentProperty setMultivalued: NO];
	[parentProperty setDerived: YES];
    parentProperty.opposite = (id)@"Anonymous.FolderWithNoClass.contents";
    
    entity.propertyDescriptions = @[labelProperty, contentsProperty, parentProperty];
	
	ETModelDescriptionRepository *repo = [ETModelDescriptionRepository mainRepository];
	[repo addUnresolvedDescription: entity];
	[repo resolveNamedObjectReferences];
}
