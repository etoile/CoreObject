
CoreObject Reflections May, 2012
==========================

Things that are definitely done the correctly in nestedversioning:

- no separate metamodel
- handling of composite relationships, treating weak/many-to-many relationships as search queries.
- tree structure within a persistent root defines copying semantics.
- branch = copy
- cheap copy

nestedversioning more or less works. my only doubt is, is it too complicated? 

It quickly create very complex structures, e.g. an outer persistent root called “project”, with an inner, embedded persistent root called “document”, with an inner, embedded persistent root called “shape”...

What if we disallowed nested persistent roots?

- We would have a flat namespace of persistent roots, which maps the persistent root UUID to the current version (or to current branch, with a branch : version mapping)

- In this model you could still have embedded objects that are references to persistent roots by UUID, by UUID:branch, or by UUID:version (but this last one is sorta a nested persistent root.)

- You could still implement a deep copy operation (this should probably be the UI default), but it would not be cheap - you would have to search for all referenced persistent roots, decide which ones to copy, and then copy them (copying an individual persistent root is still cheap.)

	- So in NestedVersioning, *commiting is not cheap*! This is exactly
	the same underlying reason that a “deep copy” in an un-nested-CO would not be cheap

	NestedVersioning pays the “cost” for cheap copies of the outer object of a deeply-nested persistent
	root structure on every commit to inner
	objects. non-nested-CO pays the cost only on copies of the outer object.

	Even then the cost of the deep copy is just:
	c * N
	where c is the number of bytes for a CoreObject object structure (say 32)
	and N is the total number of nested embedded persistent roots. Put another way,
	it would be a similar cost as traversing a unix directory tree and writing
	down the filename of every file. This is still orders of magnitude faster
	than actually copying the contained data like “cp -r /home /media/backup/home”
	would be.

- you lose the “for free” undo/redo of things like: create branch, rename branch, delete branch, create copy of branch as persistent root, move persistent root into branch,...

- it may be that the extra power provided by the nested versioning model is overkill

Now thinking that a “flattened” nestedversioning could actually be an improvement.

- simpler mental model.
- more flexible undo/redo model: expose enough information (tree structure) to let the user implement their own script based undo, incorporating actions external to coreobject 


merging model based on cherry-picking
=====================================

	trunk0—trunk1—trunk2——trunk3—trunk4
	    \-branch1-trunk1'-trunk2'-branch2-trunk4'

' indicates  that a change was ported from another branch

The visualization would highlight the differences between trunk and branch: the addition of commits “branch1”, “branch2”, and the lack of “trunk3”.

Merging branch into trunk would consist of computing the set of commits in branch but not in trunk; then stepping through and applying them to trunk in sequence.


Thing to think about
===============

using commits to determine what to merge can “lie”. we could go to something finegrained and actually look at the contents of every commit (thinking of a commit as a set of edits, with a label attached for the user’s convenience.) is this how darcs works?

##Flattened CO design doc

- There is no “root version pointer” to a document which is the store toplevel like in NV.
- The store contains a set of persistent roots, which are structured the same as in NV, but now they are first-class.
- Operations on persistent roots can be lifted from “docuemt-editing” level ops to toplevel, first class ops.
    - This is good because it lets us disallow unsane ops (i.e. in NV you can move a branch from one proot to another unrelated one)
    - But we should still allow all of the cool ops like “break off branch as new proot” and “group copies as single proot”

Eliminate paths.

Since the persistent roots are no longer just plain old data, we need a new set of plain-old-data things that can be included in documents to create persistent-root references.

1. hard reference to a PROOT at a specific VERSION. In this case specifiying the PROOT is redundant, but semantically we should as a sanity check. Could get same effect with just DOCUMENT VERSION ID.
2. Soft link to CURRENT VERSION OF CURRENT BRANCH OF PROOT (just a proot UUID)
3. Soft link to CURRENT VERSION OF SPECIFIC BRANCH OF PROOT (proot UUID : branch ID)

That's all.

IDEA: whenever you make a commit, it should be tagged with the branch you are currently on. This will only be used for giving better visualization. 

##Merging vs. cherry-picking
if a feature is cherry picked onto 2 branches, and later reverted on 1 branch, merging that into the other won't merge the revert as you might expect.

Thinking more carefully about what state should be stored in the mutable persistent roots.

Really, every branch should keep track of all commits made while on it.

This way we know if you do:

    .. a .. b .. c .. [undo] .. d .. e .. 

that c is still part of the branch. currently we only allow a linear list.

Should we have “commit grouping” as a replacement for rebase? the problem is if you group a set of commits interspersed with other changes, you can’t hide the fact that the changes aren’t really grouped 

We will want script undo so we can do
- undo across all changes in store
- undo across one persistent root or several.

Copying a branch should clear its mutable state.

todo: make a simple versioned text editor

goal: we want to be able to integrate undo/redo with external sources (e.g. window manager)