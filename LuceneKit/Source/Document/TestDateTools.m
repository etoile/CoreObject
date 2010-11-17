#include "LCDateTools.h"
#include "GNUstep.h"
#include <UnitKit/UnitKit.h>

@interface TestDateTools: NSObject <UKTest>
@end

@implementation TestDateTools

- (NSString *) isoFormat: (NSCalendarDate *) date
{
	return [date descriptionWithCalendarFormat: @"%Y-%m-%d %H:%M:%S:%F"];
}

- (void) testStringToDate
{
	NSCalendarDate *date = [@"2004" calendarDate];
	UKStringsEqual(@"2004-01-01 00:00:00:000", [self isoFormat: date]);
	date = [@"20040705" calendarDate];
	UKStringsEqual(@"2004-07-05 00:00:00:000", [self isoFormat: date]);
	date = [@"200407050910" calendarDate];
	UKStringsEqual(@"2004-07-05 09:10:00:000", [self isoFormat: date]);
#if 0 // FIXME: millisecond doesn't work on Linux
	date = [@"20040705091055990" calendarDate];
	UKStringsEqual(@"2004-07-05 09:10:55:990", [self isoFormat: date]);
#endif
	
#if 0
    try {
		d = DateTools.stringToDate("97");    // no date
		fail();
    } catch(ParseException e) { /* expected excpetion */ }
    try {
		d = DateTools.stringToDate("200401011235009999");    // no date
		fail();
    } catch(ParseException e) { /* expected excpetion */ }
    try {
		d = DateTools.stringToDate("aaaa");    // no date
		fail();
    } catch(ParseException e) { /* expected excpetion */ }
#endif
}

- (void) testStringToTime
{
	NSTimeInterval t = [@"197001010000" timeIntervalSince1970];
	NSCalendarDate *d = [NSCalendarDate dateWithYear: 1970
		month: 1 day: 1 hour: 0 minute: 0 second: 0
		timeZone: [NSTimeZone timeZoneWithAbbreviation: @"GMT"]];
	UKTrue(t == [d timeIntervalSince1970]);
	t = [@"198002021105" timeIntervalSince1970];
	d = [NSCalendarDate dateWithYear: 1980
		month: 2 day: 2 hour: 11 minute: 5 second: 0
		timeZone: [NSTimeZone timeZoneWithAbbreviation: @"GMT"]];
	UKTrue(t == [d timeIntervalSince1970]);
}

