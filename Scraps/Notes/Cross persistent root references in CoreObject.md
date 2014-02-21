Cross persistent root references in CoreObject
==============================================

Handling Dead References
-------------------------------------

I agree that -updateOutgoingSerializedRelationshipForProperty: approach is not going to work, too much complexity to implement it correctly.

For broken cross persistent root references, I would expect/use them for links (unidirectional relationship) inside documents such as:

- compound document 
	- referencing images, styles or texts
	- referencing other compound documents by using a proxy (to adapt the frame and provide a local parent to the referenced composite)
- projects 
	- referencing many other objects

For Hidden References (or enforced Broken Reference deletion), I would expect/use them for relations (usually bidirectional relationships) between objects such as:

- person groups 
	referencing other persons
- library
	- containing images, documents, etc.
- mailbox
	- containing messages
-  tags
	- referencing/tagging arbitrary objects
- calendars
	- containing events and reminders
	- referencing persons/participants

For each deletion, the application code should usually just remove dead references. For ObjectManager, if some object is deleted, the deletion removes it in all Tag objects (previously applied to it). So I think Hidden References for relations would just occur if branches are involved e.g. a person or a person group is branched, the application code is just going to care about the current branch in both cases and just ignore the branches. 

---

I think considering links and relations as two distinct notions is helpful to reason about cross persistent root references in CoreObject. For the same issues, links and relations could require distinct solutions (especially in term of user experience)…

For relations, a person object or a person group must not reference branched objects (e.g. a person or group). For these objects, we just care about the current branches. Branching a person or a person group should be a very rare use case, and this branch must remain cut from the rest of the user objects, until it gets merged or set as the current branch.
For links, a document should support referencing branched documents (e.g. document, image etc.).

May be it's question of:

- Links between Documents, where we need flexible branch references, but were bidirectional/composite cross persistent root relationships don't exist

vs 

- Relations between Objects, where we need no branches references, but were bidirectional/composite cross persistent root relationships exist and are critical

For a more in-depth discussion, see 'Cross Persistent Root Bidirectional Relationship Issues (including composite ones)'.

---

For now, we can probably present dead references just as broken references (by synthesizing marker objects for each COObject subclass, and provide an API to customize such marker objects per subclass or entity).

	@interface COObject
	+ (COObject *)deadReferenceMarkerForPath: (COPath *)aPath inRelationshipNamed: (NSString *)aPropertyName ofObject: (COObject *)aReferenceHolder]

or 

	+ (void)prepareDeadReferenceMarker: (COObject *)aMarker forPath: (COPath *)aPath inRelationshipNamed: (NSString *)aPropertyName ofObject:  (COObject *)aReferenceHolder;
	@end

This previous method could be overridden in subclasses to return correctly configured reference markers per subclasses.

In the long run, we probably want more flexibility, especially if we want to support hiding references. Hiding references is quite hard, it doesn't seem there are many ways to implement it. I think any solution will involve some collection proxies, which means the implementation can easily reusable (should probably be provided as an option in CoreObject, so it can reused to limit bugs and reinventing it in each application). 


1) Broken References kept at commit time

2) Broken References resolved at commit through a delegate method (either by the user or in code)

- Would require a property -[COObjectGraphContext brokenCrossPersistentRootReferences] returning an array of marker objects or  -[COObjectGraphContext brokenCrossPersistentRootReferencePaths]  returning an array of COPath

- a branch or object graph context delegate method such as - (NSDictionary *)objectGraphContex:resolveBrokenCrossPersistentRootReferencePaths: (NSSet *) resolveAll: (BOOL)mustResolveOrCommitWillFail (and may be some extra argument such as forCommitCommand:)

- --> the returned dictionary would contain COPath as keys and proposed objects as values. To delete a dead reference, a Null object would be inserted as value. If a COPath given in argument is not present as key in the returned dictionary, this means the reference must remain unresolved. If resolveAll is YES, this is not allowed by the caller that will raise an exception or report an error.

