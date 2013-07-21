#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import <NestedVersioning/NestedVersioning.h>

#define STOREPATH [@"~/om6teststore" stringByExpandingTildeInPath]
#define STOREURL [NSURL fileURLWithPath: STOREPATH]

@interface COSQLiteStoreTestCase : NSObject
{
    COSQLiteStore *store;
}

@end
