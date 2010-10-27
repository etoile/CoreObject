#import <Cocoa/Cocoa.h>
#import <EtoileFoundation/EtoileFoundation.h>

@interface SharingMessage : NSObject
{
  ETUUID *baseHistoryGraphNode;
  NSMutableDictionary *uuidToObjectDataMapping;
  
}

- (id)initWithPropertyList: (NSDictionary*)plist;
- (NSDictionary*)propertyList;



@end
