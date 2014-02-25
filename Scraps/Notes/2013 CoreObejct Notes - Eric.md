Summer/fall 2013 CoreObject Notes
=================================

Storing dictionary values in a embedded object:

one option:

	object {
	"org.etoile.object-name" : "Drawing dictionary",
	"org.etoile.enitiy-name" : "org.etoile.DrawingDictionary",
	"user.blue" : ...
	"user.green" :
	"user.red" : ..
	}

another option:

	root: {
	"mapping" : ( keyValPair1, keyValuePari2  )
	}
	
	keyValPair1: {
	"targetType" : "org.etoile.drawing"
	"dropType" : "org.etoile.shape"
	}
	
	keyValPair2: {
	"targetType" : "org.etoile.spreadsheet"
	"dropType" : "org.etoile.shape"
	}

Persistent root Granularity:

-   Music library, photo library - each photo / music song is a persistent root
-   Photo library containing 50000 images has one 
-   Code editor: project is a persistent root: too many references between classes/methods 

CoreObject general:

-   every embedded object should be stored with a schema version and name (except cases like an object representing an NSDictionary)
-   COObject needs to be notified when relationship cache changes incase they cache cache values.

CoreObject design decisions:

-   Support another reference type for copy: NOT a composite reference, but acts like one for the pruposes of copy. see the copy keynote, and the yellow arrows
-   Quentin argued for forcing COObject not to allow any ad-hoc properties; all must be set in metamodel.

Relationship cache:

-   DONE Move to COObject/COPersistentRoot for efficiency.
-   NO COObject metamodel should have 'parent' property
    -   It does make sense for an object to be in multiple composite relationships at once.
    
Metamodel constraints:

-   Add checks that derived properties are not persistent
-   Add check that parent property is derived
-   Add check that one side of an opposite is derived
-   Add a check that the derived side of a multivalued opposite is unordered
-   if "isContainer" is true (the property is a reference to the embedded object's parent), then we must constrain the property to be NON PERSISTENT

COSQLiteStore:

-   Add "parent branch" metadata to a branch that records which branch a branch was forked from
-   Record in COPersistentRootInfo copySource that records the persistent root UUID a cheap copy was made from (or just a flag, isCopy?)

COEditingContext

- support "transient roots" in a COEditingContext. These are COObjectGraphContext wrappers. Or, support creating a persistent root in code, then calling "freeze" which will make it read-only and prevent it from being committed to disk

July 11
-------

- We've agreed to handle loading persistent root contents in one batch.
- Quentin convinced me that we need to transparently unify the cross-persistent root references as regular COObject references.

Async faulting / nonblocking faulting:

- We will need an asynchronous loading API where you access a contents property, get an empty set, and then later get a notification like:

  COObjectDidFinishLoadingNotification

Async Faulting outline:

1. Object manager accesses a library persistent root with 50,000 child objects. These child objects are cross-persistent root references (serialized as COPath) to root objects of 50000 persistent roots.
2. At the time of loading the library persistent root, we also load the 50,000 root objects.
3. The 50,000 root objects are a special kind of async fault. They have 

We also agreed to move reference storage to some central object, outside of COObject.

We also agreed to move to something like this (from NestedVersioning):

We agreed that cross-persistent-references should give you a fault for the root object with no references (empty "contents" property) and then use the async faulting to load it.

We also agreed to move reference storage to some central object, outside of COObject.

Todo:

-   test composite
-   composites must always be valid at the COObject level -\> can't have composite cross-root references

COItem should load with just UUID/COPath references, and cache the COObject pointers at first access.

but we will try to present it simply (e.g. a persistent root only gives access to its current branch object, unless the user explicitly asks to open a particular branch).

We can avoid the "eclipse problem" (open projects in a workspace determine cross-reference resolution.).

Cross reference resolution will be resolved by:

- explicitly mentioned branch in the cross-reference
- "main branch" (persistent value), stored in the store.

Commits:

How can we get easily pluggable cross-root references?

Problem description:

I had a copy of EUI and CO in a directory. Another dir contained a different version of CO. To try that version with the other EUI, I just copied them in to the same directory.

=\> Cross-root references were resolved by looking in the current directory

It can be interesting to decouple cross-references from versioning.

**Things to discuss with Quentin:**

- How should UI's watch for changes in COObjects in general? (I want an asynchronous fault loading to be just like any other change (reloading an old revision, undoing, etc).

**Merging**

-   merge resolution process needs to be persisted as commits.
-   If partially merged stuff is persisted as commits, it will break COObject validation in the same way merge markers break file formats.
