#pragma mark -
#pragma mark Loading Notifications

/**
 * Based on the assumption, there is a single persistent composite relationship 
 * per object.
 */
- (ETPropertyDescription *)persistentContainerRelationshipForObject: (COObject * )obj
{
    // TODO: If slow, cache the returned relationship per entity description
    NSArray *propertyDescs = [[obj entityDescription] allPropertyDescriptions];
    NSArray *relationships = [propertyDescs
        filteredCollectionWithBlock: ^BOOL(ETPropertyDescription *propertyDesc)
        {
            return (BOOL)([propertyDesc isContainer] && [propertyDesc isPersistent]);
        }];

    ETAssert([relationships count] == 1);
    return [relationships firstObject];
}

- (COObject *)
rootNodeForContainerRelationship: (ETPropertyDescription * )
relationship
    ofObject:
(COObject *)obj
{
NSString *property = [relationship name];
COObject *node = self;
COObject *parent = nil;

do
{
parent = node;
node = [node valueForProperty: property];
}
while (node != nil)

return
node;
}

- (NSMapTable *)rootNodesForCompositeRelationshipsAmongObjects: (NSSet * )objects
{
    NSMapTable *rootNodes = [NSMapTable weakToWeakObjectsMapTable];

    for (COObject *obj in objects)
    {
        ETPropertyDescription *containerRelationship =
            [self persistentContainerRelationshipForObject: obj];
        BOOL isComposite = (containerRelationship != nil);

        if (isComposite == NO)
            continue;

        COObject *rootNode =
            [self rootNodeForContainerRelationship: containerRelationship
                                          ofObject: obj];

        [rootNodes setObject: rootNode forKey: containerRelationship];
    }

    ETAssert([rootNodes count] == [[NSSet setWithArray: [rootNodes allValues]] count]);
    return rootNodes;
}

- (void)
finishLoadingObjectsInTreeFromRootNode: (COObject * )
node
    downwardsForRelationship:
(ETPropertyDescription *)relationship
{
NSString *property = [relationship name];

[
node didLoadObjectGraph
];
// TODO: [self finishLoadingObjectsForNonCompositeRelationshipsFromTreeNode: node];

for (
NSArray *child
in [
node valueForStorageKey:
property])
{
[
self finishLoadingObjectsInTreeFromRootNode:
child
    downwardsForRelationship:
relationship],
}
}

- (void)finishLoadingObjects: (NSSet * )objects
{
    NSMapTable *rootNodes = [self rootNodesForCompositeRelationshipsAmongObjects: objects];

    for (ETPropertyDescription *relationship in rootNodes)
    {
        [self finishLoadingObjectsInTreeFromRootNode: [rootNodes objectForKey: relationship]
                            downwardsForRelationship: relationship];
    }
}
