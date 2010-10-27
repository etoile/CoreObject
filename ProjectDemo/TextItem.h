#import <Cocoa/Cocoa.h>
#import "COObject.h"

@interface TextItem : COObject
{
  NSMutableDictionary *textAttributes;
  NSString *text;
}

@end