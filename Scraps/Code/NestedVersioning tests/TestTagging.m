#import "TestCommon.h"

@interface TestTagging : NSObject <UKTest> {
	
}

@end

@implementation TestTagging

- (void) testTagging
{	
	// tag library <<persistent root>>
	//  |
	//  \--places
	//      |
	//      |-north america
	//      |   |
	//      |   \-canada 
	//      |
	//      \-south america
	//          |
	//          \-brazil
	//    
	// photo library <<persistent root (branchA, branchB) >>
	//  |
	//  |--local tags
	//  |   |
	//  |   |-subject
	//  |   |   |
	//  |   |   |-landscape 
	//  |   |   |
	//  |   |   |-people
	//  |   |   |
	//  |   |   \-abstract
	//  |   |
	//  |   \-lighting
	//  |       |
	//  |       |-sunlight
	//  |       |
	//  |       \-artificial
	//  | 
	//   \-photo shoots
	//      |
	//      \--shoot1
    //          |
	//          |--photo1 <<persistent root>> 
	//          |   |
	//          |   \--(tags: places/north america/canada, subject/landscape, subject/abstract)
    //          |
	//          |--photo2 <<persistent root>> 
	//          |   |
	//          |   \--(tags: lighting/sunlight, places/south america/brazil, subject/abstract)
    //          |
	//          \--photo3 <<persistent root>> 
	//              |
	//              \--(tags: lighting/artificial, places/south america/brazil, subject/people)


	COStore *store = setupStore();
	COSubtreeFactory *factory = [COSubtreeFactory factory];
	
	// wrap the rootCtx in another persistent root
	
	COPersistentRootEditingContext *rootRootCtx = [store rootContext];
	[rootRootCtx setPersistentRootTree: [factory createPersistentRootWithRootItem: [COSubtree subtree]
																	  displayName: @"tagging test library"
																			store: store]];
	[rootRootCtx commitWithMetadata: nil];
	
	
	// old code begins here...
	
	COPersistentRootEditingContext *rootCtx = [rootRootCtx editingContextForEditingEmbdeddedPersistentRoot:
												[rootRootCtx persistentRootTree]];
	
	COSubtree *iroot = [COSubtree subtree];
	
	[rootCtx setPersistentRootTree: iroot];
	
	
	COSubtree *taglib = [[COSubtreeFactory factory] createPersistentRootWithRootItem: [factory folder: @"tag library"]
													  displayName: @"tag library"
															store: store];
	[iroot addTree: taglib];
	
	COSubtree *photolib = [[COSubtreeFactory factory] createPersistentRootWithRootItem: [factory folder: @"photo library"]
														displayName: @"photo library"
															  store: store];
	[iroot addTree: photolib];
	
	[rootCtx commitWithMetadata: D(@"create libraries", @"menuLabel")];
	
	// set up some tags
	
		COPersistentRootEditingContext *taglibCtx = [rootCtx editingContextForEditingEmbdeddedPersistentRoot: taglib];
		
		COSubtree *taglibFolder = [taglibCtx persistentRootTree];
		

		COSubtree *places = [factory folder: @"places"];
		[taglibFolder addTree: places];
		COSubtree *northamerica =  [factory folder: @"north america"];
		[places addTree: northamerica];
		COSubtree *canada = [factory item: @"canada"];
		[northamerica addTree: canada];
		COSubtree *southamerica = [factory folder: @"south america"];
		[places addTree: southamerica];
		COSubtree *brazil = [factory item: @"brazil"];
		[southamerica addTree: brazil];
	
		[taglibCtx commitWithMetadata: D(@"add tags", @"menuLabel")];
	


	// create a photo library
	
		COPersistentRootEditingContext *photolibCtx = [rootCtx editingContextForEditingEmbdeddedPersistentRoot: photolib];
		
		COSubtree *photolibFolder = [photolibCtx persistentRootTree];
		
		// set up some local tags
		
			COSubtree *localtagFolder = [factory folder: @"local tags"];
			[photolibFolder addTree: localtagFolder];
			COSubtree *subject = [factory folder: @"subject"];
			[localtagFolder addTree: subject];
			COSubtree *landscape = [factory item: @"landscape"];
			[subject addTree: landscape];
			COSubtree *people = [factory item: @"people"];
			[subject addTree: people];
			COSubtree *abstract = [factory item: @"abstract"];
			[subject addTree: abstract];
			COSubtree *lighting = [factory folder: @"lighting"];
			[localtagFolder addTree: lighting];
			COSubtree *sunlight = [factory item: @"sunlight"];
			[lighting addTree: sunlight];
			COSubtree *artificial = [factory item: @"artificial"];
			[lighting addTree: artificial];
		
		
		// set up photo shoots folder
		
			COSubtree *photoshootsFolder = [factory folder: @"photo shoots"];
			[photolibFolder addTree: photoshootsFolder];
			COSubtree *shoot1 = [factory folder: @"shoot1"];
			[photoshootsFolder addTree: shoot1];
			
			COSubtree *photo1 = [[COSubtreeFactory factory] createPersistentRootWithRootItem: [factory folder: @"photo1"]
																  displayName: @"photo1"
																		store: store];
			[shoot1 addTree: photo1];

			COSubtree *photo2 = [[COSubtreeFactory factory] createPersistentRootWithRootItem: [factory folder: @"photo2"]
																  displayName: @"photo2"
																		store: store];
			[shoot1 addTree: photo2];
			
			COSubtree *photo3 = [[COSubtreeFactory factory] createPersistentRootWithRootItem: [factory folder: @"photo3"]
																  displayName: @"photo3"
																		store: store];
			[shoot1 addTree: photo3];
	
		
		// set up some albums
	
			COSubtree *albums = [factory folder: @"albums"];
			[photolibFolder addTree: albums];
			COSubtree *album1 = [factory folder: @"album1"];
			[albums addTree: album1];
			COSubtree *album2 = [factory folder: @"album2"];
			[albums addTree: album1];
	
		// put photos in the albums as COPaths. Photo 2 and 1 are in both albums
		// photo 2 appears twice in album1
	
			[album1 setValue: A([COPath pathWithPathComponent: [photo1 UUID]],
								[COPath pathWithPathComponent: [photo2 UUID]],
								[COPath pathWithPathComponent: [photo2 UUID]]) 
				forAttribute: @"contents" 
						type: kCOPathType | kCOTypeArray];

			[album2 setValue: A([COPath pathWithPathComponent: [photo2 UUID]],
								[COPath pathWithPathComponent: [photo3 UUID]],
								[COPath pathWithPathComponent: [photo1 UUID]]) 
				forAttribute: @"contents" 
						type: kCOPathType | kCOTypeArray];
		
		[photolibCtx commitWithMetadata: D(@"setup photo library", @"menuLabel")];
		
		// set up tags on photo1

		{
		// open a context to edit the branch

			COPersistentRootEditingContext *photo1Ctx = [photolibCtx editingContextForEditingEmbdeddedPersistentRoot: photo1];
			
			COPath *tag1 = [[[[[COPath path] 
								pathByAppendingPathToParent]
									pathByAppendingPathToParent]
										pathByAppendingPathComponent: [taglib UUID]]
											pathByAppendingPathComponent: [canada UUID]];
			
			COPath *tag2 = [[[COPath path] pathByAppendingPathToParent]
								pathByAppendingPathComponent: [landscape UUID]];

			COPath *tag3 = [[[COPath path] pathByAppendingPathToParent]
								pathByAppendingPathComponent: [abstract UUID]];
			
			COSubtree *photo1Ctx_rootItem = [photo1Ctx persistentRootTree];
			
			[photo1Ctx_rootItem setValue: S(tag1, tag2, tag3)
							forAttribute: @"tags"
									type: kCOPathType | kCOTypeSet];
			
			[photo1Ctx commitWithMetadata: D(@"add photo tags", @"menuLabel")];
		}
	
		// set up tags on photo2
		
		{
			// open a context to edit the branch
			
			COPersistentRootEditingContext *photo2Ctx = [photolibCtx editingContextForEditingEmbdeddedPersistentRoot: photo2];
		
			COPath *tag1 = [[[[[COPath path] 
							   pathByAppendingPathToParent]
							  pathByAppendingPathToParent]
							 pathByAppendingPathComponent: [taglib UUID]]
							pathByAppendingPathComponent: [brazil UUID]];
			
			COPath *tag2 = [[[COPath path] pathByAppendingPathToParent]
							pathByAppendingPathComponent: [sunlight UUID]];
			
			COPath *tag3 = [[[COPath path] pathByAppendingPathToParent]
							pathByAppendingPathComponent: [abstract UUID]];
			
			COSubtree *photo2Ctx_rootItem = [photo2Ctx persistentRootTree];
						
			[photo2Ctx_rootItem setValue: S(tag1, tag2, tag3)
							forAttribute: @"tags"
									type: kCOPathType | kCOTypeSet];
			
			[photo2Ctx commitWithMetadata: D(@"add photo tags", @"menuLabel")];
		}
	
		// set up tags on photo3
		
		{
			// open a context to edit the branch
			
			COPersistentRootEditingContext *photo3Ctx = [photolibCtx editingContextForEditingEmbdeddedPersistentRoot: photo3];
			
		
			COPath *tag1 = [[[[[COPath path] 
							   pathByAppendingPathToParent]
							  pathByAppendingPathToParent]
							 pathByAppendingPathComponent: [taglib UUID]]
							pathByAppendingPathComponent: [brazil UUID]];
			
			COPath *tag2 = [[[COPath path] pathByAppendingPathToParent]
							pathByAppendingPathComponent: [people UUID]];
			
			COPath *tag3 = [[[COPath path] pathByAppendingPathToParent]
							pathByAppendingPathComponent: [artificial UUID]];
			
			COSubtree *photo3Ctx_rootItem = [photo3Ctx persistentRootTree];
			
			[photo3Ctx_rootItem setValue: S(tag1, tag2, tag3)
							forAttribute: @"tags"
									type: kCOPathType | kCOTypeSet];
			
			[photo3Ctx commitWithMetadata: D(@"add photo tags", @"menuLabel")];
		}
	
	// create branch of photo library
	
	// reopen the context to avoid a merge.
	// FIXME: shouldn't be necessary
	
	rootCtx = [rootRootCtx editingContextForEditingEmbdeddedPersistentRoot:
			   [rootRootCtx persistentRootTree]];
	photolib = [[rootCtx persistentRootTree] subtreeWithUUID: [photolib UUID]];
	
	COSubtree *photolibBranchA = [[COSubtreeFactory factory] currentBranchOfPersistentRoot: photolib];
	COSubtree *photolibBranchB = [[COSubtreeFactory factory] createBranchOfPersistentRoot: photolib];
	[photolibBranchB setValue: @"Test Branch"
				 forAttribute: @"name"
						 type: kCOTypeString];
	[rootCtx commitWithMetadata: D(@"create branch", @"menuLabel")];
	
	
	// do some searches
	
	// 1. search for "subject/abstract" tag. note there are two instances of the tag; one in photolibBranchA
	//    and one in photolibBranchB. Searching for complete paths (e.g. "../../abstract") makes no sense.
	//    so we just search for the uuid of "abstract".
	
	[store release];
}

@end
