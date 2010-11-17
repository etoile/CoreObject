#include "LCFieldsWriter.h"
#include "LCIndexOutput.h"
#include "NSData+Additions.h"
#include "GNUstep.h"

@implementation LCFieldsWriter

- (id) initWithDirectory: (id <LCDirectory>) d
				 segment: (NSString *) segment
			  fieldInfos: (LCFieldInfos *) fn
{
	self = [self init];
	ASSIGN(fieldInfos, fn);
	NSString *f = [segment stringByAppendingPathExtension: @"fdt"];
	ASSIGN(fieldsStream, [d createOutput: f]);
	f = [segment stringByAppendingPathExtension: @"fdx"];
	ASSIGN(indexStream, [d createOutput: f]);
	return self;
}

- (void) dealloc
{
	DESTROY(fieldInfos);
	DESTROY(fieldsStream);
	DESTROY(indexStream);
	[super dealloc];
}

- (void) close
{
	[fieldsStream close];
	[indexStream close];
}

- (void) addDocument: (LCDocument *) doc
{
	[indexStream writeLong: [fieldsStream offsetInFile]];
	
	int storedCount = 0;
	NSEnumerator *fields = [doc fieldEnumerator];
	LCField *field;
	while ((field = [fields nextObject])) 
    {
		if ([field isStored])
			storedCount++;
    }
	[fieldsStream writeVInt: storedCount];
	
	fields = [doc fieldEnumerator];
	while ((field = [fields nextObject])) 
    {
		if([field isStored]){
			[fieldsStream writeVInt: [fieldInfos fieldNumber: [field name]]];
			
			char bits = 0;
			if ([field isTokenized])
				bits |= LCFieldsWriter_FIELD_IS_TOKENIZED;
			if ([field isData])
				bits |= LCFieldsWriter_FIELD_IS_BINARY;
			if ([field isCompressed])
				bits |= LCFieldsWriter_FIELD_IS_COMPRESSED;
			
			[fieldsStream writeByte: bits];
			if ([field isCompressed]) {
				// compression is enabled for the current field
				NSData *data = nil;
				// check if it is a binary field
				if ([field isData]) {
                    ASSIGN(data, [field data]);
				}
				else {
					ASSIGN(data, [[field string] dataUsingEncoding: NSUTF8StringEncoding]);
				}
				ASSIGN(data, [data compressedData]);
				int len = [data length];
				[fieldsStream writeVInt: len];
				[fieldsStream writeBytes: data length: len];
				DESTROY(data);
			} else {
				// compression is disabled for the current field
				if ([field isData]) {
					NSData *data = [field data];
                    int len = [data length];
					[fieldsStream writeVInt: len];
					[fieldsStream writeBytes: data length: len];
				}
				else {
					[fieldsStream writeString: [field string]];
				}
			}
		}
	}
}

@end
