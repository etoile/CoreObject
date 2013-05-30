/*
	Copyright (C) 2012 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  Ocstober 2012
	License:  Modified BSD  (see COPYING)
 */

#import <CoreObject/COBookmark.h>
#import <CoreObject/COCollection.h>
#import <CoreObject/COCommitDescriptor.h>
#import <CoreObject/COCommitTrack.h>
#import <CoreObject/COContainer.h>
#import <CoreObject/COCustomTrack.h>
#import <CoreObject/COEditingContext.h>
#import <CoreObject/COError.h>
#import <CoreObject/COFault.h>
#import <CoreObject/COGroup.h>
#import <CoreObject/COHistoryTrack.h>
#import <CoreObject/COLibrary.h>
#import <CoreObject/COObject.h>
#import <CoreObject/COPersistentRoot.h>
#import <CoreObject/COQuery.h>
#import <CoreObject/CORevision.h>
#import <CoreObject/COStore.h>
#import <CoreObject/COSQLStore.h>
#import <CoreObject/COSynchronizer.h>
#import <CoreObject/COTag.h>
#import <CoreObject/COTrack.h>

/* Diff Framework (the Diff API is very unstable) */

#import <CoreObject/COArrayDiff.h>
#import <CoreObject/COMergeResult.h>
#import <CoreObject/COObjectGraphDiff.h>
#import <CoreObject/COSequenceDiff.h>
#import <CoreObject/COSetDiff.h>
#import <CoreObject/COStringDiff.h>
