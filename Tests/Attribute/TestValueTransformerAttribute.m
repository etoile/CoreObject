#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

@interface ColorToStringTransformer : NSValueTransformer
@end
@implementation ColorToStringTransformer
+ (Class)transformedValueClass
{
	return [NSString class];
}
+ (BOOL)allowsReverseTransformation
{
	return YES;
}

static NSString *HexFromFraction(CGFloat fraction)
{
	return [NSString stringWithFormat: @"%02x", (unsigned char)(fraction * 255)];
}

static CGFloat FractionFromHex(NSString *twoChars)
{
	int value = 0;
	if (1 == sscanf([twoChars UTF8String], "%x", &value))
	{
		return value / 255.0;
	}
	return 0;
}

static NSString *ColorToString(NSColor *color)
{
	NSColor *rgbColor = [color colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
	CGFloat a, r, g, b;
	[rgbColor getRed: &r green: &g blue: &b alpha: &a];
	
	return [NSString stringWithFormat: @"#%@%@%@%@", HexFromFraction(a), HexFromFraction(r), HexFromFraction(g), HexFromFraction(b)];
}

static NSColor *ColorFromString(NSString *color)
{
	CGFloat a = FractionFromHex([color substringWithRange: NSMakeRange(1, 2)]);
	CGFloat r = FractionFromHex([color substringWithRange: NSMakeRange(3, 2)]);
	CGFloat g = FractionFromHex([color substringWithRange: NSMakeRange(5, 2)]);
	CGFloat b = FractionFromHex([color substringWithRange: NSMakeRange(7, 2)]);
	
	return [NSColor colorWithCalibratedRed: r green: g blue: b alpha: a];
}

- (id)transformedValue: (id)value
{
	ETAssert([value isKindOfClass: [NSColor class]]);
	NSColor *color = value;
	
	NSString *string = ColorToString(color);
	return string;
}

- (id)reverseTransformedValue: (id)value
{
	ETAssert([value isKindOfClass: [NSString class]]);
	NSString *string = value;
	
	NSColor *color = ColorFromString(string);
	return color;
}
@end

@interface ValueTransformerModel : COObject
@property (readwrite, strong, nonatomic) NSColor *color;
@end

@implementation ValueTransformerModel

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"ValueTransformerModel"];
    [entity setParent: (id)@"COObject"];
	
    ETPropertyDescription *colorProperty = [ETPropertyDescription descriptionWithName: @"color"
																				 type: (id)@"NSColor"];
	colorProperty.valueTransformerName = @"ColorToStringTransformer";
	colorProperty.persistentType = (id)@"NSString";
    colorProperty.persistent = YES;
	
	[entity setPropertyDescriptions: @[colorProperty]];
	
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
	[ctx setRootObject: item1];
	return self;
}

- (void) testMetamodel
{
	ETPropertyDescription *colorPropDesc = [[item1 entityDescription] propertyDescriptionForName: @"color"];
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
