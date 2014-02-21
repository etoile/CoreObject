Things I have realized

- Selective Undo requires to explicitly model operations, which means
message-based persistency to be used requires an operation model
underneath. In the end, there is no real advantage in message-based
persistency, it just involves maintaining semantic mapping between
operations and messages (can derived from the metamodel). Writing an
explicit commit in each persistency triggering method is also required
in the current CoreObject if COProxy is not used.

- Given that the new CoreObject leverages diff to derivate operations,
the new CoreObject is more operation-based rather than state-based (it
appears to be state-based at first sight though)

- Deducing the operations by diffing means the user is less likely to
implement the persistency wrong (no worry about reasoning on
deterministic replay, message arguments as primitives etc.). We have no
easy way to provide a checker for the existing message-based
persistency, unless we provide a metamodel, but then we are back to the
initial point, the metamodel makes message-based persistency
unnecessary.

- Requiring an explicit metamodel is the closest thing to a silver
bullet  (a spec to reason on persistence)… ;-) It forces the user to
reason on its model and persistence, it gives us the ability to reflect
on the object graph in various ways: write various checkers, store the
core model with a better representation than code (like serialized UI vs
UI created in code), support serialization/copy without writing code,
generate class and custom instance based on requirements
(ETAdaptiveObjectModel vs a real class), support inverse relationships
in a clean way, support optimized/localized diff strategies (e.g. by
detecting/tracing damaged regions in the object graph), integrate other
core object models than COObject (extend primitive and entity types
given we won't have to unlike CoreData, we can do it because we don't
have to fit our data model in a SQL db, we use serialization and
serialization is extensible), a place to declare how the objects are
indexed etc.

- Diffing the whole object graph won't work with compound documents, but
the metamodel can be leveraged to implement relatively safe localized
diff. Various checks can be used to make it as safe as the full diff (In
fact, I think that's probably won't be needed)… Object graph integrity
check based on the metamodel, object graph comparison check by comparing
the current object graph and the same object graph deserialized in a
separate editing context, test suite that executes various user actions
and computes full diff and localized diff to check their equality.

Goals
-----

- Temporal Persistency
- Live Collaboration & Merging
- Name Service (Grouping and Tagging)
- Indexing (Metadatas)
- Distributed Storage
- Export/Import 

More Long-Term Goals
--------------------

- Temporal Indexing
- Ontology Matching/Alignment (Tags and Metadatas)

Requirements
------------

- Generic Model Easy to Customize (COObject and COGroup subclassing)

- Foreign Model Compatibility, would involve protocols/mixins and
special constraints but require no subclassing (e.g. EtoileUI,
CodeMonkey, may be LanguageKit AST etc.)

- Non Persistent Objects supporting the same basic Core Object protocol
(COObject and COGroup protocols)… aka Name service backend support
(FUSE, UI, FS, Flickr, del.icio.us etc.)

- Should sustain several commits/serializations per second

- Localized Diff Strategy for big object graph or documents

- Little and Hard to Break Serialization Code (by leveraging the
metamodel)

- Metadata DB is just a cache (means no schema upgrade)

- Embedded/Bundled Core Objects Inside Persistent Root (like storing a
core object inside a persistent root but not exposing it outside)

- Organization and Tagging (COGroup)

- Property and Full-Text Indexing

- Soup-like Acces to Core Object Properties (and custom classes as views
per app)

- Local Concurrency Control (probably with a lock column in the UUID/URL
table or should we use merging?)

- Commit/Update Feeds as Distributed Notifications, other apps which the
same core object loaded in memory, reloads the affected core object when
the catch an commit/update notification

- Deletion Model with a trash group

- History Tracks/Aggregator which can subscribe to the update/commits
posted by any core objects and present a combined/aggregate history
(somewhat similar to RSS/Atom feed aggregators).

- Collaboration Stuff (probably several points but I haven't
investigated this at all, I let you present the thing in details)

- No Name-based references, UUID everywhere (version, groups, core
objects, branches, metadata db etc.)

- Helping the user to manage tags and groups, with a basic ontology
matching that detects uppercase/lowercase, singular/plural, genre,
erratic characters (spaces, punctuation) and synonyms (e.g. Photography
vs photo vs photographies vs picture vs photography!)… This should be
put in a distinct framework so we can reuse it to implement the
Newton-like Assistant.

More Long-Term Requirements
---

