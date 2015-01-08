/**
	Copyright (C) 2014 Quentin Mathe

	Date:  January 2014
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

/**
 * @group Schema Migration
 * @abstract Represents an entity or property move accross two packages or 
 * domains that can be attached to a schema migration.
 *
 * See -[COSchemaMigration entityMoves] and -[COSchemaMigration propertyMoves].
 */
@interface COModelElementMove : NSObject
{
	@private
	NSString *_name;
	NSString *_ownerName;
	NSString *_domain;
	int64_t _version;
}


/** @taskunit Name */


/**
 * The name of the entity or property to move.
 */
@property (nonatomic, copy) NSString *name;
/**
 * The name of the entity that owns the property to move.
 *
 * For moving an entity, must be nil.
 *
 * For moving a property, must be set.
 */
@property (nonatomic, copy) NSString *ownerName;


/** @taskunit Targeted Domain and Version */


/**
 * The domain where we want to move the entity or property.
 *
 * The domain must correspond to a package name in the metamodel.
 *
 * See -[ETPackageDescription name] and -[COCommitDescriptor domain].
 */
@property (nonatomic, copy) NSString *domain;
/**
 * The domain version that requires the moved entity or property.
 *
 * For the migration registered under this domain/version pair, the entity or 
 * property move must have been done.
 */
@property (nonatomic, assign) int64_t version;

@end
