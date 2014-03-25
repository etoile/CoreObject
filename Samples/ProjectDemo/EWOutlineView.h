#import <AppKit/AppKit.h>

@class EWOutlineView;

@protocol EWOutlineViewDelegate <NSObject>
- (void) outlineViewDidStartFieldEditor: (EWOutlineView *)aView;
- (void) outlineViewDidEndFieldEditor: (EWOutlineView *)aView;
@end

@interface EWOutlineView : NSOutlineView

@property (readwrite, nonatomic, unsafe_unretained) id<EWOutlineViewDelegate> delegate;

@end
