#import "TestCommon.h"

#if 0
void testUserRequirements()
{

// Requirements
// 
// 1. user creates a photo montage, and drags in a vector graphic which was another persistent root.
// - the vector graphic can be modified externally without affecting the photo montage.
// - the photo montage can be branched and the vector graphic can be edited without affecting the original
//   branch of the photo montage.
// - the vector graphic can be updated to the latest changes made outside the photo montage.
// - the montage can be reverted to an older version, which will also revert the vector graphic (when viewed
//   from within the photo montage - should not affect other branches or other documents where the vector graphic is embedded)
// => the version of a persistent should encapsulate the versions of embedded persistent roots.
// 
// good	.
// 
// 2. page layout
// - figures can be added by reference, either to “whatever the current branch of this is” (i.e. link to
//   branch selector) or to a particlar branch or regular copy.
// 
// - photo library:
// 
// 3. project containing 2 composite documents, which have embedded links to each other
// - possible to create a totally independent copy of the project to use as a base for something else, and
// the links between the 2 inner documents still work?
// 
// 4. QuArK-like project can be branched, tagged, and reverted, and contains inner documents which can be 
//    branched, tagged, reverted, undo/redo.
// - the project can be treated like a document from the outside. it can be copied. 
// - there should be a way to get an undo track that just covers the organization of the objects in the  
//    project and their labels
// 
// 6. same uuid = different versions of conceptually the “same thing” (identity), different uuid = different 
//    thing (different identity). copy creates new identity.
//         MMM sounds reasonable
// 
// 
// 
// 
// Quentin: “Another point worth to mention is the fact that almost no users will use branching I
//  think. Let's suppose Étoilé ends up with the same audience than Mac OS X or Windows. I doubt 
//  that more than 5 or 10 % of the users will ever use the branching ability. For these users, it's 
//  going to be a very important feature though. 
// My doubts about automatic branching are based on the troubles I get into when I try to explain branching 
// to people with various computer experience levels. I get replies such as "why making copies is not good
// enough to work on document variations". If I explain you cannot merge the changes, the reply might be 
// "merging changes would be nice but I'm not interested in this 'branch' concept. I just want to create 
// copies and merge changes." 
// I now think this informal approach to branching might be a better way to expose the users to it without 
// too much mental burden. This makes me realize the important thing is the "merging" support rather than
// the "branching", and branches and copies should really be equivalent. 
// For users who knows about branches and wants to organize things cleanly, we could provide some UI that
// exposes the branch concept and the possibility to turn copies into branches or vice-versa. This would a
// ct as a thin organization layer that remains optional.”
// 
// 
// 
// types of copy
// 
// XXXXXFor an embedded object, I can think of two
// XXXXX return an independent copy of the embedded object, with relabelling every object to a new uuid and 
//       pdating any references inside the copy which refer to Xold uuids to new uuids.
// 
// XXXXXXFor a persistent root, I can think of a lot more:
// XXXXXX "copy history graph": return an independent copy of the entire history graph (like doing "cp -r 
//          some_git_repository new_copy". This is what I was thinking of doing in nested versioning 
//          upon ever commit, all nested persistent roots inside an outer persistent root would be copied
//           in this way.)
// XXXXX- "create branch": create a new branch off of the current state of the persistent root, and 
//         return a link which tracks the latest version of the persistent root on the new branch 
//          (interestingly, this is the only one that performs a _mutable_ change to the persistent root)
// XXXXX- "non-versioned copy": return a non-versioned (embedded object) copy of the current version
//           of the persistent root, without any relabelling. 
// XXXXX- "non-versioned relabelled copy": return a non-versioned (embedded object) copy of the current  
//          version of the persistent root, with relabelling every object to a new uuid and updating
//           any references inside the copy which refer to old uuids to new uuids.
// XXXXX- "link": (not really copying) return a link to the persistent root which will continue to 
//          track further changes  (i.e., just the persistent root's uuid)
// XXXXX- "link to version": (not really copying) return a link to the current version of the  persistent 
//          root which will not track further changes (i.e. a string "uuid:version")
// XXXXX- "new persistent root": create a new persistent root with an empty history graph, and insert 
//           as its contents the "non-versioned relabelled copy"
// 
// There is really just copy and link. The key is that you can modify the copy source after making the 
// copy and the changes won’t show up in the copy. The above deals with implementation issues and UI
// issues that don’t really need to be treated as different types of copy. (e.g. “new persistent root”
// could just be a copy and a flag to hide the source history graph).
// 
// 
// 
// Comments
// 
// - hope to express all copying behaviours with 2 ui labels: “link” and “copy”
// link: can be changed to copy.
// copy: can be updated to a different version of the object, and changed to a link
// 
// - duplicate is just a shortcut for copy & paste in same container.
// 
// 
// copy operation invariants:
// for a copy C of a document D,
// for a sub-document E of D which was inserted with “copy operation”:
// C contains an E’ which can be modified without affecting E
// E’ can be opened 
// for a sub-document F of D inserted with “link operation”:
// the link in the copy points to the same place.
// 
// commit vs user copy:
// 
// what exactly is the difference between copy and link?
// — probably just metadata.
// 
// 
// 
// problem with nested versioning:
// - branching a container should totally copy the history graph of the inner object
// 
// new design example:
// 
// persistent roots:
// 1. photomontage
// contains copy of 2 at version A
// 2. photo
// 3. photolibrary
// contains copy of 2 at version A
// 
// ** persistent roots can be in multiple states at the same time, 
// so they can be in multiple containers at once **
// 
// scenarios:
// 
// open 2 from within 3
// 
// problem: we don’t want copies of template persistent roots to have the same uuid. (Suppose a root object
//          is something like a template for a form letter, or a template for a resumé, etc. When you make a 
//           copy of this, you want a new root object with a new UUID, since the final letter/resumé you 
//           produce should be a distinct object. In contrast, you might want to create branches of the template,
//           to store slight variations on the template - like different font/color choices, different wordings for 
//         a form letter - and these would make sense as branches, and should share the same UUID with the basic template.)
// 
// also need to be able to copy a template with embedded root objects and have copies of those made too.
// 
// 
// compare with unix filsystem:
// fs = { root = inode1; // will be a directory
// inodetable = { inode : byte_array  // file inode
// | // or
// {“string1” : inode1; …} // directory inode
// }
// }
// 
// copy a file has 2 steps:
// - create new inode with copy of byte array
// - insert a file somewhere in a directory linking to the new inode
// 
// 
// 
// 
// coreobject idea:
// 2 namespaces: copies of same object are stored in the object history namespace (i.e. copies of a persistent
//   root which don’t change the uuid, i.e. they’re braches).
// copies of the object which are new objects are given new uuids’, ie they’re new persistent roots.
// 
// -make sure copy is properly transitive
// 
// still not sure about “current branch”/“current version.
// 
// 
// ‘relative reference’ requirement:
// “suppose B is embdedded in A.
// if a commit to B does not cause a synthetic commit in A,
// then A’s reference to B must be stored in such a way that it refers to the new version after this latest commit.”
// 
// I hope the ‘relative reference’ requirement can be satisfied… because we want all commits in a given persistent 
//   root to be semantically meaningful.
// 
// two possibilities for storing branch data:
// 
// ( by branch data, I mean the pointer to the current version,
// and maybe auxiliary info for undo/redo - which direction
// redo should go in.)
// 
// 1. branch data is kept at the site where it is embedded (i.e., in the versioned, “data” namespace)
// => This will screw up undo. i.e. for a document embedded in a project, moving the ‘current version’ pointer 
//     of the inner document will cause commits in the project (non-semantically-meaningful commits?) -> then undo in
//     the project will have to navigate over the commits which undo/redo changes in the inner document
// 
// 2. branch data is kept in the history graph data structure (i.e., in the non-versioned, mutable “history” namespace”) -
//     but current branch is kept in the versioned contents.
// => This means that reverting to an older version of the container means the inner document stays at its current
//     version, which is bad - the user 
// 
// 
// 
// Sounds like 2 is the way to go.
// 
// supposing we use design #2:
// 
// -suppose b is embedded in a
// =>create the branch data in the history graph, and create the pointer to the branch data (which branch) 
//   at the embedding site
// 
// -to clone b (new uuid) => clone the documents embdedded in b. update the uudis where the sub-documents 
//   of b are embedded in b. history can be discareded.
// 
// -to branch a, b and all other embedded root objects need to be branched also.
// 
// 
// will accumulation of “garbage” branches be a problem? well, if we
// -embed a peristent root (creating a branch)
// -delete it
// -undo
// -redo
// -embed it againg (creating another branch)
// 
// should be ok.
// 
// seems like we actually lose nothing without nested versioning. we can undo branch switch, since the 
// current branch pointer is versioned. we can undo merge since it’s a normal commit. the history graph
// will just get a bit ‘overgrown’ after a while, but that’s necessary for undo, and we can always prune it.?
// 
// 
// can we get away without ‘default’ current branch? (this implies, “can we get away without ‘default’ 
// current revision since current revision is stored in current branch)
// 
// suppose we just store the current branch of the “root” (‘/‘) persistent root. this lists the current 
// branches of all contained objects, etc, etc, so in this way, we have defined the current branch and 
// current revision of every object.
// 
// 
// how will the object context api look with all of this?
// 
// - the branch of embedded objects is determined by versionable data in the current editing context.
// 
// we can cache the current version and current branch of all persistent roots. We just have to monitor
// for commits which 
// a) are being made on the “global current branch”
// a)_change_ the current branch of an embedded root
// then we update the cache.
// 
// what about branching the ‘/‘ object? copies need to be cheap, therefore branching / is cheap.
// 
// 
// deletion questions deleting a persistent root is permanent.
// it is possible for a persistent root to be totally inaccessible, when:
// - all references (links or embeddings) have been 

}
#endif