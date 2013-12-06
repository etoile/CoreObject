#import "COItem+Binary.h"
#import "COBinaryWriter.h"
#import "COBinaryReader.h"
#import "COPath.h"
#import "COAttachmentID.h"
#import <EtoileFoundation/Macros.h>

typedef enum {
    co_reader_expect_object_uuid,
    co_reader_expect_property,
    co_reader_expect_type,
    co_reader_expect_value,
    co_reader_error
} reader_state;

@interface COReaderState : NSObject
{
@public
    ETUUID *uuid;
    NSMutableDictionary *values;
    NSMutableDictionary *types;
    NSString *currentProperty;
    COType currentType;
    BOOL isReadingMultivalue;
    id multivalue;
    reader_state state;
}
@end

@implementation COReaderState

- (id) init
{
    SUPERINIT;
    values = [[NSMutableDictionary alloc] init];
    types = [[NSMutableDictionary alloc] init];
    state = co_reader_expect_object_uuid;
    return self;
}


@end

@implementation COItem (Binary)


static NSNull *NSNullCached;

+ (void) initialize
{
    if (self == [COItem class])
    {
        NSNullCached = [NSNull null];
    }
}

static void writePrimitiveValue(co_buffer_t *dest, id aValue, COType aType)
{
    if (aValue == NSNullCached)
    {
        co_buffer_store_null(dest);
        return;
    }
    
    switch (COTypePrimitivePart(aType))
    {
        case kCOTypeInt64:
            co_buffer_store_integer(dest, [aValue longLongValue]);
            break;
        case kCOTypeDouble:
            co_buffer_store_double(dest, [aValue doubleValue]);
            break;
        case kCOTypeString:
            co_buffer_store_string(dest, aValue);
            break;
        case kCOTypeBlob:
            co_buffer_store_bytes(dest, [aValue bytes], [aValue length]);
            break;
        case kCOTypeCompositeReference:
            co_buffer_store_uuid(dest, aValue);
            break;
        case kCOTypeReference:
            if ([aValue isKindOfClass: [COPath class]])
            {
                co_buffer_store_string(dest, [(COPath *)aValue stringValue]);
            }
            else
            {
                co_buffer_store_uuid(dest, aValue);
            }
            break;
        case kCOTypeAttachment:
            co_buffer_store_bytes(dest, [[aValue dataValue] bytes], [[aValue dataValue] length]);
            break;
        default:
            [NSException raise: NSInvalidArgumentException format: @"unknown type %d", aType];
    }
}

/**
 * Returns an integer less than, equal to, or greater than one if
 * the bytes pointed to by tokenA are considered less than, equal to, or greater than
 * the bytes pointed to by tokenB.
 */
static int comparePointersToBinaryWriterTokens(const void *ptrA, const void *ptrB)
{
	const unsigned char **tokenA = (const unsigned char **)ptrA;
	const unsigned char **tokenB = (const unsigned char **)ptrB;
	
	size_t tokenALength = co_reader_length_of_token(*tokenA);
	size_t tokenBLength = co_reader_length_of_token(*tokenB);
	assert(tokenALength > 0 && tokenBLength > 0);

	if (tokenALength < tokenBLength)
	{
		return -1;
	}
	else if (tokenALength == tokenBLength)
	{
		/*
		 From RFC 3629 (UTF-8):
		 
		 The byte-value lexicographic sorting order of UTF-8 strings is the
		 same as if ordered by character numbers.  Of course this is of
		 limited interest since a sort order based on character numbers is
		 almost never culturally valid.
		 */
		return memcmp(*tokenA, *tokenB, tokenALength);
	}
	else
	{
		return 1;
	}
}

static void writeValue(co_buffer_t *dest, id aValue, COType aType, co_buffer_t *temp)
{
    if (COTypeIsPrimitive(aType))
    {
        return writePrimitiveValue(dest, aValue, aType);
    }
    else
    {
        co_buffer_begin_array(dest);
				
		if ([aValue isKindOfClass: [NSArray class]])
		{
			for (id obj in aValue)
			{
				writePrimitiveValue(dest, obj, aType);
			}
		}
		else if ([aValue isKindOfClass: [NSSet class]])
		{
			const size_t setCount = [aValue count];
			
			// We need to sort the serialized values since NSSet has no order.
			
			co_buffer_clear(temp);

			const unsigned char **tokenPointers = malloc(sizeof(const unsigned char *) * setCount);
			
			// First, write each primitive value to the temporary byte buffer 'temp',
			// also storing the pointer to the start of each token in the tokenPointers array
			{
				size_t i = 0;
				for (id obj in aValue)
				{
					tokenPointers[i++] = co_buffer_get_data(temp) + co_buffer_get_length(temp);
					
					writePrimitiveValue(temp, obj, aType);
				}
			}
			
			// Sort the tokenPointers using a simple comparison function that
			// uses the length of the token and the byte-for-byte values of the tokens
			
			qsort(tokenPointers, setCount, sizeof(const unsigned char *), comparePointersToBinaryWriterTokens);
			
			// Copy the sorted tokens into the dest buffer
			
			for (size_t i=0; i<setCount; i++)
			{
				const unsigned char *tokenPointer = tokenPointers[i];
				const size_t tokenLength = co_reader_length_of_token(tokenPointer);
				
				co_buffer_write(dest, tokenPointer, tokenLength);
			}
			
			free(tokenPointers);
		}
		else
		{
			assert(0);
		}
		
        co_buffer_end_array(dest);
    }
}

