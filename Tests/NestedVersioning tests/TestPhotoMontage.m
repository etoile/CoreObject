#if 0

void test()
{

	/* 1. Initial state */
	
	
	// project1 <<persistent root>>
	//  |
	//  |--montage <<persistent root, current branch="layoutB">>
	//  |   |
	//  |   |-<<branch "layoutA">>
	//  |   |   |
	//  |   |   \--layer1
	//  |   |
	//  |   \-<<branch "layoutB">>
	//  |       |
	//  |       \--layer1
	//  |       
	//  \--logo <<persistent root>>
	//      |
	//      \--shape1
	//
	// photolibrary <<persistent root>>
	//  |
	//  \--photo1 <<persistent root, current branch="colour">>
	//      |
	//      |--<<branch "b&w">>
	//      |    |
	//      |    \--shape2a
	//      |   
	//      \--<<branch "colour">>
	//           |
	//           \--shape2c
	
	 

	/* 2. Drag & drop photo1 into the monage
		  Default behaviour is copy.
	 */
	
	
	// project1 <<persistent root>>
	//  |
	//  |--montage <<persistent root, current branch="layoutB">>
	//  |   |
	//  |   |-<<branch "layoutA">>
	//  |   |   |
	//  |   |   \--layer1
	//  |   |        |
	//  |   |        \--photo1 <<persistent root, current branch="colour">>
	//  |   |            |
	//  |   |            |--<<branch "b&w">>
	//  |   |            |    |
	//  |   |            |    \--shape2a
	//  |   |            |   
	//  |   |            \--<<branch "colour">>
	//  |   |                 |
	//  |   |                 \--shape2c
	//  |   |
	//  |   \-<<branch "layoutB">>
	//  |       |
	//  |       \--layer1
	//  |       
	//  \--logo <<persistent root>>
	//      |
	//      \--shape1
	//
	// photolibrary <<persistent root>>
	//  |
	//  \--photo1 <<persistent root, current branch="colour">>
	//      |
	//      |--<<branch "b&w">>
	//      |    |
	//      |    \--shape2a
	//      |   
	//      \--<<branch "colour">>
	//           |
	//           \--shape2c
	


	/* 3. Make some edits in photolibrary/photo1, on the default branch (colour).
		
	 */

	/* 4. The user wants to "pull" changes from photolibrary/photo1 into 
	      project1/montage/photo1. 
	 
		  This is implemented by searching the store for all branches with the
	      same UUID as "colour", and showing them in a list with their current
	      states.
	 
	      At this point it works basically the same as git. If project1/montage/photo1
	      has changes which diverge from those made in photolibrary/photo1, the user
	      can merge in the changes from photolibrary/photo1. Otherwise it's just
	      a "fast-forward" merge.
	 
	 */

	
	/* 5. User decides to change project1/montage/photo1 to a link. It should remember
	      where it was copied from. Uesr right clicks on the object and selects "Change to a link".
	 
		  This is implementing as deleting the project1/montage/photo1 persistent root
	      and inserting a special link marker.
	 
	 */
	
	// project1 <<persistent root>>
	//  |
	//  |--montage <<persistent root, current branch="layoutB">>
	//  |   |
	//  |   |-<<branch "layoutA">>
	//  |   |   |
	//  |   |   \--layer1
	//  |   |        |
	//  |   |        \--<<link to "../../photolibrary/photo1">>
	//  |   |
	//  |   \-<<branch "layoutB">>
	//  |       |
	//  |       \--layer1
	//  |       
	//  \--logo <<persistent root>>
	//      |
	//      \--shape1
	//
	// photolibrary <<persistent root>>
	//  |
	//  \--photo1 <<persistent root, current branch="colour">>
	//      |
	//      |--<<branch "b&w">>
	//      |    |
	//      |    \--shape2a
	//      |   
	//      \--<<branch "colour">>
	//           |
	//           \--shape2c
	
	
	
	
	/**
	 
	 - what if we want a photo in "layout A" that links to whatever "layout B"'s photo
	 is doing? simple.. just a proot that links to /artwork/montage-layout-b/photo-proot
	 
	 - what if we want a photo in "layout A" that links to a specific branch of "layout B"'s photo?
	 just a proot that links to /artwork/montage-layout-b/photo-specific-branch
	 
	 - what if we want a photo in "layout A" that links to (whatever the current branch of the 
	 montage is)'s current photo (yes, that is probably crazy and useless!)
	 	 
	 
	 */
	
	
	
	
	montagePath = [montageParent createNewRootObject{[withInitialState:?}]; // does an implicit commit?
	
	COPersistentRootEditingContext *montageCtxt = [COPersistentRootEditingContext contextWithPath: montagePath];
	
	// set up the montage contents
	
	layer_bg = [montageCtxt addEmbeddedobject];
	layer_fg = [montageCtxt addEmbeddedobject];
	
	layers = [montageCtxt addEmbeddedobject];
	[layers addContained: layer_bg];
	[layers addContained: layer_fg]; //FIXME: set as ordered
	
	[montage addContained: layers];
	
	
	montage_a = [montage newbranch];
	montage_b = [montage newbranch];	
	
	
	[montage setBranch: montage_a];
	
	// set up the photo library
	
	photo = [rootobject new];
	
	photolibrary = [rootobject new];
	[photolibrary addContained: photo];
	
	photo_color = [photo newbranch];
	photo_bw = [photo newbranch];
	photo_sepia = [photo newbranch];	
	
	[photo setBranch: photo_color];
	
	
	// copy in the photo to montage_a
	
	[montage insertCopyOfPersistentRoot: photo];
	
	[montage setBranch: montage_b];
	
	[montage insertCopyOfPersistentRoot: photo];
}

#endif


				   
				   /*
					-- long rambling investigation of problems that links can cause: --
					
					problem: we have a project like this:
					
					/art/project1/montageA - contains an embedded /art/project1/logo
					/art/project1/logo
					
					P1: suppose we copy project1:
					
					/art/project2/montageA - contains an embedded /art/project1/logo
					/art/project2/logo
					
					P2: and suppose we copy montageA into another project:
					
					/art/project3/montageAcopy
					
					P3: suppose we copy montageA into the same project
					
					/art/project1/montageA - contains an embedded /art/project1/logo
					/art/project1/montageB - contains an embedded /art/project1/logo
					/art/project1/logo
					
					======
					
					P1: BAD: the absolute paths will cause ugly results, because montage in project2 will change when
					the logo in project1 is updated; in other words, it was not a "true" copy.
					
					P2: it's not at all clear what the result should be.
					
					P3: OK: the link should point to the same logo in project1. 
					
					what if we used a relative path:
					
					/art/project1/montageA - contains an embedded ../logo
					/art/project1/logo
					
					suppose we copy project1:
					
					/art/project2/montageA - contains an embedded ../logo
					/art/project2/logo
					
					the copy works properly now, but suppose we copy montageA into another project:
					
					/art/project3/montageAcopy
					
					this would break the link to the logo.
					
					what if we used absolute paths, but when copying, check if there are absolute
					links within the subtree being copied, and if there are, update them. if they
					point outside of the tree being copied, leave them as-is.
					
					this seems to be the optimal result, but breaks cheap copies...
					
					can we 'fix up' the relative paths to get the previous result?
					
					yes.. we can detect, when copying, if any of the child proots/branches
					have relative links. this is expensive to do, but there's no other option i can see.
					
					
					summary: relative paths seem less wrong, as they work as expected unless you do a
					"bad"/"dangerous" type of copy (copying a object in a way that would break the
					link.) we just need to be able to detect when that happens, and then we can
					warn the user and offer possible fixes.
					
					relative paths breaking examle: the paths from a document to its tags
					break when you copy the document to a different level of the
					hierarchy. 
					
					- when a relationship is created with a "backwards" path (../../.. ...), 
					we can mark the proots which the path crosses as "unsafe to copy to
					a different place in the hierarchy" (if you duplicate one of these unsafe
					to copy proots, there should be no problem because the relative path still
					works.)
					
					**/
				   
				   
				   
				   /**
					guideline:
					
					embedded object: has no history. e.g. a line, a box.
					persistent root: has history. e.g. a photo, a group of lines (if desired.)
					
					
					**/

				   
				   /*
					root creation ideas:
					- the destination version/commit can be written before the
					update to the place where the reference is stored
					(not sure if useful).
					
					- api needs to handle copy vs new, blank slate
					(this determines the parent of the new commit
					for the roots contents - no parent, or parent pointing to copy src)
					
					
					
					
					*/