#include "LCFieldsReader.h"
#include "LCFieldsWriter.h"
#include "LCDirectory.h"
#include "LCIndexInput.h"
#include "NSData+Additions.h"
#include "GNUstep.h"

/**
* Class responsible for access to stored document fields.
 *
 * It uses &lt;segment&gt;.fdt and &lt;segment&gt;.fdx; files.
 *
 * @version $Id$
 */
@implementation LCFieldsReader

- (id) initWithDirectory: (id <LCDirectory>) d
				 segment: (NSString *) segment
			  fieldInfos: (LCFieldInfos *) fn
{
	self = [super init];
	ASSIGN(fieldInfos, fn);
	ASSIGN(fieldsStream, [d openInput: [segment stringByAppendingPathExtension: @"fdt"]]);
	ASSIGN(indexStream, [d openInput: [segment stringByAppendingPathExtension: @"fdx"]]);
	size = (int)([indexStream length]/8);
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

- (int) size
{
	return size;
}

- (LCDocument *) document: (int) n
{
	[indexStream seekToFileOffset: (n * 8L)];
	long position = [indexStream readLong];
	[fieldsStream seekToFileOffset: position];
	
	LCDocument *doc = [[LCDocument alloc] init];
	int numFields = [fieldsStream readVInt];
	int i, fieldNumber;
	for (i = 0; i < numFields; i++) 
    {
		fieldNumber = [fieldsStream readVInt];
		LCFieldInfo *fi = [fieldInfos fieldInfoWithNumber: fieldNumber];
		
		char bits = [fieldsStream readByte];
		
		BOOL compressed = (bits & LCFieldsWriter_FIELD_IS_COMPRESSED) != 0;
		BOOL tokenize = (bits & LCFieldsWriter_FIELD_IS_TOKENIZED) != 0;
		
		if ((bits & LCFieldsWriter_FIELD_IS_BINARY) != 0) {
			long len = [fieldsStream readVInt];
			NSMutableData *b = [[NSMutableData alloc] init];
			[fieldsStream readBytes: b offset: 0 length: len];
			if (compressed)
			{
				NSData *d = [b decompressedData];
				if (d)
				{
					LCField *field = [[LCField alloc] initWithName: [fi name]
															 data: d
															 store: LCStore_Compress];
					[doc addField: field];
					DESTROY(field);
				//doc.add(new Field(fi.name, uncompress(b), Field.Store.COMPRESS));
				}
			}
			else
			{
				LCField *field = [[LCField alloc] initWithName: [fi name]
														 data: AUTORELEASE([b copy])
														 store: LCStore_YES];
				[doc addField: field];
				DESTROY(field);
			}
			DESTROY(b);
		}
		else {
			LCIndex_Type index;
			LCStore_Type store = LCStore_YES;
			
			if ([fi isIndexed] && tokenize)
				index = LCIndex_Tokenized;
			else if ([fi isIndexed] && !tokenize)
				index = LCIndex_Untokenized;
			else
				index = LCIndex_NO;

	LCTermVector_Type termVector = LCTermVector_NO;
        if ([fi isTermVectorStored]) {
          if ([fi isOffsetWithTermVectorStored]) {
            if ([fi isPositionWithTermVectorStored]) {
              termVector = LCTermVector_WithPositionsAndOffsets;
            }                    
            else {        
              termVector = LCTermVector_WithOffsets;
            }
          }
          else if ([fi isPositionWithTermVectorStored]) {
            termVector = LCTermVector_WithPositions;
          }
          else {
            termVector = LCTermVector_YES;
          }
        }
        else {
          termVector = LCTermVector_NO;
        }
			
			if (compressed) {
				store = LCStore_Compress;
				int len = [fieldsStream readVInt];
				NSMutableData *b = [[NSMutableData alloc] init];
				[fieldsStream readBytes: b offset: 0 length: len];
				NSString *s = [[NSString alloc] initWithData: [b decompressedData] encoding: NSUTF8StringEncoding];
				LCField *field = [[LCField alloc] initWithName: [fi name]
														string: s
														 store: store
														 index: index
			termVector: termVector];
				[field setOmitNorms: [fi omitNorms]];

				[doc addField: field];
				DESTROY(field);
				DESTROY(s);
				DESTROY(b);
			}
			else // Not compressed
			{
				LCField *field = [[LCField alloc] initWithName: [fi name]
														string: [fieldsStream readString]
														 store: store
														 index: index
													termVector: termVector];
				[field setOmitNorms: [fi omitNorms]];
				[doc addField: field];
				DESTROY(field);
			}
		}
    }
    return AUTORELEASE(doc);
}

@end
