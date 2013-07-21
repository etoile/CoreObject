#if 0

void test()
{
	/**
	 we simulate a photo manager with the following object types:
	 
	 library (versioned persistent root)
	 - can contain projects, folders, albums
	 
	 photo (versioned persistent root)
	 - has name, date, etc
	 
	 project
	 -can contain folders, albums, photos (but not projects)
	 -contained items can only be in one project at a time.
	 -projects "own" photos - each photo is in only one project (but may 
	  be referenced by multiple albums, possibly from other projects).
	 
	 folder
	 -can contain projects, folders, albums (but not photos, directly).
	 -contained items can only be in one folder at a time.
	 
	 album
	 -can contain only photos
	 -contained photos can be in multiple albums.
	 */
	
	/*
	 test deleting a photo; should we automatically delete local (to the same persistent root)
	 COPath references to it? probably.
	 
	 also test deleting a branch of a persistent root; what happens to currentBranch? we will
	 need special handling to pick a new branch
	 
	 */
	
	/*
	 also, test "home-made" versioning, merging:
	 
	 "One of my desirable properties is that the versioning primitive, cheap copy,
	 be available for everyday use (e.g. simply copying a photo). While there should 
	 be a default versioning scheme, sometimes you don’t need that overhead, and just
	 want to cook your own. You should be able to, and get the same efficiency for free."
	 
	 
	 */
	
	// library1 <<persistent root>>
	//  |
	//  |--folder1
	//  |   |
	//  |   |-project1
	//  |   |   |
	//  |   |   \-photo1 <<persistent root>>	
	//  |   |
	//  |   \-album1
	//  |       |
	//  |       |-link to photo1
	//  |       |
	//  |       \-link to library2/photo4 // cross-persistent-root link
	//  | 
	//   \-project2
	//      |
	//      |--photo2 <<persistent root>>
    //      |
	//      |--photo3 <<persistent root>>
    //      |
	//       \-album2
	//          |
	//          |-link to photo1
	//          |
	//          \-link to photo2
	//
	// library2 <<persistent root>>
	//  |
	//  \--project3
	//      |
	//      |-photo4 <<persistent root>> 
	//      |
	//      \-album1
	//          |
	//          |-link to photo4
	//          |
	//          |-link to library1/photo1  // cross-persistent-root link
	//          |
	//          |-link to photo3
	//          |
	//          |-link to photo2
	//          |
	//          \-link to photo4 // duplicates make sense in photo albums if you want to return to a photo
	
	/**
	 * returns an editing context for the toplevel version
	 * note changes made in this context are not undoable!
	 */
	ctxt = [store rootContext];
	
	// creates a new parentless version in the store *right now*
	// (if the context doesn't get committed, the version will eventually get GC'ed)
	COUUID *library1 = [ctxt newPersistentRootAtItemPath: 
								[COItemPath itemPathWithUUID: [ctxt rootObject]
									 unorderedCollectionName: @"contents"]
												rootItem: [factory newFolderNamed: @"library1"]];
	[ctxt commit];
	
	
	// the library's context doesn't need full acccess to the root ctxt.
	// in fact, it should _definately not_ have full access to the root ctxt.
	// => to create a commit in the library context, we will need to commit a update in the
	// root context _only_ to the _single_ embedded object in the root context that
	// references the version for the library context.
	//library1ctxt = [store contextForPath: [COPath pathWithPathComponent: library1currentBranch]];
	
	
	library1ctxt = [ctxt editingContextForEditingEmbdeddedPersistentRoot: library1];
	
	assert([[[library1ctxt storeItem: [library1ctxt rootItem]] valueForAttribute: @"name"] isEqual: @"library1"]);
	
	
	
	COUUID *folder1 = [library1ctxt insertItem: [factory newFolderNamed: @"folder1"]
								   inContainer: [library1ctxt rootItem]];

	COUUID *project2 = [library1ctxt insertItem: [factory newFolderNamed: @"project2"]
								   inContainer: [library1ctxt rootItem]];

	// before committing library1ctxt, try making a change in the root ctxt
	
	COUUID *library2 = [ctxt newPersistentRootAtItemPath: 
						[COItemPath itemPathWithUUID: [ctxt rootObject]
							 unorderedCollectionName: @"contents"]
												rootItem: [factory newFolderNamed: @"library2"]];
	[ctxt commit];
	
	[library1ctxt commit]; // should still work
	
}

#endif