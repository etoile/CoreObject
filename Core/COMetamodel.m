/*
	Copyright (C) 2014 Quentin Mathe
 
	Date:  October 2014
	License:  MIT  (see COPYING)
 */

#import "COMetamodel.h"
#import "COAttachmentID.h"
#import "COObject.h"
#import "COLibrary.h"
#if (TARGET_OS_IPHONE)
#	import <CoreObject/COCocoaTouchCompatibility.h>
#   define NSImage UIImage
#else
#	import <AppKit/AppKit.h>
#endif

void CORegisterAdditionalEntityDescriptions(ETModelDescriptionRepository *repo)
{
	NSSet *entityDescriptions = [COLibrary additionalEntityDescriptions];

	for (ETEntityDescription *entity in entityDescriptions)
	{
		if ([repo descriptionForName: [entity fullName]] != nil)
			continue;
			
		[repo addUnresolvedDescription: entity];
	}
}

void CORegisterCoreObjectMetamodel(ETModelDescriptionRepository *repo)
{
	BOOL wereRegisteredPreviously = ([repo descriptionForName: @"COObject"] != nil);

	if (wereRegisteredPreviously)
		return;

	CORegisterAdditionalEntityDescriptions(repo);
	[repo collectEntityDescriptionsFromClass: [COObject class]
	                         excludedClasses: nil
	                              resolveNow: YES];

	NSMutableArray *warnings = [NSMutableArray array];

	[repo checkConstraints: warnings];
		
	if ([warnings isEmpty] == NO)
	{
		[NSException raise: NSInternalInconsistencyException
		            format: @"Failure on constraint check in repository %@:\n %@",
							repo, warnings];
	}
}
