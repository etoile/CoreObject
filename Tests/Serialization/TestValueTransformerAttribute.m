/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

@interface ValueTransformerModel : COObject
@property (readwrite, strong, nonatomic) NSColor *color;
@end

@implementation ValueTransformerModel

+ (ETEntityDescription*)newEntityDescription
{
	ETEntityDescription *entity = [self newBasicEntityDescription];
	
	if (![entity.name isEqual: [ValueTransformerModel className]])
		return entity;

#if TARGET_OS_IPHONE
	NSString *colorType = @"UIColor";
#else
	NSString *colorType = @"NSColor";
#endif

    ETPropertyDescription *colorProperty = [ETPropertyDescription descriptionWithName: @"color"
																				 type: (id)colorType];
	colorProperty.valueTransformerName = @"COColorToHTMLString";
	colorProperty.persistentType = (id)@"NSString";
    colorProperty.persistent = YES;
	
	entity.propertyDescriptions = @[colorProperty];
	
    return entity;
}

@dynamic color;

@end

@interface TestValueTransformerAttribute : TestCase <UKTest>
{
	COObjectGraphContext *ctx;
	ValueTransformerModel *item1;
}
@end

@implementation TestValueTransformerAttribute

- (id) init
{
	SUPERINIT;
	ctx = [COObjectGraphContext new];
	item1 = [ctx insertObjectWithEntityName: @"ValueTransformerModel"];
	ctx.rootObject = item1;
	return self;
}

- (void) testMetamodel
{
	ETPropertyDescription *colorPropDesc = [item1.entityDescription propertyDescriptionForName: @"color"];
	NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName: colorPropDesc.valueTransformerName];
	ETEntityDescription *persistentType = colorPropDesc.persistentType;
	
	UKObjectKindOf(transformer, NSValueTransformer);
	UKObjectKindOf(persistentType, ETEntityDescription);
	
	UKObjectsEqual(@"NSString", [persistentType name]);
}

- (void) testSerialization
{
	item1.color = [NSColor redColor];
	
	UKObjectsEqual(@"#ffff0000", [[item1 storeItem] valueForAttribute: @"color"]);
}

- (void) testRoundTrip
{
	item1.color = [NSColor redColor];
	
	[self checkObjectGraphBeforeAndAfterSerializationRoundtrip: ctx
													   inBlock: ^(COObjectGraphContext *testGraph, COObject *testRootObject, BOOL isObjectGraphCopy)
	 {
		 ValueTransformerModel *testItem1 = (ValueTransformerModel *)testRootObject;
		 NSColor *roundTripColor = testItem1.color;
		 
		 UKObjectsEqual([NSColor redColor], roundTripColor);
	 }];
}

@end
