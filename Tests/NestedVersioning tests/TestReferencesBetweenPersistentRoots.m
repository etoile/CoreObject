#import "TestCommon.h"

#if 0
void testReferencesBetweenPersistentRoots()
{
	
//	Tricky cases for nested versioning:
//		
//		- project containing 2 composite documents, which have embedded links to each other
//		
//		proj/doc1
//		proj/doc2
//		
//		If we maintain this big “uuid => current path in store / inode” table,
//		the embedded links can just be uuid’s, and we can do the table lookup to
//			get the current version of the link target.
//			
//			Potential problems: copying both doc1 and doc2 (together) to another project,
//			could cause the inter-document links to break unless we fix them when copying
//			(beacause doc1 and doc2 will be assigned new uuids.)
//			
//			In general when copying an arbitrary subtree, since we have to rename every
//			object, we can update update all references to the old name within the tree
//			to the new name (but not references to the old objects coming from elsewhere
//							 in the universe).
//			
//			one of my concerns here is the distinction between a “user-copy” action and a “system copy” action.
//			a user initiated copy renames all of the copied objects (the motivation for that was avoiding
//																	 the “paradoxes” we identified when working on ObjectMerging). and also, we don’t want to have
//			multiple objects with the same uuid.
//			a “system copy” is just a copy without renaming.. so the current assumption has been that
//			system copies take place inside the “persistent root” data structure, so the outer wrapper
//			keeps the same uuid, as do the content uuids stay the same, but the objects themselves
//				may change. (in this way we simulate state change).
//				
//				this relates to how we update the uuid->oid table, how we enforce one uuid = one object
//				(and what constitutes a version of an object vs a different object).
//				
//				one of the goals of nested versioning was that users could cook-their-own version control
//				if they want: they could make a series of copies/snapshots/tags of a subtree, and still get
//					benefits like the ability to merge, cheap storage. the problem, though, is if we relabel/rename
//						the copy, 
//						- merging is no longer possible (or at least, no longer easy)
//						- may interfere with a basic implementation of cheap storage (not a big deal, probably)
//						- we lose the ability to have other objects refer to the ‘latest’ version of this object,
//						because the latest version is only known by the user and not the system.
//						
//						this sounds like an issue of end users vs library users (developers).
//						the uuid->oid table, the notion of what constitutes a version of an object vs a different object
//						is an end-user concern. so end users must be prevented from violating one uuid=one object, but
//						developers may have to be careful themselves.
//						
//						
//						- composite document containing a versioned sub-document which appears multiple times.
//						
//						same problem as above basically; when a user-copy is made of the outer document, and
//	the sub-document is renamed, all references to it in the outer document need
//	to be updated.
//	
//	- project containing 2 documents: “figure” and “cover page”. “cover page” has a link to figure.
//	
//	the special thing about this case is that “cover page” has a dependency on “figure”; 
//	much like an MS Word document with a link to a photo store by reference (pathname).
//	Documents that do that are a pain to work with in general, (and probably scenarios like
//																this gave composite documents a bad reputation) but there may not be anything
//		special we can do except encouraging the user to work with the container rather than the
//			“cover page”. If they copy the container, then the uuids are updated properly.
//			
//			- photo library containing a tag hierarchy
//			
//			see above
//			
//			- pdf library using the user’s tag hierarchy.
//			
//			should work fine. the pdf documents can have uuids of tags that are applied to that
//			document. If the user deletes a tag, there will be dangling references to it, but that
//			is OK. Same with sharing the document 
//			
//			- workspaces with documents drawn from different repositories (i.e. the documents can be in multiple workspaces)
//			
//			user/tags/places/northamerica
//			user/tags/places/southamerica
//			user/tags/photosubject/landscape
//			user/tags/photosubject/portrait
//			user/workspaces/magazinecover
//			user/workspaces/webdesignproject
//			user/projects/magazinecover/reusedlogo
//			user/projects/magazinecover/coverdesign1 has a link to the current branch and latest version of ../reusedlogo *
//			user/projects/magazinecover/coverdesign2 has a link to the current branch and latest version of ../reusedlogo *
//			user/projects/magazinecover/coverdesign3 has a link to the current branch and latest version of ../reusedlogo *
//			user/photolibrary/trips/bc/ we really want to use the hierarchy, but have photos in both trips/bc and best (i.e. only photolibrary is versioned)
//			user/photolibrary/best/
//			
//			* - we don’t care where the object is. So, it should be a uuid table lookup. 
//			
//			- comment “references”/cross-document linking is inherently at odds with versioning. e.g., when you
//           copy a document, references to the document still point to the old version. So following/dereferencing
//           these cross-document references will require application logic
//			
	
	

	
//	A more complicated example is copying a directory hierarchy. Consider a copy of a website:
//	
//	0/index.html
//Contents: <img src=”images/title.png”>
//	0/images/title.png
//	0/style/style.css
//	
//	We can copy the 0 directory and edit it to create:
//	
//	1/index.html
//    Contents: This is an image: <img src=”images/title.png”>
//	1/images/title.png
//	1/style/style.css
//	
//	Note that the relative path used inside index.html is still valid.
//
//	...
//	
//	We would like to be able to do something like this:
//		
//		ver0/index.html
//		Contents: <img src=”images/title.png”>
//		<a href=“posts/15-01-2011/content.html”>first post</a>
//		ver0/images/title.png
//		ver0/posts/15-01-2011/undo0/ver0/content.html
//		
//		Note that posts/15-01-2011 is a versioned document, nested inside the outer document 
//		(the website). Also note: the URL reference in index.html can pretend that posts/15-01-2011
//		is not versioned - this means the reference refers to the current version.
//		

	
}
#endif