/*
        TestUTI.m
        
        Copyright (C) 2009 Eric Wasylishen
 
        Author:  Eric Wasylishen <ewasylishen@gmail.com>
        Date:  February 2009
 
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

#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "Macros.h"
#import "ETUTI.h"


@interface TestUTI: NSObject <UKTest>
@end

@implementation TestUTI

- (void) testBasic
{
	id text = [ETUTI typeWithString: @"public.text"];
	id data = [ETUTI typeWithString: @"public.data"];

	UKNotNil(text);
	UKNotNil(data);
	UKStringsEqual(@"public.text", [text stringValue]);
	
}

- (void) testSuperAndSubclassTypes
{
	id stringType = [ETUTI typeWithClass: [NSString class]];
	id objectType = [ETUTI typeWithClass: [NSObject class]];
	id mutableArrayType = [ETUTI typeWithClass: [NSMutableArray class]];
	id arrayType = [ETUTI typeWithClass: [NSArray class]];

	UKTrue([stringType conformsToType: objectType]);
	UKFalse([[objectType subtypes] containsObject: mutableArrayType]);
	UKTrue([[objectType allSubtypes] containsObject: mutableArrayType]);
	UKFalse([[mutableArrayType supertypes] containsObject: objectType]);
	UKTrue([[mutableArrayType supertypes] containsObject: arrayType]);
	UKFalse([[mutableArrayType supertypes] containsObject: objectType]);
	UKTrue([[mutableArrayType allSupertypes] containsObject: objectType]);
}

- (void) testExtensions
{
	id jpeg = [ETUTI typeWithString: @"public.jpeg"];
	UKTrue([[jpeg fileExtensions] containsObject: @"jpg"]);
}

- (void) testRegister
{
	id item = [ETUTI typeWithString: @"public.item"];
	id image = [ETUTI typeWithString: @"public.image"];
	id audio = [ETUTI typeWithString: @"public.audio"];

	id new = [ETUTI registerTypeWithString: @"etoile.testtype"
	                           description: @"Testing type."
	                      supertypeStrings: A(@"public.composite-content", @"public.jpeg")
	                              typeTags: nil];
	
	UKNotNil(new);
	UKStringsEqual(@"Testing type.", [new typeDescription]);
	UKTrue([new conformsToType: item]);
	UKTrue([new conformsToType: image]);
	UKFalse([new conformsToType: audio]);
	UKTrue([new conformsToType: item]);

	UKTrue([[new allSupertypes] containsObject: item]);
	UKTrue([[item allSubtypes] containsObject: new]);
}

- (void) testTransient
{
	id item = [ETUTI typeWithString: @"public.item"];
	id image = [ETUTI typeWithString: @"public.image"];
	id audio = [ETUTI typeWithString: @"public.audio"];

	id new = [ETUTI transientTypeWithSupertypeStrings: A(@"public.composite-content", @"public.jpeg")];
	
	UKNotNil(new);
	UKTrue([new conformsToType: item]);
	UKTrue([new conformsToType: image]);
	UKFalse([new conformsToType: audio]);
	UKTrue([new conformsToType: item]);

	UKTrue([[new allSupertypes] containsObject: item]);
	UKFalse([[item allSubtypes] containsObject: new]);	// Note the expected result
}

- (void) testClassBinding
{
	UKTrue([[ETUTI typeWithClass: [NSString class]] conformsToType:
			[ETUTI typeWithString: @"public.text"]]);
	UKTrue([[ETUTI typeWithClass: [NSMutableString class]] conformsToType:
			[ETUTI typeWithString: @"public.text"]]);
}

- (void) testClassValue
{
	UKNil([[ETUTI typeWithString: @"public.text"] classValue]);
	UKObjectsEqual([self class], [[ETUTI typeWithClass: [self class]] classValue]);
}

@end
