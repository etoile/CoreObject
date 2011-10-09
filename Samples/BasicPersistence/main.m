#import <EtoileFoundation/ETModelDescriptionRepository.h>

#import <ObjectMerging/COObject.h>
#import <ObjectMerging/COStore.h>
#import <ObjectMerging/COEditingContext.h>

#import <Foundation/NSDate.h>


@interface Calendar : COObject
{
	NSMutableArray *appointments;
	NSDate *today;
}

- (NSArray*)appointments;
- (NSDate*)today;
@end

@interface Appointment : COObject
{
	NSDate *startDate, *endDate;
	Calendar *calendar;
}
- (id)initWithStartDate: (NSDate*)startDate
                endDate: (NSDate*)endDate;
@end

@implementation Calendar
- (void)didCreate
{
	appointments = [NSMutableArray new];
	today = [[NSDate date] retain];
}
- (void)dealloc
{
	[today release];
	[appointments release];
	[super dealloc];
}
- (NSArray*)appointments
{
	return appointments;
}
- (NSDate*)today
{
	return today;
}
- (void)setDate: (NSDate*)date
{
	ASSIGN(today, date);
}
+ (ETEntityDescription*)newEntityDescription
{
	ETEntityDescription *desc = [self newBasicEntityDescription];
	if ([[desc name] isEqual: [Calendar className]])
	{
		ETModelDescriptionRepository *repo = [ETModelDescriptionRepository mainRepository];
		[desc setParent: (id)@"Anonymous.COObject"];
		ETPropertyDescription *today = [ETPropertyDescription 
		 	descriptionWithName: @"today"
		 	               type: [repo descriptionForName: @"Anonymous.NSDate"]];
		ETPropertyDescription *appointments = [ETPropertyDescription
			descriptionWithName: @"appointments"
			               type: (id)@"Anonymous.Appointment"];
		[appointments setMultivalued: YES];
		[appointments setOrdered: YES];
		[desc setPropertyDescriptions: A(appointments, today)];
		[[[desc propertyDescriptions] mappedCollection] setPersistent: YES];
	}
	return desc;
}
@end

@implementation Appointment 
+ (ETEntityDescription*)newEntityDescription
{
	ETEntityDescription *desc = [self newBasicEntityDescription];
	if ([[desc name] isEqual: [Appointment className]])
	{
		ETModelDescriptionRepository *repo = [ETModelDescriptionRepository mainRepository];
		[desc setParent: (id)@"Anonymous.COObject"];
		ETPropertyDescription *calendar = [ETPropertyDescription
			descriptionWithName: @"calendar"
			               type: (id)@"Anonymous.Calendar"];
		[calendar setMultivalued: YES];
		[calendar setOpposite: (id)@"Anonymous.Calendar.appointments"];
		ETPropertyDescription *startDate = [ETPropertyDescription
			descriptionWithName: @"startDate"
			               type: [repo descriptionForName: @"Anonymous.NSDate"]];
		ETPropertyDescription *endDate = [ETPropertyDescription
			descriptionWithName: @"endDate"
			               type: [repo descriptionForName: @"Anonymous.NSDate"]];
		[desc setPropertyDescriptions: A(startDate, endDate, calendar)];
		[[[desc propertyDescriptions] mappedCollection] setPersistent: YES];
	}
	return desc;
}
- (id)initWithStartDate: (NSDate*)aStartDate
                endDate: (NSDate*)aEndDate
{
	SUPERINIT;
	startDate = [aStartDate retain];
	endDate = [aEndDate retain];
	return self;
}
- (NSDate*)startDate
{
	return startDate;
}
- (NSDate*)endDate
{
	return endDate;
}
- (Calendar*)calendar
{
	return calendar;
}
- (void)setCalendar: (Calendar*)aCalendar
{
	calendar = aCalendar;
}
@end

int main(int argc, char **argv)
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	COStore *store = [[COStore alloc]
		initWithURL: [NSURL fileURLWithPath: @"TestStore.db"]];

	ETUUID* calendarID;

	// Create the calendar and appointment and persist them
	COEditingContext *ctx = [[COEditingContext alloc]
		initWithStore: store];
	Calendar *calendar = [ctx insertObjectWithEntityName: @"Anonymous.Calendar"];
	calendarID = [calendar UUID];
	Appointment *firstAppt = [[Appointment alloc]
		initWithStartDate: [NSDate date]
		          endDate: [NSDate dateWithTimeIntervalSinceNow: 3600]];
	[firstAppt becomePersistentInContext: ctx
		                  rootObject: calendar];
	[calendar addObject: firstAppt forProperty: @"appointments"]; 
	[ctx commit];
	[ctx release];

	// Reload the calendar from a new context
	ctx = [[COEditingContext alloc] initWithStore: store];
	calendar = (Calendar*)[ctx objectWithUUID: calendarID];
	firstAppt = [[calendar appointments] objectAtIndex: 0];
	NSLog(@"Reloaded calendar with date: %@", [calendar today]);
	NSLog(@"First appointment: %@ - %@", [firstAppt startDate], [firstAppt endDate]);
	[ctx release];
	[store release];
	[pool drain];
	return 0;
}
