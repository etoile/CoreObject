Notes from chat, April 2013
====

- We could look at building an asynchronous COStore wrapper API that
looks like:

		 [[[self store] updateDocument: [self editedMessage]]
		setCompletionBlock: ^()
		        {
		            isSaving = NO;
		        }];

  but only after a 1.0 release. It could be built on top of the
  lower-level, synchronous API.


**Relationship integrity feature in ObejctMerging and CoreObject trunk**

- code for caching the inverse of relationships is ugly, and mixed in to
COObject (-updateRelationshipConsistencyForProperty)

- a larger problem is, the inverse of relationships is persisted. 

- This is ugly because it means storing two pieces of data, one of which
is purely calculated from the other. This should be harmless but it
opens up the potential for your store to contain inconsistent data.

- I remembered the problem related to diff/merge:

  ]When you compare to revisions where one or more relationships changed
between the revisions, the diff will contain a mix of the real,
semantically meaningful change (add shape to document) and
non-semantically maningful change (set parent of shape to document)
which is another way of stating the first change. Having the mix of
semantic and derived changes mixed in the diff made my merge algorithm
buggy, and IIRC was the reason that selective undo was buggy in my old
ObjectMerging prototypes ;-).

- Based on the above problems I decided to switch to a design where only
the semantically meaningful side of relationships is persisted and
considered for diff/merge, and to consider the inverse side of
relationships to be discovered by doing a search query (altough we
maintain an in-memory cache when loading an embedded object graph so
it's fast)


**CORelationshipCache**


- TODO: Eric: benchmark with building a 100k object graph in a way that
requires looking up parent objects a lot. If it's too slow, one
optimisation is storing COObject pointers (weak references, because the
strong references would be in COEditingContext) directly in the
relationship cache. Look at removing the relationship consistency code
from core object trunk and integrating this.


**Persistent root branch model:**

- COSQLiteStore at https://github.com/ericwa/NestedVersioning/blob/afc1109/COSQLiteStore.h
and CoreObject trunk very similar

- branch in my fork = commit track in trunk

- In trunk, a persistent root has both a current branch and a main
branch. The main branch is used to resolve inter-persistent root
references coming from other persistent roots that don't specify an
explicit branch. The current branch determines which branch is opened
when double-clicking. I'll add this feature to my fork.

**Persistent root GC/Deletion models**

- **GC only**: really bad because it's not obvious to the user what
references are keeping a persistent root alive. Further problems noted
at
[https://github.com/ericwa/NestedVersioning/blob/afc1109/COSQLiteStore.h\#L172](https://github.com/ericwa/NestedVersioning/blob/afc1109/COSQLiteStore.h#L172)

- **explicit deletion, with persistent reference count:** so even after
a user deletes a persistent root, it will be kept alive if there are
references (not just references from tags, but stronger references
indicating that the persistent root is linked to from a composite
ocument). (*aside: this suggests that inter-persistent root references
should have a flag indicating whether they are weak or strong.)*One
thing I don't like about this design is you get a weird "zombie" state
where a persistent root is deleted but still alive because of the
references. I'm worried that this will be confusing to users when they
find a persistent root still exists which they thought they deleted.

- **explicit Deletion only**, with two-step deletion (first mark as
deleted (undoable), second run finalize deletion command on persistent
root (not undoable)): seems to be the cleanest solution. When the user
deletes a persistent root that is referened elsewhere, we can always
show a warning (showing exactly where the references are, since we have
them cached), and the first step of deletion is always undoable.

**Branch and Revision GC**

I presented the design used in
https://github.com/ericwa/NestedVersioning/blob/afc1109/COSQLiteStore.h
where branches have a two-step deletion just like persistent roots. The
first step simply sets a "Deleted" flag to true in the store, and the
second permanently removes the branch.

Unlike branches and persistent roots which require explicit deletion, I
use real garbage collection for revisions. The GC is done in the
finalize method
([https://github.com/ericwa/NestedVersioning/blob/afc1109/COSQLiteStore.m\#L792](https://github.com/ericwa/NestedVersioning/blob/afc1109/COSQLiteStore.m#L792)).
So, if you delete a branch which is the only branch referencing a
sequence of revisions, those revisions are acutally deleted from the
store (including the item data) when
-finalizeDeletionsForPersistentRoot: is called. Any attachments which
are made unreachable by deleting any unreachable revisions are also
deleted (currently requires a separate call to
-finalizeGarbageAttachments).

**Tags use case**

We discussed a use case where a Tag embedded object in one persistent
root references a document persistent root.

The design we ended up with is:

-store references in the tags side rather than the referenced
persistentent root, so that undo/redo on the persistent root does not
undo/redo tag creation.

- when deleting the document persistent root, leave dead reference in
the tag alone (tags will just ignore dead refs).

- We could make a commit in the tag persistent root to delete the dead
reference, but this adds "noise" to the undo history of the tag
persistent root. If the user undoes a few steps, they will recreate the
dead reference anyway, so we still have to handle dead references

- Presentation of dead references should probably depend on the UI
situation - tags: ignore them, link in a composite doucment: show a
broken link icon?