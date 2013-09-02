#import <Foundation/Foundation.h>
#import <CoreObject/COCommand.h>

@interface COCommandGroup : COCommand
{
    NSMutableArray *_contents;
}

@property (nonatomic, readwrite, copy) NSMutableArray *contents;

@end
