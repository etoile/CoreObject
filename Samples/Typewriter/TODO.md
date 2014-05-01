Typewriter TODO
===============

- [ ] Trying to undo past a checkpoint switches to performing selective undos, because the creation of the checkpoint revision isn't in the undo log. This may be the correct behaviour, but it was surprising to me now when I noticed it.
- [ ] Maybe commit text changes when the user manually moves the insertion point, to try to avoid "... and other edits" commits
- [x] Don't create Default Tag Group
- [ ] Delete' is enabled in the menus for All Notes
- [ ] if not tag group exists, new tags you create remain invisible (and the button and menu actions are not disabled)… I guess the solution is to create a New Tag Group at the same time, if there is none.
- [x] name a new tag group just Untitled Tag Group X
- [x] a new tag could be named Untitled X
- [ ] a way to give a name to a checkpoint
- [ ] some way to see the list of all the checkpoints
- [ ] have Revert show a panel listing all the checkpoints, so you can pick the one you want
- [x] Don't use NSDocument
- [x] NSOutlineView Warning: reloadData called while in the middle of doing a reloadData (break on NSLog to debug). Quentin: I manage to reproduce by typing a tag name while pressing '+'	but I had to try twice
- [ ] Investigate "undo" performing a selective undo when it is unnecessary (it doesn't happen in a fresh
      document, but happens on an older document ("Intro Video"))