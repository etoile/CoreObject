#import "TestCommon.h"

#if 0
void testCompositeDocument()
{

//	Understanding Composite Documents - Mar 22, 2011
//	
//	Project Editor
//	Document Editor                 Shape 1 editor
//	
//	Shape 2 editor
//	
//	1. Undo and redo are expected to work on the current context or 
//	   focus area the user is working in
//	e.g.:
//	⁃	multiple browser tabs showing Google Docs documents => each tab has an independent undo stack
//	⁃	multiple open documents in Apple’s Pages application => each document has an independent undo stack
//	- in TextMate and Xcode, each file has its own undo stack. In both apps, operations on the 
//	   project pane (grouping, moving, deleting files, etc) are not undoable. Operations which 
//	   affect multiple files in Xcode (e.g. refactor method) can only be undone by visiting each 
//	   individual file and undoing the textual change made there.
//	- Bento (GUI database app) uses one undo stack for the entire application window (one window 
//		   = one database.) The database contains libraries, (photos, todo, contacts, finances, etc),
//		   which contain DB rows and collections of DB rows.
//		- Aperture (photo manager) uses one undo stack for the entire application / library.
//			- Lightroom (photo manager) uses one stack for the entire application, even UI events like
//				switching tabs in the main interface or switching the selected photo (but not navigating
//				within a photo). However, it features a history list of all edits made to each photo, 
//				independent of the main undo system. You can navigate within this list by clicking on
//				an entry to revert to that version. This is an undoable action, but isn’t entered into
//				the history list. Lightroom shows that it’s really nice for Cmd+Z to undo operations 
//					like “revert to version”, “create snapshot”
//				
//	2. People make mistakes with revision control (see the hundreds of questions on stackoverflow.com
//		on how to fix messed up repository states in git by hand). Undo should work on things people
//		with revision control.
//				
//	Metaphor of current systems:
//				
//	-Two types of object: file and folder.
//	-Copy creates a totally independent copy of the file or folder hierarchy – very consistent. 
//					File contents are copied in the same way as directory contents.
//				
//				
//	Puzzles / Example Scenarios
//				
//	Bob is working on designing a magazine cover. He starts out with 4 or 5 very different approaches,
//	sketching out the cover layout with placeholder rectangles. It should be as easy to
//	switch between them as mouse-ing over an icon.
//				
//	One of the layouts, B, looks most promising so he starts to sketch out the main graphic which will go
//	on the cover . Now, he might continue creating new variations of the cover in which 
//	he just edits the embedded graphic.
//	
//	
//	Or, he might continue editing B and create variations of the embedded graphic.
//	
//	These variations (A, B, C, D) are basically branches. Each edit he does is committed to
//		the variation. He can create snapshots along the history of the variation, like in Lightroom. 
//	
//	How does undo-ing selection changes work?
//	
//	Poster Scenario
//	
//	Bob is working on designing a large poster, 1m x 1m. He opens two viewports on it.
//	
//	
//	
//	
//	Boundaries for copy
//		
//		Copy
//		⁃	move text, photo, or sketch from one text document to another
//		⁃	move an element from embedded graphic in a document out in to the document
//		⁃	move an elements in a composite doc from one branch/variation of the document to another
//		Reference
//		⁃	QuArK project - move a map into a group  or move to a different group
//		⁃	Photo library - put photo into an album
//		⁃	Music library - put song into playlist
//		Strategy: every object has a ‘closest ancestor document’. Documents can be nested. If you move an 
//		object to a destination which has a different ‘closest ancestor document’, make it a copy (even 
//		if the dest closest ancestor document has a chain of parents leading to the source’s closest ancestor
//		 document.)
//		
//		
					
	
}
#endif