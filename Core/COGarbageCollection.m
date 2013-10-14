/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  October 2013
	License:  Modified BSD  (see COPYING)

 */

#import "COGarbageCollection.h"
#import "CODictionary.h"

@implementation COObject (COGarbageCollection)

static void FindAllStronglyContainedObjects(COObject *anObj, NSMutableSet *dest)
{    
	for (ETPropertyDescription *propDesc in [[anObj entityDescription] allPropertyDescriptions])
	{
		if ([propDesc isComposite])
		{
			id value = [anObj valueForProperty: [propDesc name]];
			
			assert([propDesc isMultivalued] ==
				   ([value isKindOfClass: [NSArray class]] || [value isKindOfClass: [NSSet class]]));
			
			if ([propDesc isMultivalued])
			{
				for (id subvalue in value)
				{
					if ([subvalue isKindOfClass: [COObject class]])
					{
                        assert(![dest containsObject: subvalue] && ![anObj isEqual: subvalue]);
						[dest addObject: subvalue];
						FindAllStronglyContainedObjects(subvalue, dest);
					}
				}
			}
			else
			{
				if ([value isKindOfClass: [COObject class]])
				{
                    assert(![dest containsObject: value] && ![anObj isEqual: value]);
					[dest addObject: value];
                    FindAllStronglyContainedObjects(value, dest);
				}
				// Ignore non-COObject objects
			}
		}
	}
}

- (NSArray*)allStronglyContainedObjects
{
	NSMutableSet *result = [NSMutableSet set];
    FindAllStronglyContainedObjects(self, result);
    return [result allObjects];
}

- (NSArray*)embeddedOrReferencedObjects
{
	NSMutableArray *result = [NSMutableArray array];
	for (ETPropertyDescription *propDesc in [[self entityDescription] allPropertyDescriptions])
	{
		NSString *propertyName = [propDesc name];

		// FIXME: Accessing -modification and -creationDate is slow currently.
		// We can probably skip all transient property descriptions or at least
		// property descriptions that are attributes...
		if ([propertyName isEqualToString: @"modificationDate"]
			|| [propertyName isEqualToString: @"creationDate"])
		{
			continue;
		}
	
        id value = [self valueForKey: propertyName];
        
        if ([propDesc isMultivalued])
        {
			if ([propDesc isKeyed])
			{
				assert([value isKindOfClass: [CODictionary class]] || [value isKindOfClass: [NSDictionary class]]);
			}
			else
			{
				assert([value isKindOfClass: [NSArray class]] || [value isKindOfClass: [NSSet class]]);
				
			}

			/* We use -objectEnumerator, because subvalue can be a  CODictionary
			   or a NSDictionary (if a getter exists to expose the CODictionary 
			   as a NSDictionary for UI editing) */
            for (id subvalue in [value objectEnumerator])
            {
                if ([subvalue isKindOfClass: [COObject class]])
                {
                    [result addObject: subvalue];
                    [result addObjectsFromArray: [subvalue allStronglyContainedObjects]];
                }
            }
        }
        else
        {
            if ([value isKindOfClass: [COObject class]])
            {
                [result addObject: value];
                [result addObjectsFromArray: [value allStronglyContainedObjects]];
            }
            // Ignore non-COObject objects
        }
	}
	return result;
}

@end
