#import <AppKit/AppKit.h>

@class EWOutlineView;

@protocol EWOutlineViewDelegate <NSObject>
- (void) outlineViewDidStartFieldEditor: (EWOutlineView *)aView;
- (void) outlineViewDidEndFieldEditor: (EWOutlineView *)aView;
@end

@interface EWOutlineView : NSOutlineView

@property (readwrite, nonatomic, weak) id<EWOutlineViewDelegate> delegate;

@end
