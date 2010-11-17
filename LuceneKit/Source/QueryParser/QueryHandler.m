/*
 **  QueryHandler.m
 **
 **  Copyright (c) 2003, 2004, 2005
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

#include "CodeParser.h"
#include "QueryHandler.h"
#include "GNUstep.h"
#include "LCMetadataAttribute.h"
#include "LCTermQuery.h"
#include "LCPrefixQuery.h"
#include "LCWildcardQuery.h"
#include <Foundation/Foundation.h>

@implementation QueryHandler

- (void) flushQuery
{
	/* Flush query */
	if (currentQuery)
    {
		[self query: currentQuery];
		DESTROY(currentQuery);
    }
	[queryString setString: @""];
}

#define STRING_EQUAL(b) \
([token isEqualToString: b])

- (void) token: (NSString *) token
{
	if STRING_EQUAL(@"(")
    {
		if (parenthesesCount == 0)
			[self flushQuery];
		else
        {
			[queryString appendFormat: @"%@ ", token];
        }
		parenthesesCount++;
		currentType = SubqueryType;
		return;
    }
	else if STRING_EQUAL(@")")
    {
		parenthesesCount--;
		if (parenthesesCount == 0)
        {
			/* Parse again */
			QueryHandler *handler = [[QueryHandler alloc] init];
			CodeParser *parser = [[CodeParser alloc] initWithCodeHandler: handler withString: [queryString copy]];
			/* Propogate the default field */
			[handler setDefaultField: defaultField];
			[parser parse];
			[_query addQuery: [handler query] occur: occur];
			[queryString setString: @""];
			currentType = ReadyType;
                        DESTROY(handler);
                        DESTROY(parser);
        }
		else
        {
			[queryString appendFormat: @"%@ ", token];
        }
		return;
    }
	else if (parenthesesCount > 0)
    {
		[queryString appendFormat: @"%@ ", token];
		return;
    }
	
	if (STRING_EQUAL(@"[") || STRING_EQUAL(@"{"))
    {
		inRange = YES;
    }
	else if (STRING_EQUAL(@"]") || STRING_EQUAL(@"}"))
    {
		inRange = NO;
    }
	else if STRING_EQUAL(@"+")
    {
		currentType = ModifierType;
		occur = LCOccur_MUST;
    }
	else if STRING_EQUAL(@"-")
    {
		currentType = ModifierType;
		occur = LCOccur_MUST_NOT;
    }
	else if (STRING_EQUAL(@"AND") ||
			 STRING_EQUAL(@"&&"))
    {
		/* Modified current token to be MUST and flush it out*/
		[[[_query clauses] lastObject] setOccur: LCOccur_MUST];;
		occur = LCOccur_MUST; /* for next token */
    }
	else if STRING_EQUAL(@"NOT")
    {
		/* Flush out */
		[self flushQuery];
		//[self query: currentQuery];
		occur = LCOccur_MUST_NOT; /* for next token */
    }
	else if (STRING_EQUAL(@"OR") ||
			 STRING_EQUAL(@"||"))
    {
		occur = LCOccur_SHOULD; /* for next token */
    }
	else
    {
		if ([token hasSuffix: @":"])
        {
			/* field */
			ASSIGNCOPY(field, [token substringToIndex: [token length]-1]);
        }
		else if (inRange)
        {
        }
		else
        {
			NSString *f;
			LCTerm *term;
			LCQuery *q;
			if (field)
            {
				f = field;
            }
			else
            {
				/* Default field */
				f = defaultField;
            }
			
			if ([token rangeOfCharacterFromSet: wildcardCharacterSet].location != NSNotFound)
			{
				/* Wildcard Query */
				term = [[LCTerm alloc] initWithField: f text: token];
				q = [[LCWildcardQuery alloc] initWithTerm: term];
				/* Disable coordination for wildcard */
				[_query setCoordinationDisabled: YES];
			}
			else
            { 
				/* Term Query */
				term = [[LCTerm alloc] initWithField: f text: token];
				q = [[LCTermQuery alloc] initWithTerm: term];
            }
			ASSIGN(currentQuery, q);
			DESTROY(term);
			DESTROY(q);
			
			[self flushQuery];
			
			/* Fall back to SHOULD */
			if ((occur == LCOccur_MUST) ||
				(occur == LCOccur_SHOULD))
            {
				occur = LCOccur_SHOULD;
            }
        }
    }
	[queryString appendString: token];
	[queryString appendString: @" "];
}

- (void) endParsing 
{ 
	[super endParsing]; 
	[self flushQuery];
}

- (LCQuery *) query
{
	return _query;
}

- (id) init
{
	self = [super init];
	parenthesesCount = 0;
	queryString = [[NSMutableString alloc] init];
	_query = [[LCBooleanQuery alloc] init];
	currentType = ReadyType;
	occur = LCOccur_SHOULD;
	inRange = NO;
	ASSIGN(defaultField, [NSString stringWithString: LCTextContentAttribute]);
	
	ASSIGN(wildcardCharacterSet, [NSCharacterSet characterSetWithCharactersInString: @"*?"]);
	
	return self;
}

- (void) dealloc
{
	DESTROY(queryString);
	DESTROY(_currentToken);
        DESTROY(_query);
        DESTROY(defaultField);
        DESTROY(wildcardCharacterSet);
	[super dealloc];
}

- (void) query: (LCQuery *) q
{
	[_query addQuery: q occur: occur]; 
}

- (void) setDefaultField: (NSString *) f
{
	ASSIGN(defaultField, f);
}

- (NSString *) defaultField
{
	return defaultField;
}

/* Called by CodeParser */
- (void) beginParsing { [super beginParsing]; }
- (void) string: (NSString *) element { [super string: element]; }
- (void) number: (NSString *) element { [super number: element]; }
- (void) spaceAndNewLine: (unichar) element { [super spaceAndNewLine: element]; }
- (void) symbol: (unichar) element { [super symbol: element]; }
- (void) invisible: (unichar) element { [super invisible: element]; }

@end

