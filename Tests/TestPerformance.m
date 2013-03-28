#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "COEditingContext.h"
#import "TestCommon.h"
#import "COContainer.h"

@interface TestPerformance : NSObject <UKTest>
@end

@implementation TestPerformance

#if 0
- (void)testManyObjects
{
	UKFalse([ctx hasChanges]);
	
	NSLog(@"Starting performance test");
	
	COContainer *root = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	for (int i=0; i<10; i++)
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		COContainer *level1 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
		[level1 setValue: [NSString stringWithFormat: @"%d", i] forProperty: @"label"];
		[root addObject: level1];
		for (int j=0; j<10; j++)
		{
			COContainer *level2 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
			[level2 setValue: [NSString stringWithFormat: @"%d.%d", i, j] forProperty: @"label"];
			[level1 addObject: level2];
			for (int k=0; k<10; k++)
			{
				COContainer *level3 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
				[level3 setValue: [NSString stringWithFormat: @"%d.%d.%d", i, j, k] forProperty: @"label"];
				[level2 addObject: level3];
			}
		}
		[pool release];
	}

	NSLog(@"Comitting...");
	
	[ctx commit];
	
	NSLog(@"Done.");

	UKPass();
}
#endif

@end
