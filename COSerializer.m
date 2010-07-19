#import "COSerializer.h"

@implementation COSerializer

+ (NSData *) serializeObject: (id)object
{
  return [NSPropertyListSerialization dataFromPropertyList: object
                          format:NSPropertyListXMLFormat_v1_0
                            errorDescription:NULL];
}

+ (id) unserializeData: (NSData *)data
{
  return [NSPropertyListSerialization propertyListFromData:data
   mutabilityOption:NSPropertyListMutableContainersAndLeaves
     format:NULL
      errorDescription:NULL];
}

@end
