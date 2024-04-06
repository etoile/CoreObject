/*
    Copyright (C) 2012 Quentin Mathe

    Date:  October 2012
    License:  MIT  (see COPYING)
 */

/* Core */

#import <CoreObject/COCopier.h>
#import <CoreObject/COEditingContext.h>
#import <CoreObject/COObject.h>
#import <CoreObject/COObjectGraphContext.h>
#import <CoreObject/COPersistentRoot.h>
#import <CoreObject/COBranch.h>
#import <CoreObject/CORevision.h>
#import <CoreObject/COSerialization.h>
#import <CoreObject/COSQLiteStore.h>

/* Model */

#import <CoreObject/COBookmark.h>
#import <CoreObject/COCollection.h>
#import <CoreObject/COContainer.h>
#import <CoreObject/CODictionary.h>
#import <CoreObject/COGroup.h>
#import <CoreObject/COLibrary.h>
#import <CoreObject/COTag.h>
#import <CoreObject/COSmartGroup.h>

/* Diff Framework (the Diff API is very unstable) */

#import <CoreObject/CODiffManager.h>
#import <CoreObject/COArrayDiff.h>
#import <CoreObject/COMergeInfo.h>
#import <CoreObject/COItemGraphDiff.h>
#import <CoreObject/COItemGraphEdit.h>
#import <CoreObject/COSetAttribute.h>
#import <CoreObject/CODeleteAttribute.h>
#import <CoreObject/COSetInsertion.h>
#import <CoreObject/COSetDeletion.h>
#import <CoreObject/COSequenceEdit.h>
#import <CoreObject/COSequenceDeletion.h>
#import <CoreObject/COSequenceInsertion.h>
#import <CoreObject/COSequenceModification.h>
#import <CoreObject/COLeastCommonAncestor.h>

/* Storage Data Model */

#import <CoreObject/COItem.h>
#import <CoreObject/COItemGraph.h>
#import <CoreObject/COType.h>
#import <CoreObject/COPath.h>
#import <CoreObject/COAttachmentID.h>

/* Store */

#import <CoreObject/CORevisionInfo.h>
#import <CoreObject/COBranchInfo.h>
#import <CoreObject/COHistoryCompaction.h>
#import <CoreObject/COPersistentRootInfo.h>
#import <CoreObject/COSearchResult.h>
#import <CoreObject/COSQLiteStore.h>
#import <CoreObject/COSQLiteStore+Attachments.h>

/* Undo */

#import <CoreObject/COUndoTrackStore.h>
#import <CoreObject/COUndoTrack.h>
#import <CoreObject/COUndoTrackHistoryCompaction.h>
#import <CoreObject/COEndOfUndoTrackPlaceholderNode.h>
#import <CoreObject/COEditingContext+Undo.h>

/* Synchronization */

#import <CoreObject/COSynchronizationClient.h>
#import <CoreObject/COSynchronizationServer.h>
#import <CoreObject/COSynchronizerClient.h>
#import <CoreObject/COSynchronizerServer.h>
#import <CoreObject/COSynchronizerJSONClient.h>
#import <CoreObject/COSynchronizerJSONServer.h>

/* Utilities */

#import <CoreObject/COCommitDescriptor.h>
#import <CoreObject/COError.h>
#import <CoreObject/COTrack.h>
#import <CoreObject/COPersistentObjectContext.h>

/* Debugging */

#import <CoreObject/COEditingContext+Debugging.h>
#import <CoreObject/COObjectGraphContext+Debugging.h>
