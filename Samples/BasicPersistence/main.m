 #import <CoreObject/CoreObject.h>

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

- (id)init
{
	SUPERINIT;
	appointments = [NSMutableArray new];
	today = [[NSDate date] retain];
	return self;
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

- (void)addAppointment: (Appointment*)anAppointment
{
	[self insertObject: anAppointment atIndex: ETUndeterminedIndex hint: nil forProperty: @"appointments"];
}

- (NSDate*)today
{
	return today;
}

- (void)setDate: (NSDate*)date
{
	[self willChangeValueForProperty: @"date"];
	ASSIGN(today, date);
	[self didChangeValueForProperty: @"date"];
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
	[self willChangeValueForProperty: @"calendar"];
	calendar = aCalendar;
	[self willChangeValueForProperty: @"calendar"];
}

@end

int main(int argc, char **argv)
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	// Initialize the AppKit (for now CoreObject requires it)
	[NSApplication sharedApplication];

	COSQLiteStore *store = [[COSQLiteStore alloc] initWithURL: [NSURL fileURLWithPath: @"TestStore.db"]];
	COEditingContext *ctx = [[COEditingContext alloc] initWithStore: store];
	
	// Create the calendar and appointment and persist them

	Calendar *calendar = [[ctx insertNewPersistentRootWithEntityName: @"Anonymous.Calendar"] rootObject];
	ETUUID *persistentRootUUID = [[calendar persistentRoot] persistentRootUUID];
	NSDate *futureDate = [NSDate dateWithTimeIntervalSinceNow: 3600];
	Appointment *appointment = AUTORELEASE([[Appointment alloc] initWithStartDate: [NSDate date]
	                                                                      endDate: futureDate]);

	[appointment becomePersistentInContext: [calendar persistentRoot]];

	[calendar addAppointment: appointment];

	[ctx commit];
	[ctx release];

	// Reload the calendar from a new context

	ctx = [[COEditingContext alloc] initWithStore: store];
										
	calendar = [[ctx persistentRootForUUID: persistentRootUUID] rootObject];
	appointment = [[calendar appointments] firstObject];
										
	NSLog(@"Reloaded calendar with date: %@", [calendar today]);
	NSLog(@"First appointment: %@ - %@", [appointment startDate], [appointment endDate]);

	[ctx release];
	[store release];
	[pool drain];
	return 0;
}
