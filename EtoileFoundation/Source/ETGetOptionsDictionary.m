#import <Foundation/Foundation.h>
#include <string.h>
#include "glibc_hack_unistd.h"

NSDictionary *ETGetOptionsDictionary(char *optString, int argc, char **argv)
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	NSNumber *True = [NSNumber numberWithBool: YES];
	NSNumber *False = [NSNumber numberWithBool: NO];

	for (char *opts = optString ; '\0' != *opts ; opts++)
	{
		// Initialise options to False.
		if ((*opts != ':') && (*(opts + 1) != ':' ))
		{
			unichar opt = (unichar)*opts;
			NSString *key = [NSString stringWithCharacters: &opt length: 1];
			[dict setObject: False
			         forKey: key];
		}
	}

	int ch;
	while ((ch = getopt(argc, argv, optString)) != -1)
	{
		if (ch == '?')
		{
			[NSException raise: @"InvalidOption"
			            format: @"Illegal argument %c", optopt];
		}
		unichar optchar = ch;
		NSString *key = [NSString stringWithCharacters: &optchar length: 1];
		char *opt = strchr(optString, (char)ch);
		if (*(opt+1) == ':')
		{
			[dict setObject: [NSString stringWithUTF8String: optarg]
			         forKey: key];
		}
		else
		{
			[dict setObject: True
			         forKey: key];
		}
	}
	return dict;
}
