#include "LCWordlistLoader.h"
#include "GNUstep.h"

/**
* Loader for text files that represent a list of stopwords.
 *
 * @author Gerhard Schwarz
 * @version $Id$
 */
@interface LCWordlistLoader (LCPrivate)
+ (NSDictionary *) makeWordTable: (NSSet *) wordSet;
@end

@implementation LCWordlistLoader

/**
* Loads a text file and adds every line as an entry to a HashSet (omitting
																  * leading and trailing whitespace). Every line of the file should contain only 
 * one word. The words need to be in lowercase if you make use of an
 * Analyzer which uses LowerCaseFilter (like GermanAnalyzer).
 * 
 * @param wordfile File containing the wordlist
 * @return A HashSet with the file's words
 */
+ (NSSet*) getWordSet: (NSString *) path 
{
	NSMutableSet *result = [[NSMutableSet alloc] init];
	AUTORELEASE(result);
	
	NSString *s = [NSString stringWithContentsOfFile: path];
	//  NSString *word;
	if (s == nil) return nil; 
	NSArray *a = [s componentsSeparatedByString: @"\n"];
	int i, count = [a count];
	for(i = 0; i < count; i++)
	{
		[result addObject: [[a objectAtIndex: i] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]]];
	}
	return result;
}

/**
* Builds a wordlist table, using words as both keys and values
 * for backward compatibility.
 *
 * @param wordSet   stopword set
 */
+ (NSDictionary *) makeWordTable: (NSSet *) wordSet
{
	NSMutableDictionary *table = [[NSMutableDictionary alloc] init];
	NSEnumerator *e = [wordSet objectEnumerator];
	NSString *word;
	while ((word = [e nextObject]))
    {
		[table setObject: word forKey: word];
    }
	return AUTORELEASE(table);
}

@end
