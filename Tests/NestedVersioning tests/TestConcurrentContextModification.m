/*

 we need to test having two contexts open on the same version.
 
 ctx1A has uncommitted changes.
 ctx1B has uncommitted changes.
 
 ctx1A commit. ctx1B commit. ctx1B needs to merge its changes with the 
 ones 1A committed.
 
 (no communication between the contexts is needed; it can do this simply
 by noticing that the version it is expecting to attach a child to
 is no longer a leaf).
 
 */