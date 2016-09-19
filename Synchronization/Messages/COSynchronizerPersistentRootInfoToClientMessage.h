/**
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

@property (nonatomic, readwrite, strong) ETUUID *persistentRootUUID;
@property (readwrite, nonatomic, copy) NSDictionary *persistentRootMetadata;
@property (nonatomic, readwrite, strong) ETUUID *branchUUID;
@property (nonatomic, readwrite, strong) NSDictionary *branchMetadata;
@property (nonatomic, readwrite, strong) COSynchronizerRevision *currentRevision;

@end
