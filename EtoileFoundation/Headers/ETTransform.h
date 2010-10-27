/*
	ETTransform.h
	
	Description forthcoming.
 
	Copyright (C) 2007 Quentin Mathe
 
	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  November 2007
 
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
 
#import <EtoileFoundation/ETFilter.h>

/** ETTransform provides a visitor which supports double-dispatch on all
	visited objects without implementing extra methods. Any visited objects 
	can implement -renderOn: to override this double-dispatch provided by 
	ETTransform for free. 
	You can also use this class as a mixin to quickly implement visitor 
	pattern. 
	In addition to that, ETTransform by being a subclass of ETFilter provides
	the possibility to combine several transforms together in a chain. An 
	instance behave then like a transform unit where each transform in the 
	chain is rendered sequentially. A typical use would be implementing a tree 
	transformation chain as commonly done on AST. EtoileUI uses this exact 
	model in a recurrent manner to implement stuff like:
	- AppKit compatibility (building a layout item tree from AppKit window, 
	  view, menu etc.)
	- layout item tree rendering with AppKit as backend
	- UI generation from a model object graph
	- UI generation from a data format
	- UI transformation (UI generation from an existing UI)
	- data format reading, writing, converting and processing
	- composite document format
	In future, we plan to explore with this architecture:
	- synchronization of various concrete UIs derivated from a shared abstract 
	  UI (which is used as a metamodel)

	Because ETTransform and ETFilter shares a common underlying API, you can 
	create hybrid processing chain. In fact, any classes implementing 
	ETRendering protocol can be inserted in such processing chain. */

@interface ETTransform : ETFilter
{

}

- (id) tryToPerformSelector: (SEL)selector withObject: (id)object result: (BOOL *)performed;
- (id) render: (id)object;

@end
