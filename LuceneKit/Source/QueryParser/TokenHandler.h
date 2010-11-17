/*
**  TokenHandler.h
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

#ifndef _TokenHandler_H_
#define _TokenHandler_H_

#include "CodeHandler.h"
#include <Foundation/Foundation.h>

@interface TokenHandler: NSObject <CodeHandler>
{
  NSMutableString *_token;
  BOOL _inQuotation;
  BOOL _isEscaped;
  unichar _preSymbol;
}

// Override by subclass

- (void) token: (NSString *) token;

@end

#endif /* _TokenHandler_H_ */
