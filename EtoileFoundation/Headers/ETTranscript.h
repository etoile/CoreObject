/*
	ETTranscript.h
	
	A Smalltalk-80 like Transcript implementation.
 
	Copyright (C) 2007 Günther Noack
 
	Author:  Günther Noack <guenther@unix-ag.uni-kl.de>
	Date:  November 2008
 
	Redistribution and use in source and binary forms, with or without
	modification, are permitted provided that the following conditions are met:

	* Redistributions of source code must retain the above copyright notice,
	  this list of conditions and the following disclaimer.
	* Redistributions in binary form must reproduce the above copyright notice,
	  this list of conditions and the following disclaimer in the documentation
	  and/or other materials provided with the distribution.
	* Neither the name of the Etoile project nor the names of its contributors
	  may be used to endorse or promote products derived from this software
	  without specific prior written permission.

	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
	AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
	IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
	ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
	LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
	CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
	SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
	INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
	CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
	THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import "Macros.h"

/**
 * Key used to identify the transcript delegate for this thread.
 */
EMIT_STRING(kTranscriptDelegate);
/**
 * Protocol for transcript delegates.  Store an object implementing the methods
 * in this protocol in the thread's dictionary with the kTranscriptDelegate key
 * and transcript messages will be sent to it instead of the standard output.
 */
@protocol ETTranscriptDelegate
/**
 * Append the string to the transcript.
 */
- (void)appendTranscriptString: (NSString*)aString;
@end

/**
 * A simple logging class designed for compatibility with
 * Smalltalkers' expectations.
 *
 * In the future, it may become possible to change the
 * standard transcripts destination. ETTranscript will
 * then take the role of an additional level of indirection.
 */
@interface ETTranscript : NSObject
/**
 * Writes the object's description to the standard transcript.
 */
+ (void) show: (NSObject*) anObject;

/**
 * Writes the given string to the standard transcript.
 */
+ (void) appendString: (NSString*) aString;

/**
 * Writes a carriage return to the standard transcript.
 */
+ (void) cr;
@end

