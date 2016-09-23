/*
    Copyright (C) 2011 Christopher Armstrong

    Date:  October 2011
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>
#include <assert.h>

@interface Calendar : COObject
@property (nonatomic, readwrite, copy) NSSet *appointments;
@end

@interface Appointment : COObject
@property (nonatomic, readwrite, copy) NSDate *startDate;
@property (nonatomic, readwrite, copy) NSDate *endDate;
@property (nonatomic, readonly, weak) Calendar *calendar;

- (id)initWithStartDate: (NSDate *)aStartDate
                endDate: (NSDate *)aEndDate
	 objectGraphContext: (COObjectGraphContext *)aGraph;
@end


@implementation Calendar

+ (ETEntityDescription *)newEntityDescription
{
	ETEntityDescription *desc = [self newBasicEntityDescription];

	if (![desc.name isEqual: [Calendar className]])
		return desc;

	ETPropertyDescription *appointments = [ETPropertyDescription descriptionWithName: @"appointments"
	                                                                            typeName: @"Appointment"];
	appointments.multivalued = YES;
	appointments.ordered = NO;
	appointments.persistent = YES;

	desc.propertyDescriptions = @[appointments];

	return desc;
}

@dynamic appointments;

@end

@implementation Appointment 

+ (ETEntityDescription *)newEntityDescription
{
	ETEntityDescription *desc = [self newBasicEntityDescription];

	if (![desc.name isEqual: [Appointment className]])
		return desc;

	ETPropertyDescription *calendar = [ETPropertyDescription descriptionWithName: @"calendar"
	                                                                        typeName: @"Calendar"];
	calendar.oppositeName = @"Calendar.appointments";
	calendar.derived = YES;
	
	ETPropertyDescription *startDate = [ETPropertyDescription descriptionWithName: @"startDate"
	                                                                         typeName: @"NSDate"];
	startDate.persistent = YES;
	ETPropertyDescription *endDate = [ETPropertyDescription descriptionWithName: @"endDate"
	                                                                       typeName: @"NSDate"];
	endDate.persistent = YES;

	desc.propertyDescriptions = @[startDate, endDate, calendar];

	return desc;
}

- (id)initWithStartDate: (NSDate *)aStartDate
                endDate: (NSDate *)aEndDate
            objectGraphContext: (COObjectGraphContext *)aGraph
{
	self = [super initWithObjectGraphContext: aGraph];
	if (self == nil)
		return nil;
	
	self.startDate = aStartDate;
	self.endDate = aEndDate;

	return self;
}

@dynamic calendar, startDate, endDate;

@end


void ShowStoreContentsForContext(COEditingContext *newCtx);

int main(int argc, char **argv)
{
	@autoreleasepool
	{
		NSURL *url = [[NSURL fileURLWithPath: NSTemporaryDirectory() isDirectory: YES]
					  URLByAppendingPathComponent: @"TestStore.db"];
		
		// Create a new calendar and appointment and persist them

		COEditingContext *ctx = [COEditingContext contextWithURL: url];
		Calendar *calendar = [ctx insertNewPersistentRootWithEntityName: @"Calendar"].rootObject;
		ETUUID *persistentRootUUID = calendar.persistentRoot.UUID;
		NSDate *futureDate = [NSDate dateWithTimeIntervalSinceNow: 3600];
		Appointment *appointment = [[Appointment alloc] initWithStartDate: [NSDate date]
		                                                          endDate: futureDate
		                                               objectGraphContext: calendar.objectGraphContext];

		calendar.appointments = [NSSet setWithObject: appointment];

		[ctx commit];

		// Reload the calendar from a new context

		COEditingContext *newCtx = [COEditingContext contextWithURL: url];
		Calendar *newCalendar = [newCtx persistentRootForUUID: persistentRootUUID].rootObject;
		Appointment *newAppointment = newCalendar.appointments.anyObject;
	
		NSLog(@"Reloaded appointment: %@ - %@\n\n", newAppointment.startDate, newAppointment.endDate);

		ShowStoreContentsForContext(newCtx);
	}
	return 0;
}

/** 
 * If the example is run several times, persistent roots created during the previous runs will be
 * printed among the store contents in addition to the one just created.
 */
void ShowStoreContentsForContext(COEditingContext *ctx)
{
	NSLog(@"Store %@ contents:", ctx.store.URL.path);

	for (COPersistentRoot *persistentRoot in ctx.persistentRoots)
	{
		NSLog(@"\tPersistent root %@ (root object class: %@)", persistentRoot.UUID, [persistentRoot.rootObject class]);
		
		if (![persistentRoot.rootObject isKindOfClass: [Calendar class]])
			continue;
	
		Calendar *calendar = persistentRoot.rootObject;
			
		for (Appointment *appointment in calendar.appointments)
		{
			assert(appointment.calendar == calendar);

			NSLog(@"\t\tAppointment %@: %@ - %@", appointment.UUID, appointment.startDate, appointment.endDate);
		}
	}
}