- (NSData *) dataValue
{
	/** Parts of the serialization process need temporary storage */
	co_buffer_t temp;
	co_buffer_init(&temp);
	
    co_buffer_t buf;
    co_buffer_init(&buf);
    co_buffer_store_uuid(&buf, [self UUID]);
    co_buffer_begin_object(&buf);
    
	// TODO: For safety we should probaly serialize the attribute names to UTF-8 and compare
	// them there. Although, I believe compare: should be the same as comparing Unicode character numbers
	// which is the same as comparing UTF-8 byte sequences (mentiomed in the RFC.)
	NSArray *propsSorted = [[self attributeNames] sortedArrayUsingSelector: @selector(compare:)];
	
    for (NSString *prop in propsSorted)
    {
        COType type = [self typeForAttribute: prop];
        id val = [self valueForAttribute: prop];
        
        co_buffer_store_string(&buf, prop);
        co_buffer_store_integer(&buf, type);
        writeValue(&buf, val, type, &temp);
    }

    co_buffer_end_object(&buf);

    NSData *result = [NSData dataWithBytes:co_buffer_get_data(&buf)
                                    length:co_buffer_get_length(&buf)];
    co_buffer_free(&buf);
    return result;
}


// Read

static void co_read_object_value(COReaderState *state, id obj) {
    if (state->isReadingMultivalue)
    {
        [state->multivalue addObject: obj];
    }
    else
    {
        [state->values setObject: obj
                          forKey: state->currentProperty];
        state->state = co_reader_expect_property;
    }
}


static void co_read_int64(void *ctx, int64_t val)
{
    COReaderState *state = (__bridge COReaderState *)ctx;
    switch (state->state)
    {
        case co_reader_expect_value:
            co_read_object_value(state, [NSNumber numberWithLongLong: val]);
            break;
        case co_reader_expect_type:
            state->currentType = (COType)val;
            [state->types setObject: [NSNumber numberWithLongLong: val]
                             forKey: state->currentProperty];
            state->state = co_reader_expect_value;
            break;
        default:
            state->state = co_reader_error;
            break;
    }
}
static void co_read_double(void *ctx, double val)
{
    COReaderState *state = (__bridge COReaderState *)ctx;
    switch (state->state)
    {
        case co_reader_expect_value:
            co_read_object_value(state, [NSNumber numberWithDouble: val]);
            break;
        default:
            state->state = co_reader_error;
            break;
    }
}

static void co_read_string(void *ctx, NSString *val)
{
    COReaderState *state = (__bridge COReaderState *)ctx;
    switch (state->state)
    {
        case co_reader_expect_value:
            if (COTypePrimitivePart(state->currentType) == kCOTypeReference)
            {
                co_read_object_value(state, [COPath pathWithString: val]);
            }
            else if (COTypePrimitivePart(state->currentType) == kCOTypeString)
            {
                co_read_object_value(state, val);
            }
            else
            {
                state->state = co_reader_error;
            }
            break;
        case co_reader_expect_property:
            state->currentProperty =  val;
            state->state = co_reader_expect_type;
            break;
        default:
            state->state = co_reader_error;
            break;
    }
}

static void co_read_uuid(void *ctx, ETUUID *uuid)
{
    COReaderState *state = (__bridge COReaderState *)ctx;
    switch (state->state)
    {
        case co_reader_expect_value:
            co_read_object_value(state, uuid);
            break;
        case co_reader_expect_object_uuid:
            state->uuid =  uuid;
            state->state = co_reader_expect_property;
            break;
        default:
            state->state = co_reader_error;
            break;
    }
}

static void co_read_bytes(void *ctx, const unsigned char *val, size_t size)
{
    COReaderState *state = (__bridge COReaderState *)ctx;
    switch (state->state)
    {
        case co_reader_expect_value:
		{
			NSData *data = [NSData dataWithBytes: val length: size];
			if (COTypePrimitivePart(state->currentType) == kCOTypeAttachment)
            {
				co_read_object_value(state, [[COAttachmentID alloc] initWithData: data]);
			}
			else
			{
				co_read_object_value(state, data);
			}
            break;
		}
        default:
            state->state = co_reader_error;
            break;
    }
}

static void co_read_begin_object(void *ctx)
{
}
static void co_read_end_object(void *ctx)
{
}

static void co_read_begin_array(void *ctx)
{
    COReaderState *state = (__bridge COReaderState *)ctx;
    state->isReadingMultivalue = YES;
    
    assert(COTypeIsMultivalued(state->currentType));
    
    if (COTypeIsOrdered(state->currentType))
    {
        state->multivalue = [[NSMutableArray alloc] init];
    }
    else
    {
        state->multivalue = [[NSMutableSet alloc] init];
    }
}
static void co_read_end_array(void *ctx)
{
    COReaderState *state = (__bridge COReaderState *)ctx;
    state->isReadingMultivalue = NO;
    
    // Save the value
    [state->values setObject: state->multivalue
                      forKey: state->currentProperty];
    state->multivalue =  nil;
    
    // Do state transition
    state->state = co_reader_expect_property;
}
static void co_read_null(void *ctx)
{
    COReaderState *state = (__bridge COReaderState *)ctx;
    switch (state->state)
    {
        case co_reader_expect_value:
            co_read_object_value(state, NSNullCached);
            break;            
        default:
            state->state = co_reader_error;
            break;
    }
}

- (id) initWithData: (NSData *)aData
{
    COReaderState *state = [[COReaderState alloc] init];
    
    co_reader_callback_t cb = {
        co_read_int64,
        co_read_double,
        co_read_string,
        co_read_uuid,
        co_read_bytes,
        co_read_begin_object,
        co_read_end_object,
        co_read_begin_array,
        co_read_end_array,
        co_read_null
    };
    co_reader_read([aData bytes],
                   [aData length],
                   (__bridge void *)state,
                   cb);
    
    SUPERINIT;
    uuid =  state->uuid;
    types =  state->types;
    values =  state->values;
    
    return self;
}

@end

