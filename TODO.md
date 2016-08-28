TODO
====

Major Missing Features
----------------------

- COUndoTrack doesn't cope with attempts by the user to undo changes in persistent roots that are not present in the store (assetions will fail)

- Persistent root faulting; currently the entire store is loaded in memory

	- A challenge will be supporting cross-persistent root reference inverses.
	i.e. suppose we open a store, load a document persistent root into memory.
	Accessing the derived property "document.tags" requires a search query over
	the current revisions of the current branches of all persistent roots in the whole store
	(at least conceptually). The store keeps an index of cross-persistent references
	anticipating this problem, but it's not currently used. The most straightforawrd
	solution would be to load every persistent root that has ever had a cross-reference
	to document at the same time as when we load "document".

- Partial loading (loading an object using another entity e.g. COPerson as COObject)

  - Add -persistentEntityDescription (for a partially loaded person object, -persistentEntityDescription would return COPerson when -entityDescription returns COObject)


        - (ETEntityDescription *)persistentEntityDescription
        {
            return  [[[self objectGraphContext] modelDescriptionRepository] descriptionForName: @"COObject"];
        }

- Better query support (in-memory and in-store as sketched in COQuery)

  - Introduce our own query objects for expressing a search query, with
    implementations that can run against the store in SQL as well as in memory.
	We will probably need to combine both appraoches to complete a search.

  - NSPredicate to SQL generator using OMeta (not sure)

- Import/Export

- Write a generic object manager than can open any store and display any COObject

  - Should support displaying all key/values (like past StoreBorwser prototypes)
    Not blocking release, but critical for ObjectManager
	
  - The missing feature is: CoreObject can't load a COItem as a COObject unless it has the matching
    entity description available in memory. This can be a barrier for debugging
	(you can't take a saved item graph from an app and load it in a test case, without adding all 
	 of the relevant model classes to the test case)

- Implement something like COSelectiveHistoryTrack (using a query to select revisions based on criterias e.g. inner object subset)

- Something to aggregate the history of multiple persistent roots in this same class?

- Attributed string merge needs work - doing a selective undo of an older change
  tends to corrupt the document. We probably need different merge variants for collaborative
  editing and (merging branches/selective undo)


Open Questions
--------------

- Merging UI

- We only have automatic metamodel-driven copying on subsets of an inner object graph. Investigate copying a persistent root and also referenced persistent roots. For example, being able to copy the Typewriter library persistent root, and have all note persistent roots in the library automatically copied as well, would be genuinely useful. This seems to be essentially the same problem we already solve with COCopier. Note that the persistent root copies would be essentially cheap copies, but we would have to rewrite the cross-references to point to the copies instead of the originals.

- Do cross-store references make sense? i.e. switch from COPath to a URL?

- Adjust COEditingContext loaded object cache to use a strategy that matches which root objects are going to be accessed recurrently (e.g. photos in a Photo Manager should have priority over other root objects)

- Scalability to 50k persistent roots, 50k root objects

- Reintroduce history compaction (will it be needed?), which was present but bitrotted and is not supported right now.
  Possibly just collapse "minor edits" or collapse to daily snapshots + explicit tags. Not sure how much space this will save though.

  Another trick we can try is: when we decided to stop appending deltas and write a new full snapshot,
  take the previous full snapshot and all of the deltas, and zlib compress the binary
  representations of those item graphs as a single block.

- Perhaps support Layers in addition to XMPP

	- https://layer.com
	- http://www.theverge.com/2013/12/4/5173726/you-have-too-many-chat-apps-can-layer-connect-them



Future Work (Minor features, refactoring, cleanup)
--------------------------------------------------

