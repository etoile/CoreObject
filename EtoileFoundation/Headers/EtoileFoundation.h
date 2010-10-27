/*
	EtoileFoundation.h

	EtoileFoundation umbrella header

	Copyright (C) 2007 David Chisnall

	Author:  David Chisnall <csdavec@swan.ac.uk>
	Date:  September 2007

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

/* EtoileFoundation core */

#import <EtoileFoundation/ETByteSizeFormatter.h>
#import <EtoileFoundation/ETCollection.h>
#import <EtoileFoundation/ETCollection+HOM.h>
#import <EtoileFoundation/ETFilter.h>
#import <EtoileFoundation/ETGetOptionsDictionary.h>
#import <EtoileFoundation/ETHistory.h>
#import <EtoileFoundation/ETObjectChain.h>
#import <EtoileFoundation/ETPropertyValueCoding.h>
#import <EtoileFoundation/ETPropertyViewpoint.h>
#import <EtoileFoundation/ETRendering.h>
#import <EtoileFoundation/ETReflection.h>
#import <EtoileFoundation/ETSocket.h>
#import <EtoileFoundation/ETStackTraceRecorder.h>
#import <EtoileFoundation/ETTransform.h>
#import <EtoileFoundation/ETUTI.h>
#import <EtoileFoundation/ETUUID.h>
#import <EtoileFoundation/EtoileCompatibility.h>
#import <EtoileFoundation/Macros.h>
#import <EtoileFoundation/NSData+Hash.h>
#import <EtoileFoundation/NSFileManager+NameForTempFile.h>
#import <EtoileFoundation/NSFileManager+TempFile.h>
#import <EtoileFoundation/NSFileHandle+Socket.h>
#import <EtoileFoundation/NSIndexPath+Etoile.h>
#import <EtoileFoundation/NSIndexSet+Etoile.h>
#import <EtoileFoundation/NSInvocation+Etoile.h>
#import <EtoileFoundation/NSObject+Etoile.h>
#import <EtoileFoundation/NSObject+HOM.h>
#import <EtoileFoundation/NSObject+Model.h>
#import <EtoileFoundation/NSString+Etoile.h>
#import <EtoileFoundation/NSURL+Etoile.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import <EtoileFoundation/ETModelElementDescription.h>
#import <EtoileFoundation/ETEntityDescription.h>
#import <EtoileFoundation/ETPackageDescription.h>
#import <EtoileFoundation/ETPropertyDescription.h>
#import <EtoileFoundation/ETValidationResult.h>

#ifdef GNUSTEP

#import <EtoileFoundation/ETCArray.h>
#import <EtoileFoundation/NSObject+Mixins.h>
#import <EtoileFoundation/NSObject+Prototypes.h>

/* EtoileFoundation subframeworks */

#import <EtoileThread/ETThread.h>
#import <EtoileThread/ETThreadedObject.h>
#import <EtoileThread/ETThreadProxyReturn.h>
#import <EtoileThread/NSObject+Futures.h>
#import <EtoileThread/NSObject+Threaded.h>

#endif

#import <EtoileXML/ETXMLDeclaration.h>
#import <EtoileXML/ETXMLNullHandler.h>
#import <EtoileXML/ETXMLParserDelegate.h>
#import <EtoileXML/ETXMLParser.h>
#import <EtoileXML/ETXMLString.h>
#import <EtoileXML/ETXMLWriter.h>
#import <EtoileXML/ETXMLXHTML-IMParser.h>
#import <EtoileXML/NSAttributedString+HTML.h>
