/*
    Copyright (C) 2011 Christopher Armstrong

    Date:  October 2011
    License:  MIT  (see COPYING)
 */

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
- (id)initWithStartDate: (NSDate*)aStartDate
                endDate: (NSDate*)aEndDate
            objectGraphContext: (COObjectGraphContext *)aGraph;
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

- (id)initWithObjectGraphContext:(COObjectGraphContext *)aContext
{
	self = [super initWithObjectGraphContext: aContext];
	appointments = [NSMutableArray new];
	today = [NSDate date];
	return self;
}


- (NSArray*)appointments
{
	return appointments;
}

- (void)addAppointment: (Appointment*)anAppointment
{
	[[self mutableArrayValueForKey: @"appointments"] addObject: anAppointment];
}

- (NSDate*)today
{
	return today;
}

- (void)setDate: (NSDate*)date
{
	[self willChangeValueForProperty: @"date"];
	today =  date;
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
            objectGraphContext: (COObjectGraphContext *)aGraph
{
	self = [super initWithObjectGraphContext:aGraph];
	startDate = aStartDate;
	endDate = aEndDate;
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
	@autoreleasepool
	{
		COSQLiteStore *store = [[COSQLiteStore alloc] initWithURL: [NSURL fileURLWithPath: @"TestStore.db"]];
		COEditingContext *ctx = [[COEditingContext alloc] initWithStore: store];
		
		// Create the calendar and appointment and persist them

		Calendar *calendar = [[ctx insertNewPersistentRootWithEntityName: @"Anonymous.Calendar"] rootObject];
		ETUUID *persistentRootUUID = [[calendar persistentRoot] UUID];
		NSDate *futureDate = [NSDate dateWithTimeIntervalSinceNow: 3600];
		Appointment *appointment = [[Appointment alloc] initWithStartDate: [NSDate date]
																  endDate: futureDate
													   objectGraphContext: [calendar objectGraphContext]];
		[calendar addAppointment: appointment];

		[ctx commit];

		// Reload the calendar from a new context

		ctx = [[COEditingContext alloc] initWithStore: store];
											
		calendar = [[ctx persistentRootForUUID: persistentRootUUID] rootObject];
		appointment = [[calendar appointments] firstObject];
											
		NSLog(@"Reloaded calendar with date: %@", [calendar today]);
		NSLog(@"First appointment: %@ - %@", [appointment startDate], [appointment endDate]);
	}
	return 0;
}
