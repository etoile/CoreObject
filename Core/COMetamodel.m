/*
    Copyright (C) 2014 Quentin Mathe
 
    Date:  October 2014
    License:  MIT  (see COPYING)
 */

#import "COMetamodel.h"
#import "COAttachmentID.h"
#import "COObject.h"
#import "COLibrary.h"
#include <objc/runtime.h>

/**
 * Extends the FM3 metamodel with data/blob and attachment as attribute types.
 */
void CORegisterPrimitiveEntityDescriptions(ETModelDescriptionRepository *repo)
{
    ETEntityDescription *dataEntity = [NSData newEntityDescription];
    ETEntityDescription *attachmentIDEntity = [COAttachmentID newEntityDescription];

    object_setClass(dataEntity, [ETPrimitiveEntityDescription class]);
    object_setClass(attachmentIDEntity, [ETPrimitiveEntityDescription class]);

    [repo addUnresolvedDescription: dataEntity];
    [repo addUnresolvedDescription: attachmentIDEntity];

    [repo setEntityDescription: dataEntity forClass: [NSData class]];
    [repo setEntityDescription: attachmentIDEntity forClass: [COAttachmentID class]];
}

void CORegisterAdditionalEntityDescriptions(ETModelDescriptionRepository *repo)
{
    NSSet *entityDescriptions = [COLibrary additionalEntityDescriptions];

    for (ETEntityDescription *entity in entityDescriptions)
    {
        if ([repo descriptionForName: entity.fullName] != nil)
            continue;

        [repo addUnresolvedDescription: entity];
    }
}

void CORegisterCoreObjectMetamodel(ETModelDescriptionRepository *repo)
{
    const BOOL wereRegisteredPreviously = ([repo descriptionForName: @"COObject"] != nil);

    if (wereRegisteredPreviously)
        return;

    CORegisterPrimitiveEntityDescriptions(repo);
    CORegisterAdditionalEntityDescriptions(repo);

    [repo collectEntityDescriptionsFromClass: [COObject class]
                             excludedClasses: nil
                                  resolveNow: YES];

    NSMutableArray *warnings = [NSMutableArray array];

    [repo checkConstraints: warnings];

    if (![warnings isEmpty])
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Failure on constraint check in repository %@:\n %@",
                            repo, warnings];
    }
}
