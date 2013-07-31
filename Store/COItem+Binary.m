#import "COItem+Binary.h"
#import "COBinaryWriter.h"
#import "COBinaryReader.h"
#import "COPath.h"
#import <EtoileFoundation/Macros.h>

typedef enum {
    co_reader_expect_object_uuid,
    co_reader_expect_object_schemaname,
    co_reader_expect_property,
    co_reader_expect_type,
    co_reader_expect_value,
    co_reader_error
} reader_state;

@interface COReaderState : NSObject
{
@public
    ETUUID *uuid;
    NSString *schemaName;
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

- (void) dealloc
{
    [uuid release];
    [values release];
    [types release];
    [currentProperty release];
    [super dealloc];
}

@end

@implementation COItem (Binary)


static NSNull *NSNullCached;

+ (void) initialize
{
    if (self == [COItem class])
    {
        NSNullCached = [[NSNull null] retain];
    }
}

static void writePrimitiveValue(co_buffer_t *dest, id aValue, COType aType)
{
    if (aValue == NSNullCached)
    {
        co_buffer_store_null(dest);
        return;
    }
    
    switch (COPrimitiveType(aType))
    {
        case kCOInt64Type:
            co_buffer_store_integer(dest, [aValue longLongValue]);
            break;
        case kCODoubleType:
            co_buffer_store_double(dest, [aValue doubleValue]);
            break;
        case kCOStringType:
            co_buffer_store_string(dest, aValue);
            break;
        case kCOBlobType:
            co_buffer_store_bytes(dest, [aValue bytes], [aValue length]);
            break;
        case kCOCompositeReferenceType:
            co_buffer_store_uuid(dest, aValue);
            break;
        case kCOReferenceType:
            if ([aValue isKindOfClass: [COPath class]])
            {
                co_buffer_store_string(dest, [(COPath *)aValue stringValue]);
            }
            else
            {
                co_buffer_store_uuid(dest, aValue);
            }
            break;
        case kCOAttachmentType:
            co_buffer_store_bytes(dest, [aValue bytes], [aValue length]);
            break;
        default:
            [NSException raise: NSInvalidArgumentException format: @"unknown type %d", aType];
    }
}

static void writeValue(co_buffer_t *dest, id aValue, COType aType)
{
    if (COTypeIsPrimitive(aType))
    {
        return writePrimitiveValue(dest, aValue, aType);
    }
    else
    {
        co_buffer_begin_array(dest);
        for (id obj in aValue)
        {
            writePrimitiveValue(dest, obj, aType);
        }
        co_buffer_end_array(dest);
    }
}

- (NSData *) dataValue
{
    co_buffer_t buf;
    co_buffer_init(&buf);
    co_buffer_store_uuid(&buf, [self UUID]);
    co_buffer_store_string(&buf, [self schemaName]);
    co_buffer_begin_object(&buf);
    
    for (NSString *prop in [self attributeNames])
    {
        COType type = [self typeForAttribute: prop];
        id val = [self valueForAttribute: prop];
        
        co_buffer_store_string(&buf, prop);
        co_buffer_store_integer(&buf, type);
        writeValue(&buf, val, type);
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
    COReaderState *state = (COReaderState *)ctx;
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
    COReaderState *state = (COReaderState *)ctx;
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
    COReaderState *state = (COReaderState *)ctx;
    switch (state->state)
    {
        case co_reader_expect_value:
            if (COPrimitiveType(state->currentType) == kCOReferenceType)
            {
                co_read_object_value(state, [COPath pathWithString: val]);
            }
            else if (COPrimitiveType(state->currentType) == kCOStringType)
            {
                co_read_object_value(state, val);
            }
            else
            {
                state->state = co_reader_error;
            }
            break;
        case co_reader_expect_property:
            ASSIGN(state->currentProperty, val);
            state->state = co_reader_expect_type;
            break;
        case co_reader_expect_object_schemaname:
            ASSIGN(state->schemaName, val);
            state->state = co_reader_expect_property;
            break;
        default:
            state->state = co_reader_error;
            break;
    }
}

static void co_read_uuid(void *ctx, ETUUID *uuid)
{
    COReaderState *state = (COReaderState *)ctx;
    switch (state->state)
    {
        case co_reader_expect_value:
            co_read_object_value(state, uuid);
            break;
        case co_reader_expect_object_uuid:
            ASSIGN(state->uuid, uuid);
            state->state = co_reader_expect_object_schemaname;
            break;
        default:
            state->state = co_reader_error;
            break;
    }
}

static void co_read_bytes(void *ctx, const unsigned char *val, size_t size)
{
    COReaderState *state = (COReaderState *)ctx;
    switch (state->state)
    {
        case co_reader_expect_value:
            co_read_object_value(state, [NSData dataWithBytes: val length: size]);
            break;
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
    COReaderState *state = (COReaderState *)ctx;
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
    COReaderState *state = (COReaderState *)ctx;
    state->isReadingMultivalue = NO;
    
    // Save the value
    [state->values setObject: state->multivalue
                      forKey: state->currentProperty];
    ASSIGN(state->multivalue, nil);
    
    // Do state transition
    state->state = co_reader_expect_property;
}
static void co_read_null(void *ctx)
{
    COReaderState *state = (COReaderState *)ctx;
    switch (state->state)
    {
        case co_reader_expect_value:
            co_read_object_value(state, NSNullCached);
            break;            
        case co_reader_expect_object_schemaname:
            ASSIGN(state->schemaName, nil);
            state->state = co_reader_expect_property;
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
                   state,
                   cb);
    
    SUPERINIT;
    ASSIGN(uuid, state->uuid);
    ASSIGN(types, state->types);
    ASSIGN(values, state->values);
    ASSIGN(schemaName, state->schemaName);
    [state release];
    
    return self;
}

@end

