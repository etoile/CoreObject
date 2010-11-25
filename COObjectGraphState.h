#import <Cocoa/Cocoa.h>


@interface COObjectGraphState : NSObject
{
	NSMutableDictionary *commitUUIDForObjectUUID;
	NSMutableDictionary *branchUUIDForObjcetUUID;
}

@end
