#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETUUID.h>


typedef struct {
    unsigned char *data;
    size_t length;
    size_t allocated_length;
} co_buffer_t;

static inline
void
co_buffer_store_null(co_buffer_t *dest);


#define CO_BUFFER_INITIAL_LENGTH 4096

static inline
void
co_buffer_init(co_buffer_t *dest)
{
    dest->allocated_length = CO_BUFFER_INITIAL_LENGTH;
    dest->data = malloc(CO_BUFFER_INITIAL_LENGTH);
    dest->length = 0;
}

static inline
void
co_buffer_free(co_buffer_t *dest)
{
    free(dest->data);
}

static inline
const unsigned char *
co_buffer_get_data(co_buffer_t *dest)
{
    return dest->data;
}

static inline
size_t
co_buffer_get_length(co_buffer_t *dest)
{
    return dest->length;
}

static inline
void
co_buffer_ensure_available(co_buffer_t *dest, size_t len)
{
    const size_t currlength = dest->length;
    if (currlength + len > dest->allocated_length)
    {
        dest->allocated_length = currlength + len + CO_BUFFER_INITIAL_LENGTH;
        dest->data = realloc(dest->data, dest->allocated_length);
    }
}


static inline
void
co_buffer_write(co_buffer_t *dest, const unsigned char *data, size_t len)
{
    co_buffer_ensure_available(dest, len);

    memcpy(dest->data + dest->length, data, len);
    dest->length += len;
}

// FIXME: Would be better to avoid these casts
#define WRITE(v) co_buffer_write(dest, (const unsigned char *)&v, sizeof(v))
#define WRTITE_TYPE(t) co_buffer_write(dest, (const unsigned char *)t, 1)

static inline
void
co_buffer_store_uint8(co_buffer_t *dest, uint8_t value)
{
    WRITE(value);
}

static inline
void
co_buffer_store_uint16(co_buffer_t *dest, uint16_t value)
{
    uint16_t swapped = NSSwapHostShortToBig(value);
    WRITE(swapped);
}

static inline
void
co_buffer_store_uint32(co_buffer_t *dest, uint32_t value)
{
    uint32_t swapped = NSSwapHostIntToBig(value);
    WRITE(swapped);
}

static inline
void
co_buffer_store_uint64(co_buffer_t *dest, uint64_t value)
{
    uint64_t swapped = NSSwapHostLongLongToBig(value);
    WRITE(swapped);
}

static inline
void
co_buffer_store_integer(co_buffer_t *dest, int64_t value)
{
    if (value <= INT8_MAX && value >= INT8_MIN)
    {
        WRTITE_TYPE("B");
        co_buffer_store_uint8(dest, (uint8_t)value);
    }
    else if (value <= INT16_MAX && value >= INT16_MIN)
    {
        WRTITE_TYPE("i");
        co_buffer_store_uint16(dest, (uint16_t)value);
    }
    else if (value <= INT32_MAX && value >= INT32_MIN)
    {
        WRTITE_TYPE("I");
        co_buffer_store_uint32(dest, (uint32_t)value);
    }
    else
    {
        WRTITE_TYPE("L");
        co_buffer_store_uint64(dest, (uint64_t)value);
    }
}

static inline
void
co_buffer_store_double(co_buffer_t *dest, double value)
{
	NSSwappedDouble swapped = NSConvertHostDoubleToSwapped(value);
	WRTITE_TYPE("F");
    WRITE(swapped);
}

static inline
void
co_buffer_store_string(co_buffer_t *dest, NSString *value)
{
    if (value == nil)
    {
        co_buffer_store_null(dest);
        return;
    }
    
    const NSUInteger numChars = [value length];
    NSUInteger length = 0;
    [value getBytes: NULL
          maxLength: 0
         usedLength: &length
           encoding: NSUTF8StringEncoding
            options: 0
              range: NSMakeRange(0, numChars)
     remainingRange: NULL];
    
    if (length <= UINT8_MAX)
    {
        WRTITE_TYPE("s");
        co_buffer_store_uint8(dest, (uint8_t)length);
    }
    else if (length <= UINT32_MAX)
    {
        WRTITE_TYPE("S");
        co_buffer_store_uint32(dest, (uint32_t)length);
    }
    else
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"Strings longer than 2^32-1 not supported."];
    }
    
    co_buffer_ensure_available(dest, length);
    
    [value getBytes: dest->data + dest->length
          maxLength: length
         usedLength: NULL
           encoding: NSUTF8StringEncoding
            options: 0
              range: NSMakeRange(0, numChars)
     remainingRange: NULL];
    
    dest->length += length;
}

static inline
void
co_buffer_store_bytes(co_buffer_t *dest, const unsigned char *bytes, size_t length)
{
    if (length <= UINT8_MAX)
    {
        WRTITE_TYPE("d");
        co_buffer_store_uint8(dest, (uint8_t)length);
    }
    else if (length <= UINT32_MAX)
    {
        WRTITE_TYPE("D");
        co_buffer_store_uint32(dest, (uint32_t)length);
    }
    else
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"Data longer than 2^32-1 not supported."];
    }
    
    co_buffer_write(dest, bytes, length);
}

static inline
void
co_buffer_store_uuid(co_buffer_t *dest, ETUUID *uuid)
{
    if (uuid == nil)
    {
        co_buffer_store_null(dest);
        return;
    }
    
    WRTITE_TYPE("#");

    // TODO: Benchmark, access UUID bytes directly via a pointer?
    co_buffer_write(dest, [uuid UUIDValue], 16);
}

static inline
void
co_buffer_begin_object(co_buffer_t *dest)
{
    WRTITE_TYPE("{");
}

static inline
void
co_buffer_end_object(co_buffer_t *dest)
{
    WRTITE_TYPE("}");
}

static inline
void
co_buffer_begin_array(co_buffer_t *dest)
{
    WRTITE_TYPE("[");
}

static inline
void
co_buffer_end_array(co_buffer_t *dest)
{
    WRTITE_TYPE("]");
}

static inline
void
co_buffer_store_null(co_buffer_t *dest)
{
    WRTITE_TYPE("0");
}
