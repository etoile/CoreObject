ObjectMerging / CoreObject rewrite
====================================

Author: Eric Wasylishen
License: MIT X11

This is my work-in-progress rewrite of CoreObject.

Primary goals:
---------------
- Temporal persistence, with branch, merge, undo tracks, and selective undo
- Drops in to GNUstep/Cocoa apps
- Live Collaboration
- Act as a name service (provide grouping and tagging features)
- Metadata Indexing, Full-text search
- Distributed storage
- Export/Import


Inspired by these papers:
--------------------------
- "Difference and Union of Models" by M. Alanen and I. Porres.
- "A flexible object merging framework" by J. P. Munson and P. Dewan.
 This paper has a lot of nice examples of collaboration scenarios with merging

