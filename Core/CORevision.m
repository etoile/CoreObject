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
    _cache = aCache;
    _revisionInfo = aRevInfo;
    assert(_revisionInfo.revisionUUID != nil);
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

    return [_revisionInfo.revisionUUID isEqual: ((CORevision *)rhs)->_revisionInfo.revisionUUID];
}

- (NSUInteger)hash
{
    return _revisionInfo.revisionUUID.hash;
}

- (NSArray *)propertyNames
{
    return [[super propertyNames] arrayByAddingObjectsFromArray:
        @[@"UUID", @"date", @"type", @"localizedTypeDescription",
          @"localizedShortDescription", @"metadata"]];
}

- (ETUUID *)UUID
{
    return _revisionInfo.revisionUUID;
}

- (CORevisionCache *)cache
{
    if (_cache == nil)
    {
        [NSException raise: NSGenericException
                    format: @"Attempted to access a CORevision property from a revision whose "
                                "parent revision cache/editing context have been deallocated"];
    }
    return _cache;
}

- (CORevision *)parentRevision
{
    if (_revisionInfo.parentRevisionUUID == nil)
        return nil;

    ETUUID *parentRevID = _revisionInfo.parentRevisionUUID;
    return [[self cache] revisionForRevisionUUID: parentRevID
                              persistentRootUUID: _revisionInfo.persistentRootUUID];
}

- (CORevision *)mergeParentRevision
{
    if (_revisionInfo.mergeParentRevisionUUID == nil)
        return nil;

    ETUUID *revID = _revisionInfo.mergeParentRevisionUUID;
    return [[self cache] revisionForRevisionUUID: revID
                              persistentRootUUID: _revisionInfo.persistentRootUUID];
}

- (ETUUID *)persistentRootUUID
{
    return _revisionInfo.persistentRootUUID;
}

- (ETUUID *)branchUUID
{
    return _revisionInfo.branchUUID;
}

- (NSDate *)date
{
    return _revisionInfo.date;
}

// TODO: Implement it in the metadata for the new store
// Formalize the concept of similar operations belonging to a common kind...
// For example:
// - major edit vs minor edit
// - Item Mutation that includes Add Item, Remove Item, Insert Item etc.

- (NSDictionary *)metadata
{
    return _revisionInfo.metadata;
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
            return YES;

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
