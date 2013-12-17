/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@class COSynchronizerRevision;

/**
 * Contains everything a client needs to get set up
 *
 * Client should send a COSynchronizerAcknowledgementFromClientMessage
 * in response.
 */
@interface COSynchronizerPersistentRootInfoToClientMessage : NSObject

@property (readwrite, nonatomic, strong) ETUUID *persistentRootUUID;
@property (readwrite, nonatomic, copy) NSDictionary *persistentRootMetadata;
@property (readwrite, nonatomic, strong) ETUUID *branchUUID;
@property (readwrite, nonatomic, strong) NSDictionary *branchMetadata;
@property (readwrite, nonatomic, strong) COSynchronizerRevision *currentRevision;

@end
