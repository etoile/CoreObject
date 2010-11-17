/*
**  TokenHandler.m
**
**  Copyright (c) 2003, 2004
**
**  Author: Yen-Ju  <yjchenx@hotmail.com>
**
**  This program is free software; you can redistribute it and/or modify
**  it under the terms of the GNU General Public License as published by
**  the Free Software Foundation; either version 2 of the License, or
**  (at your option) any later version.
**
**  This program is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
**  GNU General Public License for more details.
**
**  You should have received a copy of the GNU General Public License
**  along with this program; if not, write to the Free Software
**  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#include "TokenHandler.h"
#include "GNUstep.h"
#include <Foundation/Foundation.h>

@implementation TokenHandler

- (void) flushToken
{
  if ([_token length] > 0)
    {
      [self token: [_token copy]];
      [_token setString: @""];
    }
}

- (void) appendElement: (NSString *) element
{
  [_token appendString: element];
}

- (void) string: (NSString *) element
{
  [self appendElement: element];
  _preSymbol = 0;
}

- (void) number: (NSString *) element 
{
  [self appendElement: element];
  _preSymbol = 0;
}

- (void) spaceAndNewLine: (unichar) element 
{
  NSString *s = [NSString stringWithCharacters: &element length: 1];

  if (element == ' ')
    {
      if (_inQuotation) {
        [self appendElement: s];
      } else if ([_token length] > 0) {
        /* Send out token */
        [self token: [_token copy]];
        /* Reset token */
        [_token setString: @""];
      }
    }
  else
    {
      NSLog(@"Error: %@ is not allowed", s);
    }

  _preSymbol = 0;
}

/* Even in quotation, special symbol still need escaped characher '\' */
- (void) symbol: (unichar) element 
{
  NSString *s = [NSString stringWithCharacters: &element length: 1];

  if (_preSymbol == '\\')
    {
      [self appendElement: s];
      _preSymbol = 0;
      return;
    }

  switch(element) {
    case '+':
    case '-':
    case '!':
      //[self appendElement: s];
      [self flushToken];
      [self token: s];
      _preSymbol = 0;;
      break;
    case '&':
      if (_preSymbol == '&')
        {
          [self token: @"&&"];
          _preSymbol = 0;;
        }
      else 
        {
          _preSymbol = element;
        }
      break;
    case '|':
      if (_preSymbol == '|')
        {
          [self token: @"||"];
          _preSymbol = 0;;
        }
      else 
        {
          _preSymbol = element;
        }
      break;
    case '(':
    case ')':
    case '{':
    case '}':
    case '[':
    case ']':
      [self flushToken];
      [self token: s];
      _preSymbol = 0;
      break;
    case ':':
      [self appendElement: s];
      [self flushToken];
      break;
    case '"':
      if (_inQuotation)
        _inQuotation = NO;
      else
        _inQuotation = YES;
      [self appendElement: s];
      break;
    case '^':
    case '~':
    case '*':
    case '?':
      [self appendElement: s];
      _preSymbol = 0;
      break;
    case '\\':
      _preSymbol = element;
      break;
    default:
      /* Regular symbol */
      [self appendElement: s];
      _preSymbol = element;
  }
}

- (void) invisible: (unichar) element
{
}

- (void) beginParsing
{
}

- (void) endParsing
{
  // flush final token
  [self flushToken];
}

- (id) init
{
  self = [super init];
  _inQuotation = NO;
  _isEscaped = NO;
  _token = [[NSMutableString alloc] init];
  return self;
}

- (void) dealloc
{
  DESTROY(_token);
  [super dealloc];
}

- (void) token: (NSString *) token
{
  //NSLog(@"%@", token);
}

@end

