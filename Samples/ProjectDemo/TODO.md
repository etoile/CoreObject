TODO
====

Critical
--------

###Outliner

 - fix drag-and-drop

###Text editor

 - finish attributed string support (in progress)

###Graphics editor

###General

 - fix project level undo
 - there is a lot more broken... test the app and take notes on use cases that should work


Nice-to-have
------------

###Outliner

 - Add partial NSOutlineView updates
 - Memorize open/closed outline items
 
###Text editor

###Graphics editor

 - Support embedding drawings inside other drawings (using cross-persistent root references)

###General

 - Re-enable tagging UI
 - Improve history graph window
    - GitX-like table view?
    - Implement hiding of minor edits, so the graph only shows checkpoint revisions and branches (with a button to expand the collapsed edits)
    - add selective undo buttons to history graph window
    - show username in history graph when sharing
 - Investiage "changes in both contexts" exceptions that happen during undo/redo (not sure if they still happen)
 - diff/merge visualizations (even very basic, like displaying the output of the -description method in a text view)
 - make branch switch undoable
 - attachments over XMPP
 - rename the branch UI to sharing Sessions 
 - ProjectDemo should support restarting sharing on a document that’s been shared
 - Add pause / resume methods for sharing

