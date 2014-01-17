#import <Cocoa/Cocoa.h>

#import "EWGraphRenderer.h"

@interface EWGraphCell : NSCell
{
	IBOutlet EWGraphRenderer *graphRenderer;
}

@end