- Solve All Undo Puzzles as Mark and Retrace does (this ensures we
preserve user intention as much as possible when resolving conflicts
automatically). Based on my readings, Mark and Retrace is the only
simple model that can solve all the Undo Puzzles. The same result were
recently achieved with OT but this raised the OT model complexity a lot
(according to the Mark and Retrace authors).

- Zero Data Loss (not loosing even a single character in a text editor,
I suggest a write ahead log by using EtoileSerialize)

- Localized Diff Strategy with damaged range hint (for non-structured
text editor)

- Partial Deserialization for attributes? (if an attribute class is not
loaded we keep the data serialized in a map per object and write on the
serialization stream at the right place when the owner object is
serialized)

- Metadata DB shared between multiple users with a security model
(capability based?)

- Garbage Collector for history

- History and Object Bundle Compression

- Rich Ontology Matching (semantic analysis and leveraging existing
ontologies for a domain)

- Synchronizing Tagging and Organization with external services (Flickr,
del.icio.us etc.) by leveraging the built-in ontology matching.

----

Below are discussions about more specific points…

Deletion Model
----

I suggest to add every new core object to a default group (customizable
based on the core object type e.g. photo into the photo library), then
when a core object is removed from a group which was the last holding a
reference on it, we move it to a special trash group… We wouldn't use a
gc to collect unused core objects and never erase any core object unless
the user empties the trash group. 

This approach is simplistic in the sense it doesn't track core objects
referenced  elsewhere than in groups, so in the we might end using a
persistent retain count per core object… However this can result in
cycles, so we'll probably have to use a real GC in the long run or a
double retain count. 

Dealing with Cycles with a Double Retain Count
----

If we use both a overall persistent retain count and a group retain
count, then we can consider that when the group retain drop to zero, we
can do a simple cycle detection by checking whether the core objects in
the cycle have also their group retain count at zero. If all the group
retain count are at zero is in the cycle, we can move all these core
objects to the trash group.


Metadata Server
---

A metadata server represents a single distributed core object store, it
uses a URL/UUID table to track local and remote core object bundles that
belongs its core object graph. In addition, it indexes core object
properties and the core object graph history. URL/UUID mapping put
aside, it is just a cache.

- SQL database
- Full-text indexing is delegated to the SQL db (or LuceneKit if
needed?)… Need to check whether Lucene supports to have a version
attached to a document field for temporal queries. I doubt that's
possible.
- Tables
	- Objects, the UUID/URL mapping
	- History, the core object graph versions (we might need some additional
	tables… e.g. check points, merge points etc.)
	- Property\_Type, tables such as name\_String to store the indexed
	property values and using 3 colums: UUID (core object ref), Value,
	Version (core object version). Temporal queries would be evaluated
	against these tables.
	- SchemaVersion, a dumb table where we add a row with the date and
	version, each time we update the metadata db schema


Although we have a SchemaVersion table, we don't upgrade the schema and
migrate the data, we just pull out the URL/UUID list, discard the entire
database content, declare the new schema and reconstruct everything by
reading every object bundle content as needed. That's slow but dead
simple, and can be used to recover from a metadata db corruption or
importing existing core objects previously owned by another metadata
server.

We probably want to offer the possibility to disable temporal indexing
and only index the last version.

Should we support a CoreObject use case without a metadata server?


Object Bundle (aka Persistent Root and COStore and COStoreCoordinator class)
----

An object bundle is a directory whose name is usually uuid.coreobject
but which can be renamed. It contains:

- Datas/Keys mapping reflected on disk as Files/Names. Most files will
use a history UUID as name.
- Info.plist
	- metadata server / core object graph UUID
	- branches  history node UUIDs	
	- main branch history node UUID
	- current compression scheme
	- persistent retain counts or gc hints
	- serialization format  and version?
	- core object version last use to read/write?
	- last indexing?
	- metamodel related infos?
	- fallback classes?
	- other infos up to the dev

We might need directories inside the bundle like format/version/data.
For example org.etoile-project.keyedarchiving-xml/3/uuid or
org.etoile-project.etoileserialize-binary/2/uuid. The reverse DNS scheme
ensures multiple apps can access the same core object and extend it
safely.

-setData:forPathKey: or -setData:forKey:atPath: in addition to
-setData:forKey:

Probably a good idea to encode the type of the data in a file extension…
So -setData:ofType:forKey: rather than -setData:forKey:

I'd rather change the name to COObjectBundle or COStoreUnit to elimate
any confusion with the main store represented by the core object graph
as whole.
