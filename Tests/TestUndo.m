#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"

@interface TestUndo : TestCommon <UKTest>
{
}
@end

@implementation TestUndo

- (id) init
{
    SUPERINIT;
    
    // FIXME: Hack
    [[NSFileManager defaultManager] removeItemAtPath: [@"~/coreobject-undo.sqlite" stringByExpandingTildeInPath] error: NULL];
    
    return self;
}

- (void) dealloc
{
    [super dealloc];
}

- (void)testBasic
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    [ctx commitWithStackNamed: @"test"];

    UKNil([[persistentRoot rootObject] valueForProperty: kCOLabel]);
    
    [[persistentRoot rootObject] setValue: @"hello" forProperty: kCOLabel];
    [ctx commitWithStackNamed: @"test"];
    
    UKObjectsEqual(@"hello", [[persistentRoot rootObject] valueForProperty: kCOLabel]);
    
    [ctx undoForStackNamed: @"test"];
    
    UKNil([[persistentRoot rootObject] valueForProperty: kCOLabel]);
}

@end
