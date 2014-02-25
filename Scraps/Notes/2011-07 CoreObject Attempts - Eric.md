CoreObject attempts as of July, 2011
====================================

1. History
----------

###2008 - (Quentin) CoreObject trunk


- persistent object context and objects.
- attempted to record and playback messages. ability to roll back a context to an earlier state

###2010 - ObjectMerging 1

- Attempt to build a git-like RCS. The store simply holds a { key : blob } dictionary.

- Like git there are commit objects (COHistoryGraphNode) that map a set of UUID’s to a set of keys representing that version of the object with that UUID.

- Like git, there is exactly one DAG of history graph nodes representing the entire repository; and there is a tag saved with the repo specifying which history graph node represents the current repository state, so the entire repo can be rolled back to a previous/later version, or switch to a branch, by editing the value of this tag

- Also implemented was a rudimentary object graph diff and merge algorithm. By diffing and merging various repository states, we could perform selective undo of changes.


ObjectMerging 2-4 were essentially bugfixes and refinements on this, switching to a SQLite store, fixing bugs in the frontend model classes, adding support for the EtoileFoundation metamodel code.

###Solved problems

One of the main problems that arose which is largely solved is understanding the impact of compositional (one-to-many) vs weak (many-to-many) relationships, and in particular that moving a sub-object from one document to another needs to create a copy by default.

The metamodel also was problematic. Expecting the library user to provide metamodel objects which are compatible with (all versions of) the objects in the repository is too much to ask. I decided the objects in the repo should be self-describing and not contain explicit references to ObjC class names - they’re data and not necessarily serialized obejcts.

###Problems Encountered

One of the main roadblocks was trying to figure out how to add per-document linear undo to ObjectMerging 4, and branching of portions of the repository. e.g. If we can branch folders containing documents which themselves have branches, are all of the document’s branches themselves branched again?

A second roadblock was realizing that repository-level operations like create branch, delete branch, revert object to previous version, etc. must be undoable for usability’s sake. The ObjectMerging model wasn’t really conducive to making these undoable.

##Future Directions

A large source of my problems seems related to trying to maintain a global namespace mapping UUID-\>object data, and figuring out how to sanely manipulate this global namespace to account for branching and undo.

I’m currently contemplating a newspeak-like “no global namespace” approach. The fact that we use UUID’s everywhere doesn’t make a global namespace any less dangerous; it just guarantees that we’ll never have a name clash (just one of many problems with global namespaces.)

This seems related to questions like, “If I embed a link to graphic C from document B into document A, and then branch and edit document B, ...”

###ObjectMerging design

A revision R is a mapping of all accessible object UUID’s to their serialized state. Making a commit means creating an R<sup>1</sup> revision with the required changes.

###Possible om5 model

think about user model of branching.

how would the capabilities of a system all stored in one git rep differ from one with multiple? (discarding convenience, performace, etc.)

can we get away with one repo (om1 solution)? do we need nested repos? look at what the benefits are from a conceptual perspective.

###Proposal

Branching shouldn’t be given special, “toplevel” treatment. why? well branching-like scenarios will arise naturally (e.g. variations of a photo in a photo manager with the ability to switch which variation is “preferred” and have references to the group of variations show the preferred photo). If we have both toplevel support and ‘home-baked’ mid-tree support, it will be a mess.

 
2. Open Problems
================

Project-centric application
---------------------------

I’m still not sure how to model a project-like document with various revision control possibilities: revision control graph per document, for the entire project, and undo over all changes. What about undo in the document editor vs undo in the project? What about two editor windows open on the same document, and undo for each? What about undo of editor (view) data (scrollbar position, selection, etc, that shouldn’t be stored directly in the model? ) What about branching the project vs branching a document? Linking and embedding cross map and cross project? That about covers all the problems I can think of right now...

	{
	    type = project
	    contents = strong [ ... ] <group, document>
	    uuid = ...
	}
	
	{
	    type = document
	    document_subobjects = strong [ ... ] <document_subobject, group>
	    uuid = ...
	}
 
Boundaries for copy
---------------------

We know we need to create copies of objects when crossing certain boundaries. How do we define these boundaries?

Copy | Don’t copy
---- | ----------
 - move text, photo, sketch from one text document to another | - project - put document into a group / move to a different group  
 - move element from embedded graphic in a document out in to the document  | - Photo library - put photo into an album     
 - move elements in a composite doc from one branch/variation of the document to another| - Music library - put song into playlist

unifying strategy: every object has a ‘closest ancestor document’. documents can be nested. if you move an object to a destination which has a different ‘closest ancestor document’, make it a copy. (even if the dest closest ancestor document has a chain of parents leading to the source’s closest ancestor document.)

Project structure

as a case study app with a rich organizational model, Aperture's data types look like this:

-   images
-   albums (many:many relationship to images)
-   projects (one:many relationship to images, albums, or folders)
-   folders_in_projects (one:many relationship to folders_in_projects or alumbs)
-   folders_outside_of_projects. (one:many relationship to folders_outside_of_projects or projects)
-   library (one:many relationship to folders_outside_of_projects or projects)
