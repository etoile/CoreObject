#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "COHistoryTrack.h"
#import "COGroup.h"
#import "COCollection.h"
#import "TestCommon.h"

@interface TestObjectGraphDiff : NSObject <UKTest>
{
}
@end

@implementation TestObjectGraphDiff

- (void)testBasic
{
	COEditingContext *ctx = NewContext();
	
	// FIXME:
	
	TearDownContext(ctx);
}
@end