- General

	- Decide whether to enable Clang warning 'Implicit Conversions to 32 Bit Type'

		- This produces some CoreObject warnings currently
	
		- I have set this warning explicitly to 'No' in TestCoreObject (where we probably don't want it) - Quentin

		- At the same time, we could remove -Wno-sign-compare in CoreObject target too (used to inhibit some -Wextra warnings)


- GNUstep

  - Port Samples
  
  - Port benchmark suite

  - Add -URLByAppendingPathComponent:isDirectory: and -fileHandleForReadingFromURL:error: to GNUstep (see COSQLiteStore+Attachments)

  - Add -dateWithContentsOfFile:options:error: to GNUstep (see COOCommitDescriptor)

  - Add -predicateWithBlock: to GNUstep (see COQuery)

  - Perhaps tweak `[[NSDecimalNumber defaultBehavior] scale]` to return NSDecimalScale by default as Mac OS X does

  - Perhaps don't treat `-[NSSet countByEnumeratingWithState:objects:count:]` as a primitive method to match Mac OS X behavior


- Store

  - exportRevisions: and importRevisions: that take a set of CORevisionID an returns a delta-compressed NSData
    suitable for network transport.
	
  - GC: only collect divergent revisions older than X days
  
  - Switch from FMDB to an SQL abstraction backend
  
  - Async attachment import
  
  - Revisit deletion

  - Don't leave empty backing store databases cluttering the store directory
  
    - Doesn't happen while running the test suite anymore, but I don't remove it since backing stores might still need to be deleted on store compaction (for deleted persistent roots).
  
  - Add support for indexing properties other than text ones. Either use a single table with
	property, value columns and a composite key on (property, value), or one table per
	indexed property name.


- COEditingContext

  - Expose COSQLiteStore's attachments feature

  - expose COSQLiteStore's finalize deletion method

  - expose store's searching functionality (integrate COSearchResult and COQuery)

  - Switch to NSUUID everywhere?

  - Expose COEditingContext(Debugging), probably with a header we can explicit import (should be outside of COEditingContext+Private)
  

- COPersistentRoot

  - Refactor handling of store notifications
  
  - Add -initialRevision?

	
- COBranch

  - Extend COBranch API to support branches and merging revisions accross tracks

  - Clean up selective undo code and share implementation with undo system

  - Implement -isCopy and -isTrunkBranch
  
  - Record last modified date on branches
  

- COPersistentObjectContext

	- Find a better name for this protocol, that gives it less importance, and convey it can represent a transient object graph context (or at least doesn't go against this use case). 
	
	- Perhaps move it to EtoileUI


- Metamodel

  - Add checks that derived are not persistent (readonly can be persistent, for set-once properties. Useful for immutable objects).

  - Add check that parent property (isContainer = YES) is derived

  - Add check that one side of an opposite is derived (now sanity-checked in COObject+RelationshipCache, but should be impossible to configure a metamodel with this constraint broken)

  - Review other constraints

  - Add a check that the derived side of a multivalued opposite is unordered
  
  - Add a check that complains about ivars for incoming relationships
  
  - Add constraint stating that a keyed relationships cannot have an opposite (at least for now)

  - Move to CoreObject - extract it to a tiny framework CoreObjectModelDescription.framework with no dependencies except Foundation

  - Improve metamodel checker to ensure matching Objective-C property types (e.g. a ETCollection must be declared as multivalued, a NSArray as ordered)

  - Add a check that complains about serialization accessors or serialization transformers for relationships if there is no custom persistent type declared

  - For keyed relationships, it's not clear what the permissible types of keys are.
	The tests just test NSString.

  - perform validation at freezing time on the set of entities being frozen. This means a group of entities can only become frozen if they are valid. 

  - call +newEntityDescription methods lazily, either at first use of -entityDescriptionForClass: or -descriptionForName: on ETModelDescriptionRepository (for performance)
  
  - Have a look at the section "Discussion of Composite & Aggregate Terminology in UML" in ETModelElementDescription's class description.
    See if we want to tweak the metamodel to be closer to UML or FAME. Consider how this will impact COCopier.


- COObject

  - If you have a property in a superclass that's readonly and implemented as an ObjC method (e.g. -[COObject identifier]),
    and you override the property in a subclass but make it readwrite in the metamodel (like COLibrary does), you won't get
	autogenerated variable storage accessors. We should either fail explicitly, or support this.

  - Better error message if you try to use a composite relationship across persistent roots, 
    currently you get a COPath does not respond to UUIDValue exception.

  - We should have dedicated array/set multivalue mutation methods rather than using:
    `-[COObject (void)insertObject: (id)object atIndex: (NSUInteger)index hint: (id)hint forProperty: (NSString *)key]`
    for both, IMO (Eric)

  - Use NSOrderedSet for relationships
    
  - Throw an exception if the developer names a property that conflicts with a NSObject/COObject method

  - Add dictionary update tests to TestObjectUpdate.m
  
  - Add relationship update check to detect persistent objects inserted into a transient relationship. The object put in the relationship could belong to:
  
    - a transient object graph context --> allowed (see transient property _dropIndicator in -[ETLayout awakeFromDeserialization)
    - the same object graph context --> disallowed (otherwise we can accidentally easily look up shared instance using the wrong object graph context e.g. `_dropIndicator = [ETDropIndicator sharedInstanceForObjectGraphContext: [layout objectGraphContext]])`
    - some other persistent object graph context --> allowed or disallowed (not sure yet)

  - Make primitives with potentially mutable subclasses (NSString and NSData)
    have immutable copies made before being stored in the variable storage.

  - Add more transient relationship tests

  - Check memory management for transient relationships:

    - Transient collection (which is retaining) can contains persistent COObjects?
	- Persistent collection (weak references) can contain transient COObjects

  - Fix problem with properties that have the first letter uppercase
  
  - Synthesize more KVC accessors, such as the multivalued ones
  
  - Synthesize accessors for the primitive types (int, BOOL, etc). Just a 'nice to have' feature.

  - Double check support for properties that are both readOnly and persistent (Basically set-once.)

  - For all of the relationship tests, test cross persistent root, and a mix of cross-persistent root
	and inner objects with in the same relationship.

  -  For all of the relationship tests, we need to come up with some solution to exercise all Relationship tests in    
the following situations at least:

      - references in the same transient object contexts (we just cover this case currently)
	  - references accross transient object contexts
	  - references accross persistent object graph contexts
                                                                
	To get a good test coverage, we probably need to have an abstract TestRelationship test class and concrete test subclasses covering each variation by initializing the test class instance with the proper object graph contexts. For persistent object graph contexts, we want some mechanism to check the relationship states:
	
	  - before commit (we need to catch tracking and non-tracking branch border cases that can arise on persistent root initialization)
	  - after commit in another recreated context
		
	Wrapping all test method code with -checkObjectGraphContextWithExistingAndNew(Editing)Context:inBlock: in abstract classes such as TestUnivaluedRelationship should do the trick.
		
		@interface TestRelationship : TestCommon // Abstract
		{
			/* If we references in the same object graph context, then both ivars are initialized to point the same context */
			COObjectGraphContext *sourceObjectGraphContext;
			COObjectGraphContext *targetObjectGraphContext;
		}
		
		@interface TestUnivaluedRelationship : TestRelationship // Abstract
		
		@interface TestUnivaluedRelationshipAccrossPersistentObjectGraphContexts : TestUnivaluedRelationship  <UKTest>
		
	See -testUnivaluedGroupWithOppositeInPersistentRoot as a starting point.
	
  - Test entity type checking for all relationship types (inserting a child where the type is wrong.)
    Also test this for cross-persistent root relationships.

  - The relationship tests mostly test NSString and COObject references. Test
    more with NSData, NSNumber, COAttachmentID, etc.
	
  - Attempting to set a value for a readonly property should raise an exception

  - Expose and document the COPrimitiveCollection protocol and the
    COMutableArray and related collection subclasses, so advanced use cases that need to
    use ivar storage for collections (or implement custom storage data structures)
    instead of the variable storage can integrate correctly with CoreObject.

  - Avoid hardcoding the model description repository in +automaticallyNotifiesObserversForKey:
  
    - the simplest solution could be to return NO and let subclasses override it to return YES (e.g. for the rare case, where the user wants to have hand-written accessors + automatic KVO notifications for some transient properties) 
	- or to return NO and just forbid overriding it (since returning YES seems almost useless if we synthesize accessors, and we support @dynamic even for transient properties)
	- check `+[COObject automaticallyNotifiesObserversForKey:]` doesn't break KVO notifications for transient and non-derived properties in EtoileUI subclasses
	
  - Add some collection-oriented KVO update tests to TestObjectUpdate

- COObjectGraphContext

  - Test `-[COObjectGraphContext discardAllChanges]` during synchronization. It's important to use 
    -reloadAtRevision: and not -setCurrentRevision: here, otherwise -supportsRevert would go our way

  - Test nil univalued relationship case (see r10270)


- COItem

  - tidy up ugly NSMutableDictionary / NSDictionary casting

  - use a `std::unordered_map<NSString *, std::pair<uint32_t, id>>`
    (i.e. map from string to (COType, object) pair). 
    
    (Well, use a simple wrapper class instead of std::pair.) NOTE: using
	SEL as a map key won't work on libobjc2.

  - Write tests that ensure we correctly copy (see -mutableCopyWithNameMapping:):

    - relationships (mixing UUIDs and COPath)
    - collections of value objects


- Collaboration

  - COSynchronizer should handle syncing persistent root / branch metadata changes?

  - support sending attachments (or large persistent roots) using XMPP file transfer

  - COSynchronizerClient is missing the detection for illegal reverts


- COUndoTrack

  - Doesn’t work: [[COUndoTrack trackForPattern: @"org.etoile.projectdemo*" withEditingContext: nil] clear];

  - Perhaps have different commands for a regular commit and a revert.
    It's probably confusing or dangerous that undoing a revert can cause a selective undo (as it can now),
	whereas for undoing a regular commit it's okay to make a selective undo.

  - Refactor COCommand initialization which is a mess

  - Rename COTrack to COHistoryTrack protocol

  - Reduce commit description related code duplication in CORevision and COCommandGroup

  - Concurrency between processes is not robust (no checking that in-memory
    revisions snapshot is in sync with what is in the DB)

  - e.g:
  
	    a = [COUndoTrack trackForName: @"test" withEditingContext: ctx]
	    b = [COUndoTrack trackForName: @"test" withEditingContext: ctx]
	    ...
	    [ctx commitWithUndoTrack: a]

	[a nodes] will not equal [b nodes] but I would expect them to be the equal

  - Maybe support user-defined actions that track state not managed by CoreObject


- Model objects (COObject subclasses included with CoreObject for convenience)

  - for COLibrary, evaluate whether we can enfore the constraint that one persistent root belongs to one library (we discussed this and we can't)
  
  - Test unordered COCollection subclass
  

- Serialization

  - Make a strict set of supported types, see: Scraps/serialization_todo.txt


- Utilities

  - Define some CoreObject exceptions perhaps
	
    - COAbstractClassInitializationException
    - COImmutableCollectionMutationException
    - what else?
 
  - Write commit descriptor tests (localization is untested at this time)
	
  - Implement copying commit descriptor plist and string files to ~/Library/CoreObject/Commits, in order to support browsing changes done by applications uninstalled from the system
  - Integrate COCommitDescriptor with Schema Upgrade 
	
    - adjust to support versioned descriptors 
    - multiple commit descriptor versions can present per domain in ~/Library/CoreObject/Commits

  - COError API will probably need adjustements once we report more errors through the core API (for now, we just report validation errors at commit time) 


- Documentation

  - Expose the following API if needed once more mature and documented:
    - COCopier, COPrimitiveCollection
    - all COCommand subclasses
    - Diff
    - Extras
    - Store 
    - StorageDataModel
    - Synchronization

  - Once all COCommand class hierarchy appear in the API documentation, their @group should be changed to 'Undo Actions' to ensure COUndoTrack and COTrack don't get lost among all these subclasses.

  - Check and update all Core, Model, Undo and Utilities API documentation (underway)

    - Reviewed classes
      - Core: COObjectGraphContext, COEditingContext, COBranch, CORevision, COQuery, COObject
      - Model: all
      - Undo: all, but needs to be checked again due to Undo-tree rewrite
      - Utilities: COCommitDescriptor, COError

    - talk about how we automatically synchronize COEditingContexts (in the same process or different processes), we should explicitly talk about cross references

    - talk about change notifications in the class descriptions. mention the notifications we support for each class description.


- Code Quality

	- Reviewed classes: none (COObjectGraphContext, COEditingContext, COBranch underwent a preliminary review)


- COAttributedString

    - Automatically split chunks longer than X characters