- (void) testDateAndTimeToString
{
  NSCalendarDate *d = [NSCalendarDate dateWithYear: 2004
	month: 2 day: 3 hour: 22 minute: 8 second: 56
	timeZone: [NSTimeZone timeZoneWithAbbreviation: @"GMT"]];

  NSString *dateString = [NSString stringWithCalendarDate: d resolution: LCResolution_YEAR];
  UKStringsEqual(@"2004", dateString);
  UKStringsEqual(@"2004-01-01 00:00:00:000", [self isoFormat: [dateString calendarDate]]);

  dateString = [NSString stringWithCalendarDate: d resolution: LCResolution_MONTH];
  UKStringsEqual(@"200402", dateString);
  UKStringsEqual(@"2004-02-01 00:00:00:000", [self isoFormat: [dateString calendarDate]]);

  dateString = [NSString stringWithCalendarDate: d resolution: LCResolution_DAY];
  UKStringsEqual(@"20040203", dateString);
  UKStringsEqual(@"2004-02-03 00:00:00:000", [self isoFormat: [dateString calendarDate]]);

  dateString = [NSString stringWithCalendarDate: d resolution: LCResolution_HOUR];
  UKStringsEqual(@"2004020322", dateString);
  UKStringsEqual(@"2004-02-03 22:00:00:000", [self isoFormat: [dateString calendarDate]]);

  dateString = [NSString stringWithCalendarDate: d resolution: LCResolution_MINUTE];
  UKStringsEqual(@"200402032208", dateString);
  UKStringsEqual(@"2004-02-03 22:08:00:000", [self isoFormat: [dateString calendarDate]]);

  dateString = [NSString stringWithCalendarDate: d resolution: LCResolution_SECOND];
  UKStringsEqual(@"20040203220856", dateString);
  UKStringsEqual(@"2004-02-03 22:08:56:000", [self isoFormat: [dateString calendarDate]]);

#if 0
  dateString = DateTools.dateToString(cal.getTime(), DateTools.Resolution.MILLISECOND);
  assertEquals("20040203220856333", dateString);
  assertEquals("2004-02-03 22:08:56:333", isoFormat(DateTools.stringToDate(dateString)));
#endif

  // date before 1970:
  d = [NSCalendarDate dateWithYear: 1961 month: 3 day: 5 
	hour: 23 minute: 9 second: 51 timeZone: [NSTimeZone timeZoneWithAbbreviation: @"GMT"]];
  dateString = [NSString stringWithCalendarDate: d 
	resolution: LCResolution_SECOND];;
  UKStringsEqual(@"19610305230951", dateString);
  UKStringsEqual(@"1961-03-05 23:09:51:000", [self isoFormat: [dateString calendarDate]]);

  dateString = [NSString stringWithCalendarDate: d
	resolution: LCResolution_HOUR];;
  UKStringsEqual(@"1961030523", dateString);
  UKStringsEqual(@"1961-03-05 23:00:00:000", [self isoFormat: [dateString calendarDate]]);

  // timeToString:
  d = [NSCalendarDate dateWithYear: 1970 month: 1 day: 1 
       hour: 0 minute: 0 second: 0 timeZone: [NSTimeZone timeZoneWithAbbreviation: @"GMT"]];
  dateString = [NSString stringWithTimeIntervalSince1970: [d timeIntervalSince1970]
	resolution: LCResolution_MILLISECOND];;
  UKStringsEqual(@"19700101000000000", dateString);

  d = [NSCalendarDate dateWithYear: 1970 month: 1 day: 1 
	hour: 1 minute: 2 second: 3 timeZone: [NSTimeZone timeZoneWithAbbreviation: @"GMT"]];
  dateString = [NSString stringWithTimeIntervalSince1970: [d timeIntervalSince1970]
	resolution: LCResolution_MILLISECOND];;
  UKStringsEqual(@"19700101010203000", dateString);
}

- (void) testRound
{
	NSCalendarDate *d = [NSCalendarDate dateWithYear: 2004
											   month: 2 day: 3 hour: 22 minute: 8 second: 56
											timeZone: nil];
	UKStringsEqual(@"2004-02-03 22:08:56:000", [self isoFormat: d]);
	
	NSCalendarDate *r = [d dateWithResolution: LCResolution_YEAR];
	UKStringsEqual(@"2004-01-01 00:00:00:000", [self isoFormat: r]);
	
	r = [d dateWithResolution: LCResolution_MONTH];
	UKStringsEqual(@"2004-02-01 00:00:00:000", [self isoFormat: r]);
	
	r = [d dateWithResolution: LCResolution_DAY];
	UKStringsEqual(@"2004-02-03 00:00:00:000", [self isoFormat: r]);
	
	r = [d dateWithResolution: LCResolution_HOUR];
	UKStringsEqual(@"2004-02-03 22:00:00:000", [self isoFormat: r]);
	
	r = [d dateWithResolution: LCResolution_MINUTE];
	UKStringsEqual(@"2004-02-03 22:08:00:000", [self isoFormat: r]);
	
	r = [d dateWithResolution: LCResolution_SECOND];
	UKStringsEqual(@"2004-02-03 22:08:56:000", [self isoFormat: r]);
	
#if 0
    Date dateMillisecond = DateTools.round(date, DateTools.Resolution.MILLISECOND);
    assertEquals("2004-02-03 22:08:56:333", isoFormat(dateMillisecond));
#endif
	
    // long parameter:
	NSTimeInterval t = [d timeIntervalSince1970WithResolution: LCResolution_YEAR];
	r = [NSCalendarDate dateWithTimeIntervalSince1970: t];
	UKStringsEqual(@"2004-01-01 00:00:00:000", [self isoFormat: r]);
	
	t = [d timeIntervalSince1970WithResolution: LCResolution_MILLISECOND];
	r = [NSCalendarDate dateWithTimeIntervalSince1970: t];
	UKStringsEqual(@"2004-02-03 22:08:56:000", [self isoFormat: r]);
}

@end
