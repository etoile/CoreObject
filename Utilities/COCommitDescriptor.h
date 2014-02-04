/*
	Copyright (C) 2013 Quentin Mathe

	Date:  May 2013
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

/** 
 * @group Utilities
 * @abstract A commit descriptor represents transient and persistent revision 
 * metadata.
 *
 * Commit descriptors must be used to support history localization, and avoid 
 * writing any localized metadata to the store at commit time.
 *
 * Each commit descriptor describes a persistent change or operation. A 
 * persistent change is usually bound to a user action. 
 *
 * Commit descriptors must be registered at the application launch, before 
 * giving the control to the user. For example, on 
 * -[NSApplicationDelegate applicationDidFinishLaunching:] (explain how they 
 * can be automatically registered by declaring in a .json file).
 *
 * For committing localizable metadatas, pass -[COCommitDescriptor identifier]
 * to COEditingContext commit methods:
 *
 * <example>
 * NSString *objType = @"Folder";
 * NSDictionary *metadata = D(A(objType), kCOCommitMetadataShortDescriptionArguments);
 * NSError *error = nil;
 *
 * // kOMCommitCreate is a constant that represents 'org.etoile-project.ObjectManager.create'
 * [editingContext commitWithIdentifier: kOMCommitCreate
 *                             metadata: metadata
 *                            undoTrack: undoTrack
 *                                error: &amp;error];
 * </example>
 *
 * For the previous example, the commit short description is going to be 
 * "Create New Folder" based on a localizable template "Create New %@" provided 
 * in a .strings file.
 *
 * Localized descriptions that appear in the UI are transient metadata and are 
 * not included in the committed metadata. The CoreObject store doesn't contain 
 * them, but -[COCommitDescriptor shortDescription] can recreate them at 
 * run-time by combining -[CORevision metadata] and localized strings (explain a 
 * bit more... e.g.format for .string files and how they are located).
 *
 * You can use  -[ETPropertyDescription setPersistencyDescriptor:] (not yet 
 * implemented) to attach a commit descriptor to the metamodel, then retrieve it 
 * at a commit time.
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
 * Returns the commit descriptor previously registered for a descriptor 
 * identifier.
 *
 * The registration is not persistent and is lost on application termination.
 *
 * For a nil argument, raises a NSInvalidArgumentException.
 */
+ (COCommitDescriptor *)registeredDescriptorForIdentifier: (NSString *)anIdentifier;


/** @taskunit Persistent Metadata */


/**
 * A unique identifier among all the commit descriptors.
 *
 * The identifier format is <em>&lt;domain-in-reverse-DNS-notation&gt;.&lt;name&gt;</em>. 
 * For org.etoile-project.ObjectManager.rename:
 *
 * <deflist>
 * <term>org.etoile-project.ObjectManager</term><desc>the descriptor domain</desc>
 * <term>rename</term><desc>the descriptor name</desc>
 * </deflist>
 *
 * The identifier is often used as a subtype: multiple commit descriptors can 
 * share the same type description, but use distinct identifiers.
 *
 * You can use it to look up the current commit description from the revision 
 * metadata:
 *
 * <example>
 * NSString *identifier = [[aRevision metadata] objectForKey: kCOCommitMetadataIdentifier];
 * COCommitDescriptor *descriptor = 
 *     [COCommitDescriptor registeredDescriptorForIdentifier: identitifier];
 * </example>
 *
 * See also -domain and -name.
 */
@property (nonatomic, readonly) NSString *identifier;
/**
 * A domain representing an editing activity (e.g. an application), and usually 
 * shared among several commit descriptors.
 *
 * The domain must be in reverse DNS notation e.g. 
 * <em>org.etoile-project.ObjectManager</em>.
 *
 * See also -identifier and -name.
 */
@property (nonatomic, readonly) NSString *domain;
/**
 * A name representing an editing action (e.g. a user action causing a commit).
 *
 * The descriptor name can be shared among several commit descriptors. For a 
 * rename operation, we could have:
 *
 * <list>
 * <item>org.etoile-project.ObjectManager.rename</item>
 * <item>org.etoile-project.AddressBook.rename</item>
 * </list>
 *
 * For multiple rename actions targeting multiple objects kinds in a domain, you 
 * might want to use highly customized localizations in some cases (rather than 
 * just customizing few words in the sentence based on -shortDescriptionArguments).
 * You can do it by using suffixes to precise the renaming:
 *
 * <list>
 * <item>org.etoile-project.AddressBook.renamePerson</item>
 * <item>org.etoile-project.AddressBook.renameGroup</item>
 * </list>
 *
 * See also -identifier and -domain.
 */
@property (nonatomic, readonly) NSString *name;


/** @taskunit Transient Metadata */


/**
 * The type of the action that triggered the commit.
 *
 * The descriptor type can be shared among several commit descriptors. For a 
 * rename operation, we could use <em>renaming</em> as the type set on:
 *
 * <list>
 * <item>org.etoile-project.AddressBook.renamePerson</item>
 * <item>org.etoile-project.AddressBook.renameGroup</item>
 * </list>
 *
 * This property must be provided (in the plist file).
 *
 * For a nil description, the setter raises a NSInvalidArgumentException.
 *
 * See also -typeDescription and -localizedTypeDescription.
 */
@property (nonatomic, readonly) NSString *type;
/**
 * Few words that summarizes the action that triggered the commit.
 *
 * This property must be provided (in the plist file).
 *
 * For a nil description, the setter raises a NSInvalidArgumentException.
 *
 * See also -type and -localizedTypeDescription.
 */
@property (nonatomic, readonly) NSString *typeDescription;
/**
 * A localized description for -typeDescription.
 *
 * This is usually presented in a history browser UI.
 *
 * See also -type and -typeDescription.
 */
@property (nonatomic, readonly) NSString *localizedTypeDescription;
/**
 * A description that fits on a single line.
 *
 * This property must be provided (in the plist file).
 *
 * For a nil description, the setter raises a NSInvalidArgumentException.
 *
 * See also -localizedShortDescriptionWithArguments:.
 */
@property (nonatomic, readonly) NSString *shortDescription;
/**
 * A localized description for -shortDescription, by optionally interpolating 
 * localized arguments (depending on the commit or the context) into the 
 * localized short description.
 *
 * This is usually presented in a history browser UI.
 *
 * See also -shortDescription.
 */
- (NSString *)localizedShortDescriptionWithArguments: (NSArray *)args;

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
 * string of -[COCommitDescriptor shortDescription] and 
 * -[COCommitDescriptor localizedShortDescription].
 */
extern NSString *kCOCommitMetadataShortDescriptionArguments;
