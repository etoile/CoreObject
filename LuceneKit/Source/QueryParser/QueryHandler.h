/*
**  QueryHandler.h
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

#ifndef _QueryHandler_H_
#define _QueryHandler_H_

#include "TokenHandler.h"
#include "LCBooleanQuery.h"

typedef enum _TokenType {
	ReadyType = 0, /* Usually set when start or a query is finished */
	FieldType, /* field */
	TermType, /* single term */
	PhraseType, /* phrase with (") */
	ModifierType, /* +, -, ! */
	OperatorType, /* AND, OR, &&, || */
        SubqueryType
} TokenType;

@interface QueryHandler: TokenHandler <CodeHandler>
{
  int parenthesesCount;
  NSMutableString *queryString;
  LCQuery *currentQuery;
  LCOccurType occur;
  LCBooleanQuery *_query;
  NSString *defaultField;

  /* Reconstitue token */
  NSMutableString *_currentToken;
  NSString *field;
  TokenType currentType;
  BOOL inRange;
  
  /* Wildcard character set */
  NSCharacterSet *wildcardCharacterSet;
}

/* Override by subclass */

- (void) query: (LCQuery *) query;

- (LCQuery *) query;

- (void) setDefaultField: (NSString *) field;
- (NSString *) defaultField;

@end

#endif /* _QueryHandler_H_ */
