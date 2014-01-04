/*
    Copyright (C) 2011 Christopher Armstrong

    Date:  October 2011
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>
#include <assert.h>

@interface Calendar : COObject
@property (nonatomic, readwrite, strong) NSSet *appointments;
@end

@interface Appointment : COObject
@property (nonatomic, readwrite, strong) NSDate *startDate;
@property (nonatomic, readwrite, strong) NSDate *endDate;
@property (nonatomic, readonly, weak) Calendar *calendar;

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
		ETPropertyDescription *appointments = [ETPropertyDescription descriptionWithName: @"appointments"
																					type: (id)@"Anonymous.Appointment"];
		[appointments setMultivalued: YES];
		[appointments setOrdered: NO];
		[appointments setPersistent: YES];
		[desc setPropertyDescriptions: @[appointments]];
	}
	return desc;
}

@dynamic appointments;

- (void) addAppointment: (Appointment*)anAppointment
{
	[[self mutableSetValueForKey: @"appointments"] addObject: anAppointment];
}

@end

@implementation Appointment 

+ (ETEntityDescription*)newEntityDescription
{
	ETEntityDescription *desc = [self newBasicEntityDescription];
	if ([[desc name] isEqual: [Appointment className]])
	{
		ETPropertyDescription *calendar = [ETPropertyDescription descriptionWithName: @"calendar"
																				type: (id)@"Calendar"];
		[calendar setOpposite: (id)@"Calendar.appointments"];
		ETPropertyDescription *startDate = [ETPropertyDescription descriptionWithName: @"startDate"
																				 type: (id)@"NSDate"];
		[startDate setPersistent: YES];
		ETPropertyDescription *endDate = [ETPropertyDescription descriptionWithName: @"endDate"
																			   type: (id)@"NSDate"];
		[endDate setPersistent: YES];
		[desc setPropertyDescriptions: A(startDate, endDate, calendar)];
	}
	return desc;
}

- (id)initWithStartDate: (NSDate*)aStartDate
                endDate: (NSDate*)aEndDate
            objectGraphContext: (COObjectGraphContext *)aGraph
{
	self = [super initWithObjectGraphContext:aGraph];
	self.startDate = aStartDate;
	self.endDate = aEndDate;
	return self;
}

@dynamic calendar, startDate, endDate;

@end

int main(int argc, char **argv)
{
	@autoreleasepool
	{
		NSURL *url = [NSURL fileURLWithPath: @"TestStore.db"];
		ETUUID *persistentRootUUID = nil;
		
		{
			COEditingContext *ctx = [COEditingContext contextWithURL: url];
			
			// Create a new calendar and appointment and persist them

			Calendar *calendar = [[ctx insertNewPersistentRootWithEntityName: @"Calendar"] rootObject];
			persistentRootUUID = [[calendar persistentRoot] UUID];
			NSDate *futureDate = [NSDate dateWithTimeIntervalSinceNow: 3600];
			Appointment *appointment = [[Appointment alloc] initWithStartDate: [NSDate date]
																	  endDate: futureDate
														   objectGraphContext: [calendar objectGraphContext]];
			[calendar addAppointment: appointment];

			[ctx commit];
		}
		
		{
			// Reload the calendar from a new context

			COEditingContext *ctx = [COEditingContext contextWithURL: url];
			
			NSLog(@"Store %@ contents:", [url path]);
			for (COPersistentRoot *persistentRoot in ctx.persistentRoots)
			{
				NSLog(@"\tPersistent root %@ (root object class: %@)",
					  [persistentRoot UUID], [[persistentRoot rootObject] class]);
				
				if ([[persistentRoot rootObject] isKindOfClass: [Calendar class]])
				{
					Calendar *calendar = [persistentRoot rootObject];
					
					for (Appointment *appointment in calendar.appointments)
					{
						assert(appointment.calendar == calendar);
						NSLog(@"\t\tAppointment %@: %@ - %@", [appointment UUID], [appointment startDate], [appointment endDate]);
					}
				}
			}
			
		}
	}
	return 0;
}
