/*
	Copyright (C) 2013 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  May 2013
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

/** 
 * @group Utilites
 * @abstract A commit descriptor represent transient and persistent revision 
 * metadata.
 *
 * Each commit descriptor describes a persistent change or operation. A 
 * persistent change is usually bound to a user action. 
 *
 * Commit descriptors must be registered at the application launch, before 
 * giving the control to the user. For example, on 
 * -[NSApplicationDelegate applicationDidFinishLaunching:].
 *
 * With -persistentMetadata, you can obtain the commit metadata and pass them 
 * to -[COEditingContext commitWithMetadata:]. You can use 
 * -[ETPropertyDescription setPersistencyDescriptor:] to attach a commit 
 * descriptor to the metamodel, then at a commit time, retrieving the commit 
 * descriptor gives the possibility to commit the right metadatas easily.
 *
 * Localized descriptions that appear in the UI are transient metadata and are 
 * not included in -persistentMetadata. The CoreObject store doesn't contain 
 * them, but they can be looked up at runtime based on the persistent metadata 
 * exposed by -[CORevision metadata].
 */
@interface COCommitDescriptor : NSObject
{
	@private
	NSString *_identifier;
	NSString *_type;
	NSString *_shortDescription;
}

/** @taskunit Commit Descriptor Registry */

/**
 * Registers a commit descriptor for the given combination of domain and 
 * descriptor identifier.
 *
 * For a nil argument, raises a NSInvalidArgumentException.
 *
 * See also -identifier and +registeredDescriptorForIdentifier:inDomain:.
 */
+ (void) registerDescriptor: (COCommitDescriptor *)aDescriptor;
/**
 * Returns the commit descriptor previously registered for the given combination 
 * of domain and descriptor identifier.
 *
 * The registration is not persistent and is lost on application termination.
 *
 * For a nil argument, raises a NSInvalidArgumentException.
 *
 * See also +registerDescriptor:inDomain:.
 */
+ (COCommitDescriptor *) registeredDescriptorForIdentifier: (NSString *)anIdentifier;

/** @taskunit Transient and Persistent Metadata */

/**
 * A unique identifier among all the commit descriptors.
 *
 * The identifier is often used as a subtype: multiple commit descriptors can 
 * shared the same type description, but use distinct identifiers.
 *
 * You can use it to look up the current commit description from the revision 
 * metadata:
 *
 * <example>
 * NSString *identifier = [[aRevision metadata] objectForKey: kCOCommitMetadataIdentifier];
 * COCommitDescriptor *descriptor = 
 *     [COCommitDescriptor registeredDescriptorForIdentifier: identitifier
 *                                                  inDomain: kETUIBuilderDomain];
 * </example>
 */
@property (nonatomic, strong) NSString *identifier;
@property (nonatomic, readonly) NSString *domain;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, strong) NSString *type;
/**
 * Few words that summarizes the action that triggered the commit.
 *
 * This property must be set.
 *
 * For a nil description, the setter raises a NSInvalidArgumentException.
 */
@property (nonatomic, readonly) NSString *typeDescription;
/**
 * A localized description for -typeDescription.
 *
 * This is usually presented in a history browser UI.
 */
@property (nonatomic, readonly) NSString *localizedTypeDescription;
/**
 * A description that fits on a single line.
 *
 * This property must be set.
 *
 * For a nil description, the setter raises a NSInvalidArgumentException.
 */
@property (nonatomic, strong) NSString *shortDescription;
/**
 * A localized description for -shortDescription.
 *
 * This is usually presented in a history browser UI.
 */
- (NSString *)localizedShortDescriptionWithArguments: (NSArray *)args;

/** @taskunit Commit Integration */

/**
 * A persistent metadata representation.
 *
 * The returned dictionary can be passed to -[COEditingContext commitWithMetadata:].
 *
 * If -shortDescription or -typeDescription returns nil, a 
 * NSInternalInconsistencyException is raised.
 */
@property (nonatomic, readonly) NSDictionary *persistentMetadata;

@end

/** 
 * The key used to identify -[COCommitDescriptor identifier] among the commit 
 * metadata.
 */
extern NSString *kCOCommitMetadataIdentifier;
/**
 * The key used to identify -[COCommitDescriptor typeDescription] among the 
 * commit metadata.
 */
extern NSString *kCOCommitMetadataTypeDescription;
/**
 * The key used to identify -[COCommitDescriptor shortDescription] among the
 * commit metadata.
 */
extern NSString *kCOCommitMetadataShortDescription;
/**
 * The optional key used to identify -[COCommitDescriptor shortDescriptionArguments] 
 * among the commit metadata.
 *
 * The value must be a string array that can used to interpolate the format 
 * string of -shortDescription and -localizedShortDescription.
 */
extern NSString *kCOCommitMetadataShortDescriptionArguments;

