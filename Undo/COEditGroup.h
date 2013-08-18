#import <Foundation/Foundation.h>
#import <CoreObject/COEdit.h>

@interface COEditGroup : COEdit
{
    NSArray *_contents;
}

@property (nonatomic, readwrite, copy) NSArray *contents;

@end
