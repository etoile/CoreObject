#import "TestCommon.h"
#import <EtoileFoundation/EtoileFoundation.h>

void setUpMetamodel()
{
	ETEntityDescription *outlineEntity = [ETEntityDescription descriptionWithName: @"OutlineItem"];
	[outlineEntity setParent: (id)@"Anonymous.COGroup"];
	
	ETPropertyDescription *labelProperty = [ETPropertyDescription descriptionWithName: @"label"
																	  type: [[ETModelDescriptionRepository mainRepository] descriptionForName: @"Anonymous.NSString"]];
	
	[outlineEntity setPropertyDescriptions: A(labelProperty)];
	
	[[ETModelDescriptionRepository mainRepository] addUnresolvedDescription: outlineEntity];

	// Tag entity

	ETEntityDescription *tagEntity = [ETEntityDescription descriptionWithName: @"Tag"];	
	[tagEntity setParent: (id)@"Anonymous.COCollection"];
	
	ETPropertyDescription *tagLabelProperty = [ETPropertyDescription descriptionWithName: @"label"
																	  type: [[ETModelDescriptionRepository mainRepository] descriptionForName: @"Anonymous.NSString"]];
	
	[outlineEntity setPropertyDescriptions: A(tagLabelProperty)];
	
	[[ETModelDescriptionRepository mainRepository] addUnresolvedDescription: tagEntity];
	
	[[ETModelDescriptionRepository mainRepository] resolveNamedObjectReferences];	
}