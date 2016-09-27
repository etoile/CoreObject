- (void) testAsyncFaulting
{
    // library1 <<persistent root>>
    //  |
    //  \--photo1 // cross-persistent-root link, default branch
    //
    // photo1 <<persistent root>>
    //  |
    //  \--child1 (pretend there are a lot of child objects)
    
    
    // 1. Set it up in memory
    
    COPersistentRoot *photo1 = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    COObject *child1 = [photo1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];

    [[photo1 rootObject] setValue: @"photo1" forProperty: @"label"];
    [[photo1 rootObject] insertObject: child1 atIndex: ETUndeterminedIndex hint: nil forProperty: @"contents"];
    
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [[persistentRoot rootObject] insertObject: [photo1 rootObject] atIndex: ETUndeterminedIndex hint:nil forProperty: @"contents"];
    
    [ctx commit];
    
    // 2. Read it into another context
    
    {
        COEditingContext *ctx2 = [[COEditingContext alloc] initWithStore: store];
        COPersistentRoot *persistentRoot2 = [ctx2 persistentRootForUUID: [persistentRoot persistentRootUUID]];
        COPersistentRoot *photo1ctx2 = [[[[persistentRoot2 rootObject] valueForKey: @"contents"] objectAtIndex: 0] persistentRoot];
        
        // This should be a fault
        COObject *photo1ctx2RootObject = [photo1ctx2 rootObject];
        
        // The relationship has not loaded yet.
        UKObjectsEqual([NSArray array], [photo1ctx2RootObject valueForKey: @"contents"]);
        
        // Now, suppose that triggers loading.
        // Should we automatically notify a delegate?
        
        // FIXME: Check for the loaded contents
    }
}

