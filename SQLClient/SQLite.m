/* -*-objc-*- */

/** Implementation of SQLClientPostgres for GNUStep
   Copyright (C) 2005 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date:	Nov 2005
   
   This file is part of the SQLClient Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   $Date$ $Revision$
   */ 

#import	<Foundation/NSAutoreleasePool.h>
#import	<Foundation/NSCalendarDate.h>
#import	<Foundation/NSData.h>
#import	<Foundation/NSDate.h>
#import	<Foundation/NSException.h>
#import	<Foundation/NSLock.h>
#import	<Foundation/NSMapTable.h>
#import	<Foundation/NSNotification.h>
#import	<Foundation/NSNull.h>
#import	<Foundation/NSPathUtilities.h>
#import	<Foundation/NSProcessInfo.h>
#import	<Foundation/NSString.h>
#import	<Foundation/NSUserDefaults.h>
#import	<Foundation/NSValue.h>

#include	"config.h"

#ifdef BUILD_SQLITE_BACKEND

#define SQLCLIENT_PRIVATE       @public

#include	"SQLClient.h"
#include	<string.h>
#include	<sqlite3.h>

@interface SQLClientSQLite : SQLClient
@end

@implementation	SQLClientSQLite

/* use [self database] as path to database file */
- (BOOL) backendConnect
{
  if (connected == NO)
    {
      if ([self database] != nil)
	{
	  NSString	*dbase = [self database];
	  sqlite3	*sql;
	  int		result;

	  [[self class] purgeConnections: nil];

	  if ([self debugging] > 0)
	    {
	      [self debug: @"Connect to '%@' as %@",
		[self database], [self name]];
	    }
	  result = sqlite3_open([dbase fileSystemRepresentation], &sql);
	  if (result != 0)
	    {
	      [self debug: @"Error connecting to '%@' (%@) - %s",
		[self name], [self database], sqlite3_errmsg(sql)];
	      sqlite3_close(sql);
	      extra = 0;
	    }
	  else
	    {
	      connected = YES;
              extra = sql;

	      if ([self debugging] > 0)
		{
		  [self debug: @"Connected to '%@'", [self name]];
		}
	    }
	}
      else
	{
	  [self debug: @"Connect to '%@' with no database configured",
	    [self name]];
	}
    }
  return connected;
}

- (void) backendDisconnect
{
  if (connected == YES)
    {
      NS_DURING
	{
	  if ([self isInTransaction] == YES)
	    {
	      [self rollback];
	    }

	  if ([self debugging] > 0)
	    {
	      [self debug: @"Disconnecting client %@", [self clientName]];
	    }
	  sqlite3_close((sqlite3 *)extra);
	  extra = 0;
	  if ([self debugging] > 0)
	    {
	      [self debug: @"Disconnected client %@", [self clientName]];
	    }
	}
      NS_HANDLER
	{
	  extra = 0;
	  [self debug: @"Error disconnecting from database (%@): %@",
	    [self clientName], localException];
	}
      NS_ENDHANDLER
      connected = NO;
    }
}

- (NSInteger) backendExecute: (NSArray*)info
{
  NSString	        *stmt;
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];

  stmt = [info objectAtIndex: 0];
  if ([stmt length] == 0)
    {
      [arp release];
      [NSException raise: NSInternalInconsistencyException
		  format: @"Statement produced null string"];
    }

  NS_DURING
    {
      const char	*statement;
      unsigned		length;
      int		result;
      char		*err;

      /*
       * Ensure we have a working connection.
       */
      if ([self connect] == NO)
	{
	  [NSException raise: SQLException
	    format: @"Unable to connect to '%@' to execute statement %@",
	    [self name], stmt];
	} 

      statement = (char*)[stmt UTF8String];
      length = strlen(statement);
      statement = [self insertBLOBs: info
	              intoStatement: statement
			     length: length
			 withMarker: "'?'''?'"
			     length: 7
			     giving: &length];

      result = sqlite3_exec((sqlite3 *)extra, statement, 0, 0, &err);
      if (result != SQLITE_OK)
	{
	  [NSException raise: SQLException format: @"%s", err];
	}
    }
  NS_HANDLER
    {
      NSString	*n = [localException name];

      if ([n isEqual: SQLConnectionException] == YES) 
	{
	  [self disconnect];
	}
      if ([self debugging] > 0)
	{
	  [self debug: @"Error executing statement:\n%@\n%@",
	    stmt, localException];
	}
      [localException retain];
      [arp release];
      [localException autorelease];
      [localException raise];
    }
  NS_ENDHANDLER
  [arp release];
  return -1;
}

