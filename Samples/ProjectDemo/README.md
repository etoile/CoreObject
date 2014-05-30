ProjectDemo
===========

This is an attempt to write a demonstration of a project UI with all of the
neat things we want:

 - revision control / checkpointing / branching / merging / selective undo
 - collaborative editing


Command line arguments example:

    -storeURL ~/anotherStore.coreobject
    -XMPPJID foo@bar.com
    -XMPPPassword password

The library is saved in ~/Library/CoreObject/ProjectDemo.coreobjectstore by default

What's working:

 - the "New…" menu item, and "New Outline" button
 - Insert, Insert Child, Step Backward, Step Forward toolbar items in an outline window
 - editing the label of an outline item
 - drag and drop of outline items, including between documents
 - Document -> Move to trash (no way to view the trash, but the persistent root is deleted, and the document won't re-open on the next app launch)
 - The undo mode in Preferences
 - "Undo", "Redo", "Step Backward", "Step Forward" in the "Edit" menu

Probably nothing else works, but it's enough to be a useful demo
 
