/*
	Copyright (C) 2013 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  May 2013
	License:  Modified BSD  (see COPYING)

 */

#import "COCommitDescriptor.h"

@implementation COCommitDescriptor

@synthesize identifier = _identifier, typeDescription = _typeDescription, shortDescription = _shortDescription;

static NSMutableDictionary *descriptorTable = nil;

+ (void) initialize
{
	if (self != [COCommitDescriptor class])
		return;

	descriptorTable = [NSMutableDictionary new];
}

+ (void) registerDescriptor: (COCommitDescriptor *)aDescriptor
                   inDomain: (NSString *)aDomain
{
	NILARG_EXCEPTION_TEST(aDescriptor);
	NILARG_EXCEPTION_TEST(aDomain);

	NSString *key = [NSString stringWithFormat: @"%@-%@", aDomain, [aDescriptor identifier]];

	[descriptorTable setObject: aDescriptor forKey: key];
}

+ (COCommitDescriptor *) registeredDescriptorForIdentifier: (NSString *)anIdentifier
                                                  inDomain: (NSString *)aDomain
{
	NILARG_EXCEPTION_TEST(anIdentifier);
	NILARG_EXCEPTION_TEST(aDomain);
	NSString *key = [NSString stringWithFormat: @"%@-%@", aDomain, anIdentifier];

	return [descriptorTable objectForKey: key];
}

- (void) setTypeDescription: (NSString *)aDescription
{
	NILARG_EXCEPTION_TEST(aDescription);
	_typeDescription =  aDescription;
}

- (NSString *)localizedTypeDescription
{
	NSString *localizationKey =
		[kCOCommitMetadataTypeDescription stringByAppendingString: @"TypeDescription"];
	return NSLocalizedString(localizationKey, [self typeDescription]);
}

- (void) setShortDescription: (NSString *)aDescription
{
	NILARG_EXCEPTION_TEST(aDescription);
	_shortDescription =  aDescription;
}

- (NSString *)localizedShortDescription
{
	NSString *localizationKey =
		[kCOCommitMetadataTypeDescription stringByAppendingString: @"ShortDescription"];
	return NSLocalizedString(localizationKey, [self shortDescription]);
}

- (NSDictionary *)persistentMetadata
{
	return D([self identifier], kCOCommitMetadataIdentifier,
	         [self typeDescription], kCOCommitMetadataTypeDescription,
	         [self shortDescription], kCOCommitMetadataShortDescription);
}

@end

NSString *kCOCommitMetadataIdentifier = @"kCOCommitMetadataIdentifier";
NSString *kCOCommitMetadataTypeDescription = @"kCOCommitMetadataTypeDescription";
NSString *kCOCommitMetadataShortDescription = @"kCOCommitMetadataShortDescription";
