CoreObject
==========

Maintainers
: Eric Wasylishen, Quentin Mathe
Authors
: Eric Wasylishen <ewasylishen@gmail.com>, Quentin Mathe <quentin.mathe@gmail.com>, Christopher Armstrong <carmstrong@fastmail.com.au>
License
: MIT License
Version
: 0.5


CoreObject is a version-controlled object database, designed to be a humane
persistence layer for applications with a "never lose any work" philosophy.

At the center is an ACID-compliant object store using SQLite, and built on this are
semantic merging, rich undo/redo support, collaborative editing, and a
transaction API for viewing database snapshots in memory and batching changes for commit.

Read more at [coreobject.org](http://coreobject.org)

[![Build Status](https://travis-ci.org/etoile/CoreObject.png?branch=master)](https://travis-ci.org/etoile/CoreObject)


Key Features
------------

- Revision Control  

    - Built on a DVCS (distributed version control system) model
    - Persistent roots have isolated history
        - Comparable to separate Git repositories
    - Based on Object Graph Diff and Merging Model
        - Each Change is a delta represented as an Object Graph Patch
    - Two-level History
        - History Graph per document
        - Undo Track per activity
    - Branch
    - Cheap Copy (copying a document requires O(1) space)
    - Localizable History
    - History Compression and Compaction // Not finished!
    - Serialization Formats
        - JSON and Binary (endian-, 32/64-bit- independent)
        - Stable over multiple invocations for the same object graph (no merge issues in SCM)
        - Integrity Checking (every single committed change includes a checksum)


- Undo Framework

    - Built on the Revision Control model
        - Never need to define new Command objects
    - Pervasive Undo/Redo
        - Document Changes (Creation, Update and Deletion inside a Document)
        - Store Changes (Document/Branch Creation, Update and Deletion)
    - Selective Undo (each change can be cancelled individually)
    - Persistent Undo Stacks (tree structured/branching undo)
        - Mutiple Undo Views on the same document
        - Undo Stack Union View


- Object Store

    - Pragmatic OODB atop SQLite
    - Minimalistic Metamodel
    - Flexible Storage Model 
        - Coarse-grained Objects with Metadata (e.g. Documents and their Branches)
        - Fine-grained Objects (e.g. inside Document Branches)
        - Optional Object Organization Model based on Tags and Libraries
        - Built-in Indexing and Search (history included)
    - Flexible Collection and Relationship Model
        - Unidirectional or bidirectional
            - Ordered or unordered
            - To-one or to-many
            - Composite
        - Undirectional Unordered Keyed
        - Transparent Constraint Enforcements on Update
    - Cross Document References
        - named branch
        - current branch
        - unidirectional accross arbitrary branch
        - bidirectional between the current branches
    - Synthesized Accessors
    - Transparent Object Graph Copy
    - Transient Object Graph

- Real-Time Collaboration

    - Any CoreObject-based model supports it (for free)
    - Based on the Revision Control Model
    - Very Fast
    - Full Branch and Undo Support per User
        - Per User Persistent Undo Stack
        - Per User Selective Undo
    - Based on XMPP

- Overall Design

    - Small Code Base (~ 20 000 loc)
    - Pretty Large Test suite (over 3000 tests)
    - High Quality API documentation
    - Good Debugging Support 
         - View object graph in memory as PDF diagram (can be generated from the debugger or in code)
         - Short and Detailed Descriptions for logging objects
    - Minimal dependencies (SQLite and EtoileFoundation)
    - Pervasive UUID use (no string, number or content-based identifiers)
    - Favor JSON formats
    - Create a Persistent Object and save it in 3 loc

            COEditingContext *ctx = [COEditingContext contextWithURL: [NSURL fileURLWithPath: @"TestStore.db"]];
            COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"COObject"];
            [persistentRoot commit];

Note: Viewing object graphs as PDF diagrams is not supported on iOS.


Build and Install
-----------------

Clone CoreObject and its dependencies into the same directory (or extract a release .tgz which contains all 3 projects):

    git clone https://github.com/etoile/CoreObject.git
    git clone https://github.com/etoile/EtoileFoundation.git
    git clone https://github.com/etoile/UnitKit.git
    
The Xcode projects and schemes of interest are:

- CoreObject/CoreObject.xcodeproj
  - CoreObject - builds the framework itself
  - BasicPersistence - a minimal example app
  - TestCoreObject - the test suite
  - BenchmarkCoreObject - the benchmark
- CoreObject/Samples/ProjectDemo/ProjectDemo.xcodeproj
   - ProjectDemo - an experimental testbed application with a drawing editor, outliner, and collaborative editing support used in the [demo videos](hthttps://github.com/etoile/CoreObject/blob/master/INSTALL.Cocoa.mdtp://coreobject.org)
- CoreObject/Samples/Typewriter/Typerwriter.xcodeproj
   - Typewriter - a reasonably polished note manager that uses CoreObject

Note: ProjectDemo and Typewriter cannot be run on iOS.

For more details, see [INSTALL.Cocoa](https://github.com/etoile/CoreObject/blob/master/INSTALL.Cocoa.md) or [INSTALL.GNUstep](https://github.com/etoile/CoreObject/blob/master/INSTALL.GNUstep.md).


macOS and iOS support
---------------------

CoreObject is supported on macOS (10.8 or higher), and iOS (7 or higher).

**Warning:** Xcode 4.6 or higher is required to build the Xcode projects.
