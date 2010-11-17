#include "LCQueryParser.h"
#include "LCBooleanQuery.h"
#include "LCPrefixQuery.h"
#include "LCTermQuery.h"
#include "LCMetadataAttribute.h"
#include "GNUstep.h"
#include "CodeParser.h"
#include "QueryHandler.h"

@implementation LCQueryParser

+ (LCQuery *) parse: (NSString *) query
{
  return [LCQueryParser parse: query defaultField: LCTextContentAttribute];
}

+ (LCQuery *) parse: (NSString *) query defaultField: (NSString *) field
{
  QueryHandler *handler = AUTORELEASE([[QueryHandler alloc] init]);
  [handler setDefaultField: field];
  CodeParser *parser = AUTORELEASE([[CodeParser alloc] initWithCodeHandler: handler withString: query]);
  [parser parse];
//  NSLog(@"%@", [handler query]);
  return [handler query];
}

@end

