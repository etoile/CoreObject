/*
	Copyright (C) 2010 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COCollection.h>

@class COSmartGroup;

/**
 * @group Object Organization
 *
 * COGroup is a mutable, unordered, weak (an object can be in any number of 
 * collections) collection class.
 */
@interface COGroup : COCollection
{

}

/** @taskunit Metamodel */

/**
 * Returns a multivalued, non-ordered and persistent property.
 *
 * You can use this method to easily describe your collection content in a way 
 * that matches the superclass contraints. 
 *
 * See -[COCollection contentPropertyDescriptionWithName:type:opposite:] which 
 * documents the method precisely.
 */
+ (ETPropertyDescription *)contentPropertyDescriptionWithName: (NSString *)aName
                                                         type: (NSString *)aType
                                                     opposite: (NSString *)oppositeType;

/**
 * Returns YES.
 */
- (BOOL)isGroup;

@end


/**
 * @group Object Collection and Organization
 *
 * COTag represents a tag attached to every object that belongs to it.
 */
@interface COTag : COGroup
{

}

/**
 * Returns YES.
 *
 * A tag is group that belongs to -[COEditingContext tagGroup].
 */
- (BOOL)isTag;

/** @taskunit Tagging */

/**
 * Returns the tag the receiver represents.
 *
 * COTag can represent a tag attached to every object that belongs to it.
 *
 * By default, returns the name in lower case.
 */
- (NSString *)tagString;

@end



/**
 * @group Object Collection and Organization
 *
 * COTagGroup is used to organize tags. 
 *
 * A tag group content is restricted to COTag objects. 
 * Unlike COGroup, the content is ordered (to ensure the tag list order is  
 * stable in the UI on every use).
 *
 * Tags can be belong to multiple tag groups.
 */
@interface COTagGroup : COGroup
{

}

@end


typedef NSArray *(^COContentBlock)(void);

/**
 * @group Object Collection and Organization
 *
 * A custom group class whose content is provided a query or a code block.
 *
 * COSmartGroup is an immutable, ordered, weak (an object can be in any number 
 * of collections) collection class.
 *
 * Because it is an immutable collection, it isn't a COCollection subclass.
 */
@interface COSmartGroup : COObject <ETCollection>
{
	@private
	id <ETCollection> targetCollection;
	COQuery *query;
	COContentBlock contentBlock;
	NSArray *content;
}

/** @taskunit Controlling the Content */

@property (nonatomic, retain) id <ETCollection> targetCollection;
@property (nonatomic, retain) COQuery *query;
@property (nonatomic, copy) COContentBlock contentBlock;

/** @taskunit Accessing the Content */

- (id) content;

/** @taskunit Updating */

/**
 * Forces the receiver content to be recreated by evaluating the query or 
 * content block.
 *
 * See also -query and -contentBlock.
 */
- (void) refresh;

@end