3) Hidden References (using tombstone idea from OT)


	COArray : NSArray
	{
		NSArray *objects;
		NSIndexSet *tombstoneIndexes;
	}
	
	- (NSIndexSet *)aliveIndexes
	{
		NSMutableIndexSet *indexes =  [NSMutableIndexSet indexSetWithIndexesInRange: NSMakeRange(0, [objects count])];
	
		return [indexes removeIndexes: tombstoneIndexes];
	}
	
	- objectAtIndex: 
	{
		return [objects objectAtIndex: index + [tombstones countOfIndexesInRange: NSMakeRange(0, index)];
	}
	
	- allObjects
	{
		return [objects objectAtIndexes: [self aliveIndexes]];
	}
	
	COSet : NSSet
	{
		NSSet *objects;
		NSSet *tombstoneObjects;
	}

etc.

We would have mutable subclasses e.g. COMutableArray : NSMutableArray

If a property or entity description is marked -hidesDeadReferences, then COObject would allocate COMutableArray rather NSMutableArray, and the same for NSMutableSet or other collection types we decide to support.  For ivars, COObject would enforce the right collection type, as it does currently, by checking the ivars contain collections whose types match the metamodel.


Cross Persistent Root Bidirectional Relationship Issues (including composite ones)
----------------------------------------------------------------------------------

For the discussion below, see also Keynote document: cross persistent root reference semantics.

---

Document vs Objects distinction can be also be though rephrased in term of: Creation vs Representation. Here Creation means creative or crafted work, rather than coming into existence.

A Document is a new creation (that doesn't correspond to an existing real world object), where an Object such as a person or calendar is a unique representation (that corresponds to an implicit or explicit world object). This idea, especially the way I express it just before, sounds a bit arbitrary or abstract… However I think this point to a notion (not well understood and formulated yet) that is important for handling/interpreting relationships if branches are created.

There is a sense of uniqueness for Objects that don't exist for Documents. "You don't create a variation for a person", it doesn't make sense from a real-world perspective, because a person is unique. So this initially leads to the idea that you create variations for Documents, but not for Objects usually. For Objects, you just create copies.

To refine this previous point (a bit simplistic) further: "You don't create/materialize a variation for a person, but you can imagine a variation for a person (e.g. haircut or address changes) and apply it to the real person." 

Now to reformulate this last sentence in term of branches:

- For Documents, branches are public experiments (you can hold references to them from other persistent roots)

- For Objects, branches are private experiments (or reorganization processes underway). For example, you branch a library to remove/add some photos, but this branch will never be (and must never be) referenced from anywhere else, this is just a private experiment. The reworked library branch will remain private until you set it as the current branch, then it becomes public (the official and unique representation for the Library object).

Note: For Containers such as Library,  a persistent root copy doesn't work because it results in multiple parents for a composite. Libraries require deep copies or copies that contain no children. Can we just state that children collection are reset to empty for cross persistent root references involving Containers (if a persistent root boundary is reached during a copy)? Deep copies seem complex and I don't see a clear or common use case. If needed, applications can implement deep copy manually. For example, if a Photo Manager wants to support cloning a library and its content in a single pass, the Photo Manager can implement it on its own.

In the model I'm discussing, you can branch a library to reorganize it though (the photo parent will point on the current branch and not the reorganization branch). 

For this model, the constraint relaxation rules are:

- Current Branches and Persistent Root Copies tolerate no constraint violations

- Non-current branch tolerate constraint violations for bidirectional relationships

---

We could to refine how we describe relationships in the metamodel to support characterizing relationships either explicitly in the property description (e.g. -[ETPropertyDescription isLink]) or implicitly by derivating whether the relationship is a link or relation based on -[ETPropertyDescription type]. This gives the following picture for multivalued properties:

- value collection (element type is NSString, NSNumber etc.)
- relationship
	- link, if both element type is document type (e.g. ETLayoutItem, COOutlineItem, COImage etc.) and owning entity is document type (e.g. ETLayoutItem, COOutlineItem etc. … the type is always a composite document type if want to be precise)  <-- unidirectional only
	- relation, if element type is COPerson, COEvent etc. (in this case we don't consider the owning entity type) <-- unidirectional or bidirectional

Note: From an object graph viewpoint, links are identical to relation for unidirectional relationships e.g. COImage link in a compound document.

For projects as documents (see classification below), we might want to support both links and relations inside a composite document (e.g. by giving the possibility to override -[ETPropertyDescription isLink], by default computed according to the rules outlined just before). Think about this point…

The result of the model describe above is that nothing changes for unidirectional references across persistent roots, but for cross persistent root bidirectional references:

- from Objects to Objects (or Objects to Documents), the cross persistent root references would just be maintained for the current branch of each persistent root. For branches as private experiments, bidirectional constraints would be relaxed to tolerate some constraint violations (e.g. you cannot navigate back and forth on a relationship crossing persistent roots using 'children' and 'parent' if some references point to objects outside the current branch).

- from Documents to Documents, bidirectional references are forbidden, but can be simulated using proxies representing links if needed. A proxy maintains two relationships: a bidirectional one to a parent inner object inside the host compound document and another unidirectional one that crosses the persistent root boundaries)

- from Document to Objects, bidirectional references are just forbidden e.g You cannot have a Compound Document holding a reference on a Person and the Person referencing the Compound Document as its parent. However holding a reference to a Person object through a unidirectional reference its just fine.


- Document
	- Composite (a creation unit)
		- Outliner Document (outline nodes)
		- Compound Document (layout item nodes)
		- Structured Text Document (text nodes)
		- Diagram (layout item or diagram nodes)
		- Video/Music Editing Document (tracks, resources) -- could be better named Structured Video/Music Document. See comments below in Object -> Project
		- Map (locations, regions, paths)

	- Simple (usually a Media document… or some basic data type which can viewed/edited)
		- Image
		- Sound
		- Text
		- Music/Video Track
		- Message -- if the message uses a compound document format, it can be considered as a composite document too
		- Note

- Object
	- Composite (an organizational unit)
		- Library (objects) -- 'objects' can contains documents
		- Tag (objects) -- 'objects' can contains documents
		- Tag Group (tags)
		- Project (documents, persons, messages, calendars, notes) -- projects are large organizational units for workflow
			- IDE Project (source code documents, resources, dependencies, products, persons, messages, calendars, notes)
			- Video/Music Editing Project (tracks, resources, persons, messages, calendars, notes) -- in some case, the user or application could treat it as composite document to get other constraints or behaviors especially for tracks and resources relationships… Figure out use cases and meaning, or am I just inventing a solution without a problem here?
		- Folder (objects) -- 'objects' can contains documents
		- Calendar (events, reminders)
		- Map (locations, regions, paths)
		- Mailbox (messages)
		- Person Group (persons)
		- Playlist (music/video tracks)

	- Simple (usually a very simple object,  or representations for concrete objects or abstractions other than documents in the real world e.g. Person, Layout or Style -- a style is also a very simple object btw)
		- Bookmark
		- Person -- an event can have persons attached to it as participants
		- Event
		- Reminder
		- Location
		- Region
		- Path -- in a map
		- Annotations -- location, region or path can have an annotation attached to it and appearing on a map… moreover an annotation just packages together some media objects (may be we should consider it as a very simple document?)
		- Style (for compound or text documents)
		- Layout (for compound documents or diagrams)


For a style, you can share it across multiple compound documents.

For a layout, you can share it across persistent roots (e.g. between some tags and a layout library), but you cannot link it in multiple compound documents, because it requires a bidirectional relationships (and maintains some internal state that depends on the context), so it must be copied into the compound document.

With layout vs style sharing variation, we see a distinction between Link vs Share where Link is a restricted form of Share that occurs inside Composite Document, and must involve no bidirectional relationships. 

To achieve linking a composite document inside another one, to prevent creating a bidirectional relationships (disallowed in the model I propose) and very troublesome if branching occurs, the solution is to use a proxy to represent the link. The proxy turns the bidirectional relationship into a unidirectional one. So linking an outline item document into another outline item document doesn't change the parent for the linked outline document, basically the parent remains nil. As a result, the composite doesn't give us issues if we want to create new branches for each outline document.

Link proxies would be special objects such as as ETLayoutItemLink or COOutlineItemLink in the children relationship for COOutlineItem and ETLayoutItemGroup.

For a map, I think in most locations, regions and paths will be inner objects and not persistent roots. However I think paths, regions or locations could sometimes be shared across multiple map objects. In some cases, locations might also be referenced from elsewhere (e.g. attached to a Message or Photo)… For this last case, a better solution is probably to attach photos or messages to a map, and generate map location objects dynamically each time the map is shown (in case the message or photo locations changed).

