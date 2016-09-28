CoreObject NEWS
===============

0.6
---

- Lazy loading of persistent roots and branches
- Hidden dead cross references
    - Relationships accross persistent roots are transparently resolved when deleting/undeleting persistent roots or branches
    - Support any relationships including bidirectional ones
- Schema upgrade
    - Support to evolve dependent schemas located in different packages/frameworks
- History compaction
    - Explicit (where finalized persistent roots, branches, and dead revisions are discarded)
    - Automatic (where dead persistent roots, branches and revisions are computed based on an undo track and its max size)
- Massive performance improvements
    - Serialization and loading
    - History navigation
    - Multivalued property mutation (new fast path)
    - Cross persistent root relationships
    - Synthesized accessors
- Selective undo/redo metadata (to track what has been undone/redone)
    - Allow to build custom presentation of the history
- Improved history localization
- Introduced iOS 7 and higher support


0.5
---

- First release.
