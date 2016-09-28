/*
    Copyright (C) 2014 Eric Wasylishen
 
    Date:  February 2014
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>

@class EWTypewriterWindowController;

@interface EWTagGroupTagPair : NSObject

@property (nonatomic, readonly) ETUUID *tagGroup;
@property (nonatomic, readonly) ETUUID *tag;

- (instancetype)initWithTagGroup: (ETUUID *)aTagGroup tag: (ETUUID *)aTag;

@end


@interface EWTagListDataSource : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate>
{
    NSTreeNode *rootTreeNode;
    NSTreeNode *allNotesTreeNode;
    NSMutableSet *oldSelection;
    EWTagGroupTagPair *nextSelection;
    BOOL ignoreSelectionChanges;
}

@property (nonatomic, unsafe_unretained) EWTypewriterWindowController *owner;
@property (nonatomic, strong) NSOutlineView *outlineView;

- (void)reloadData;
- (void)cacheSelection;
- (void)setNextSelection: (EWTagGroupTagPair *)aUUID;
- (void)selectTagGroupAndTag: (EWTagGroupTagPair *)aPair;

@end
