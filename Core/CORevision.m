/*
    Copyright (C) 2010 Eric Wasylishen, Quentin Mathe

    Date:  November 2010
    License:  MIT  (see COPYING)
 */

#import "CORevision.h"
#import "COCommitDescriptor.h"
#import "CORevisionInfo.h"
#import "CORevisionCache.h"

@implementation CORevision

- (instancetype)initWithCache: (CORevisionCache *)aCache
                 revisionInfo: (CORevisionInfo *)aRevInfo
{
    NILARG_EXCEPTION_TEST(aCache);
    NILARG_EXCEPTION_TEST(aRevInfo);
    SUPERINIT;
    cache = aCache;
    revisionInfo = aRevInfo;
    assert(revisionInfo.revisionUUID != nil);
    return self;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"

- (instancetype)init
{
    return [self initWithCache: nil revisionInfo: nil];
}

#pragma clang diagnostic pop

- (BOOL)isEqual: (id)rhs
{
    if (![rhs isKindOfClass: [CORevision class]])
        return NO;

    return [revisionInfo.revisionUUID isEqual: ((CORevision *)rhs)->revisionInfo.revisionUUID];
}

- (NSUInteger)hash
{
    return revisionInfo.revisionUUID.hash;
}

- (NSArray *)propertyNames
{
    return [[super propertyNames] arrayByAddingObjectsFromArray:
        @[@"UUID", @"date", @"type", @"localizedTypeDescription",
          @"localizedShortDescription", @"metadata"]];
}

- (ETUUID *)UUID
{
    return revisionInfo.revisionUUID;
}

- (CORevisionCache *)cache
{
    if (cache == nil)
    {
        [NSException raise: NSGenericException
                    format: @"Attempted to access a CORevision property from a revision whose "
                                "parent revision cache/editing context have been deallocated"];
    }
    return cache;
}

- (CORevision *)parentRevision
{
    if (revisionInfo.parentRevisionUUID == nil)
    {
        return nil;
    }

    ETUUID *parentRevID = revisionInfo.parentRevisionUUID;
    return [[self cache] revisionForRevisionUUID: parentRevID
                              persistentRootUUID: revisionInfo.persistentRootUUID];
}

- (CORevision *)mergeParentRevision
{
    if (revisionInfo.mergeParentRevisionUUID == nil)
    {
        return nil;
    }

    ETUUID *revID = revisionInfo.mergeParentRevisionUUID;
    return [[self cache] revisionForRevisionUUID: revID
                              persistentRootUUID: revisionInfo.persistentRootUUID];
}

- (ETUUID *)persistentRootUUID
{
    return revisionInfo.persistentRootUUID;
}

- (ETUUID *)branchUUID
{
    return revisionInfo.branchUUID;
}

- (NSDate *)date
{
    return revisionInfo.date;
}

// TODO: Implement it in the metadata for the new store
// Formalize the concept of similar operations belonging to a common kind...
// For example:
// - major edit vs minor edit
// - Item Mutation that includes Add Item, Remove Item, Insert Item etc.

- (NSDictionary *)metadata
{
    return revisionInfo.metadata;
}

- (COCommitDescriptor *)commitDescriptor
{
    NSString *commitDescriptorId =
        self.metadata[kCOCommitMetadataIdentifier];

    if (commitDescriptorId == nil)
        return nil;

    return [COCommitDescriptor registeredDescriptorForIdentifier: commitDescriptorId];
}

- (NSString *)localizedTypeDescription
{
    COCommitDescriptor *descriptor = self.commitDescriptor;

    if (descriptor == nil)
        return self.metadata[kCOCommitMetadataTypeDescription];

    return descriptor.localizedTypeDescription;
}

- (NSString *)localizedShortDescription
{
    return [COCommitDescriptor localizedShortDescriptionFromMetadata: self.metadata];
}

- (NSString *)description
{
    return [NSString stringWithFormat: @"%@ (%@ <= %@)",
                                       NSStringFromClass([self class]),
                                       self.UUID,
                                       (self.parentRevision != nil ? self.parentRevision.UUID : @"none")];
}

- (BOOL)isEqualToOrAncestorOfRevision: (CORevision *)aRevision
{
    NILARG_EXCEPTION_TEST(aRevision);
    CORevision *rev = aRevision;

    while (rev != nil)
    {
        if ([rev isEqual: self])
        {
            return YES;
        }
        rev = rev.parentRevision;
    }
    return NO;
}

#pragma mark - COTrackNode Implementation

- (id <COTrackNode>)parentNode
{
    return self.parentRevision;
}

- (id <COTrackNode>)mergeParentNode
{
    return self.mergeParentRevision;
}

@end
