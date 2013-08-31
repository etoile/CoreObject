/*
	Copyright (C) 2012 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  Ocstober 2012
	License:  Modified BSD  (see COPYING)
 */

/* Core */

#import <CoreObject/COCopier.h>
#import <CoreObject/COEditingContext.h>
#import <CoreObject/COObject.h>
#import <CoreObject/COObjectGraphContext.h>
#import <CoreObject/COPersistentRoot.h>
#import <CoreObject/COBranch.h>
#import <CoreObject/COQuery.h>
#import <CoreObject/CORevision.h>
#import <CoreObject/COSerialization.h>
#import <CoreObject/COSQLiteStore.h>
#import <CoreObject/NSObject+CoreObject.h>

/* Model */

#import <CoreObject/COBookmark.h>
#import <CoreObject/COCollection.h>
#import <CoreObject/COContainer.h>
#import <CoreObject/CODictionary.h>
#import <CoreObject/COGroup.h>
#import <CoreObject/COLibrary.h>
#import <CoreObject/COTag.h>

/* Diff Framework (the Diff API is very unstable) */

#import <CoreObject/COArrayDiff.h>
#import <CoreObject/COItemGraphDiff.h>
#import <CoreObject/COSubtreeEdits.h>

/* Storage Data Model */

#import <CoreObject/COItem.h>
#import <CoreObject/COItemGraph.h>
#import <CoreObject/COType.h>
#import <CoreObject/COPath.h>

/* Store */

#import <CoreObject/CORevisionID.h>
#import <CoreObject/CORevisionInfo.h>
#import <CoreObject/COBranchInfo.h>
#import <CoreObject/COPersistentRootInfo.h>
#import <CoreObject/COSearchResult.h>
#import <CoreObject/COSQLiteStore.h>
#import <CoreObject/COSQLiteStore+Attachments.h>

/* Undo */

#import <CoreObject/COEditingContext+Undo.h>

/* Utilities */

#import <CoreObject/COCommitDescriptor.h>
#import <CoreObject/COError.h>