- (NSMutableArray*) backendQuery: (NSString*)stmt
		      recordType: (id)rtype
		        listType: (id)ltype
{
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];
  NSMutableArray	*records = [[ltype alloc] initWithCapacity: 2];

  if ([stmt length] == 0)
    {
      [arp release];
      [NSException raise: NSInternalInconsistencyException
		  format: @"Statement produced null string"];
    }

  NS_DURING
    {
      char		*statement;
      int		result;
      sqlite3_stmt	*prepared;
      const char	*stmtEnd;

      /*
       * Ensure we have a working connection.
       */
      if ([self connect] == NO)
	{
	  [NSException raise: SQLException
	    format: @"Unable to connect to '%@' to run query %@",
	    [self name], stmt];
	} 

      statement = (char*)[stmt UTF8String];
      result = sqlite3_prepare((sqlite3 *)extra,
	statement, strlen(statement), &prepared, &stmtEnd);
      if (result != SQLITE_OK)
	{
	  [NSException raise: SQLException
	    format: @"Unable to prepare '%@'", stmt];
	}
      if ((result = sqlite3_step(prepared)) == SQLITE_ROW)
        {
	  int		columns = sqlite3_column_count(prepared);
	  NSString	*keys[columns];
	  int		i;

	  for (i = 0; i < columns; i++)
	    {
	      keys[i] = [NSString stringWithUTF8String: 
		sqlite3_column_name(prepared, i)];
	    }

          do
	    {
	      id		values[columns];
	      SQLRecord		*record;

	      for (i = 0; i < columns; i++)
		{
		  int	type = sqlite3_column_type(prepared, i);

		  switch (type)
		    {
		      case SQLITE_INTEGER:
			values[i] = [NSNumber numberWithInt:
			  sqlite3_column_int(prepared, i)];
			break;

		      case SQLITE_FLOAT:
			values[i] = [NSNumber numberWithDouble:
			  sqlite3_column_double(prepared, i)];
			break;

		      case SQLITE_TEXT:
			values[i] = [NSString stringWithUTF8String:
			  (char *)sqlite3_column_text(prepared, i)];
			break;

		      case SQLITE_BLOB:
			values[i] = [NSData dataWithBytes:
			  sqlite3_column_blob(prepared, i)
			  length: sqlite3_column_bytes(prepared, i)];
			break;

		      case SQLITE_NULL:
			values[i] = nil;
			break;
		    }
		}

	      record = [rtype newWithValues: values
				       keys: keys
				      count: columns];
	      [records addObject: record];
	      [record release];
	    }
	  while ((result = sqlite3_step(prepared)) == SQLITE_ROW);
        }
      if (result != SQLITE_DONE)
        {
	  [NSException raise: SQLException
		      format: @"%s", sqlite3_errmsg((sqlite3 *)extra)];
	}
      sqlite3_finalize(prepared);
    }
  NS_HANDLER
    {
      NSString	*n = [localException name];

      if ([n isEqual: SQLConnectionException] == YES) 
	{
	  [self disconnect];
	}
      if ([self debugging] > 0)
	{
	  [self debug: @"Error executing statement:\n%@\n%@",
	    stmt, localException];
	}
      [localException retain];
      [arp release];
      [localException autorelease];
      [localException raise];
    }
  NS_ENDHANDLER
  [arp release];
  return [records autorelease];
}

static char hex[16] = "0123456789ABCDEF";
- (unsigned) copyEscapedBLOB: (NSData*)blob into: (void*)buf
{
  const unsigned char	*bytes = [blob bytes];
  unsigned char		*ptr = buf;
  unsigned		length = [blob length];
  unsigned		i;

  *ptr++ = 'X';
  *ptr++ = '\'';
  for (i = 0; i < length; i++)
    {
      unsigned char     c = bytes[i];

      *ptr++ = hex[c / 16];
      *ptr++ = hex[c % 16];;
    }
  *ptr++ = '\'';
  return ((void*)ptr - buf);
}

- (unsigned) lengthOfEscapedBLOB: (NSData*)blob
{
  /*
   * A blob is X'xx' where xx is  hexadecimal encoded binary data ...
   * two hex digits per byte.
   */
  return 3 + [blob length] * 2;
}

- (NSString*) quote: (id)obj
{
  if ([obj isKindOfClass: [NSDate class]] == YES)
    {
      obj = [NSNumber numberWithDouble: [obj timeIntervalSinceReferenceDate]];
    }
  return [super quote: obj];
}

@end

#endif /* BUILD_SQLITE_BACKEND */
