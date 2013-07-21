#if 0

void test()
{
	/**
	 
	 we test the equivelance of branches and copies.
	 
	 branching is just a thin user interface for 'grouping' copies.
	 
	 note that it would be best for some properties of the object 
	 (e.g., name) to live outside the branches and directly in the persistent root
	 
	 
	 When you copy an object, it needs to be independent from the source.
	 Other than that, you should be able to:
	 
	 - view where the copy came from (optionally hide-able)
	 - merge in changes from where the copy came from.
	 
	 **/

	
	// create a persistent root r with 3 branches: a, b, c; current branch: a
	
	rootCtx = [store rootContext];
	libUUID = [rootCtx insertNewPersistentRootWithRootItem: [factory newFolder: @"library"]];
						// implict inContainer: [rootCtx rootUUID]
	
	[rootCtx commit];
	
	{
		libCtx = [rootCtx editingContextForEditingEmbdeddedPersistentRoot: libUUID];
		
		libFolder = [libCtx rootUUID];
		
		drawingUUID = [libCtx insertNewPersistentRootWithRootItem: [factory newFolder: @"drawing"]];
		// implict inContainer: [libCtx rootUUID]

		COUUID *drawing_b1 = [factory currentBranchForPersistentRoot: drawingUUID inContext: libCtx];
		COUUID *drawing_b2 = [factory createBranchForPersistentRoot: drawingUUID inContext: libCtx];
		COUUID *drawing_b3 = [factory createBranchForPersistentRoot: drawingUUID inContext: libCtx];
		// current branch is still drawing_b1
		
		// copy r -> r' (a', b', c'), current branch: a'

		COUUID *drawing1 = [factory copyEmbeddedObject: drawingUUID
										  insertInto: libFolder
										   inContext: libCtx];
		
		// copy branch c out of the r and edit it a bit -> c"
		
		// FIXME!!!: We shouldn't use this hack.
		// we need a way to get drawing1_b3 cleanly. The copy method should also return a mapping dictionary?
		
		//COUUID *drawing1_b3 = [[[libCtx storeItemForUUID: drawing1] valueForAttribute: @"contents"] objectAtIndex: 2];

		COUUID *drawing1_b3copy = [factory newPersistentRootCopyingBranch: drawing1_b3
												   insertInto: libFolder
													inContext: libCtx];
		
		[libCtx commit];
		
		// open a context to edit the branch
		{
			drawing1_b3copyCtx = [libCtx editingContextForEditingEmbdeddedPersistentRoot: drawing1_b3copy];
		
			drawing1_b3copyCtx_drawing = [drawing1_b3copyCtx rootUUID];
			
			layer = [drawing1_b3copyCtx_drawing insertItem: [factory newFolderNamed: @"layer"]
											   inContainer: [drawing1_b3copyCtx_drawing rootItem]];
			
			[drawing1_b3copyCtx commit];
		}
	
	
		// add c" to r' -> (a', b', c', c")
		
		{
			COMutableStoreItem *r1item = [ctx storeItemForUUID: r1];
			[r1item addObject: r2b3copy forAttribute: @"contents"];
			[ctx updateItem: r1item];
		}
		
		// merge branch c" and b' -> branch d, r' -> (a', b', c', c", d)

		// FIXME:
	}
}

#endif
