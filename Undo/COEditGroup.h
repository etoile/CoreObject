#import <Foundation/Foundation.h>
#import <CoreObject/COEdit.h>

@interface COEditGroup : COEdit
{
    NSMutableArray *_contents;
}

@property (nonatomic, readwrite, copy) NSMutableArray *contents;

@end
