#import <Cocoa/Cocoa.h>

#import "EWHistoryGraphView.h"
#import "EWUtilityWindowController.h"

@interface EWHistoryWindowController : EWUtilityWindowController
{
    IBOutlet EWHistoryGraphView *graphView_;
}

+ (EWHistoryWindowController *) sharedController;

- (void) show;

- (IBAction) sliderChanged: (id)sender;

@end
