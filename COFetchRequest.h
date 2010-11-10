#import <EtoileFoundation/EtoileFoundation.h>


@interface COFetchRequest : NSObject
{
	NSPredicate *_predicate;
	NSSortDescriptor *_sortDescriptor;
}

@end
