#import "Project.h"


@implementation Project

@synthesize delegate; // notification hack - remove when we can use KVO

+ (void)initialize
{
  if (self == [Project class])
  {
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"Project"];

    ETPropertyDescription *documentsProperty = [ETPropertyDescription descriptionWithName: @"documents"
                                                                                     type: (id)@"Document"];
    [documentsProperty setMultivalued: YES];
    
    [entity setPropertyDescriptions: A(documentsProperty)];
    
    [[ETModelDescriptionRepository mainRepository] addUnresolvedDescription: entity];
    [[ETModelDescriptionRepository mainRepository] setEntityDescription: entity
                                              forClass: self];
                                              
    [[ETModelDescriptionRepository mainRepository] resolveNamedObjectReferences];
  }
}

- (NSSet*) documents
{
  [self willAccessValueForProperty: @"documents"];
  return documents;
}
- (void) addDocument: (Document *)document
{
  [self willChangeValueForProperty: @"documents"];
  [documents addObject: document];
  [self didChangeValueForProperty: @"documents"];

  [delegate projectDocumentsDidChange: self]; // notification hack - remove when we can use KVO
}
- (void) removeDocument: (Document *)document
{
  [self willChangeValueForProperty: @"documents"];
  [documents removeObject: document];
  [self didChangeValueForProperty: @"documents"];
  
  [delegate projectDocumentsDidChange: self];// notification hack - remove when we can use KVO
}

- (void)didAwaken
{
  [delegate projectDocumentsDidChange: self];// notification hack - remove when we can use KVO
}

@end
