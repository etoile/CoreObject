/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  March 2013
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"
#import "COBinaryReader.h"
#import "COBinaryWriter.h"

@interface TestBinaryReadWrite : NSObject <UKTest>
{
    NSMutableArray *readObjects;
}

@end


@implementation TestBinaryReadWrite

static NSString *const beginObject = @"<<begin object>>";
static NSString *const endObject = @"<<end object>>";
static NSString *const beginArray = @"<<begin array>>";
static NSString *const endArray = @"<<end array>>";

- (void)readObject: (id)anObject
{
    [readObjects addObject: anObject];
}

static void test_read_int64(void *ctx, int64_t val)
{
    [((__bridge TestBinaryReadWrite *)ctx) readObject: @(val)];
}

static void test_read_double(void *ctx, double val)
{
    [((__bridge TestBinaryReadWrite *)ctx) readObject: @(val)];
}

static void test_read_string(void *ctx, NSString *val)
{
    [((__bridge TestBinaryReadWrite *)ctx) readObject: val];
}

static void test_read_uuid(void *ctx, ETUUID *uuid)
{
    [((__bridge TestBinaryReadWrite *)ctx) readObject: uuid];
}

static void test_read_bytes(void *ctx, const unsigned char *val, size_t size)
{
    [((__bridge TestBinaryReadWrite *)ctx) readObject: [NSData dataWithBytes: val length: size]];
}

static void test_read_begin_object(void *ctx)
{
    [((__bridge TestBinaryReadWrite *)ctx) readObject: beginObject];
}

static void test_read_end_object(void *ctx)
{
    [((__bridge TestBinaryReadWrite *)ctx) readObject: endObject];
}

static void test_read_begin_array(void *ctx)
{
    [((__bridge TestBinaryReadWrite *)ctx) readObject: beginArray];
}

static void test_read_end_array(void *ctx)
{
    [((__bridge TestBinaryReadWrite *)ctx) readObject: endArray];
}

static void test_read_null(void *ctx)
{
    [((__bridge TestBinaryReadWrite *)ctx) readObject: [NSNull null]];
}

- (instancetype)init
{
    SUPERINIT;
    readObjects = [[NSMutableArray alloc] init];
    return self;
}

- (void)testBasic
{
    ETUUID *uuid = [ETUUID UUID];

    co_buffer_t buf;
    co_buffer_init(&buf);
    co_buffer_begin_object(&buf);
    co_buffer_begin_array(&buf);
    co_buffer_store_integer(&buf, 0);
    co_buffer_store_integer(&buf, -1);
    co_buffer_store_integer(&buf, 1);
    co_buffer_store_integer(&buf, -255);
    co_buffer_store_integer(&buf, 255);
    co_buffer_store_integer(&buf, -256);
    co_buffer_store_integer(&buf, 256);
    co_buffer_store_integer(&buf, -65535);
    co_buffer_store_integer(&buf, 65535);
    co_buffer_store_integer(&buf, -65536);
    co_buffer_store_integer(&buf, 65536);
    co_buffer_store_double(&buf, 3.14159);
    co_buffer_store_string(&buf, @"hello world!");
    co_buffer_store_string(&buf, @"");
    co_buffer_store_uuid(&buf, uuid);
    co_buffer_store_null(&buf);
    co_buffer_end_array(&buf);
    co_buffer_end_object(&buf);

    NSArray *expected = @[beginObject,
                          beginArray,
                          @(0),
                          @(-1),
                          @(1),
                          @(-255),
                          @(255),
                          @(-256),
                          @(256),
                          @(-65535),
                          @(65535),
                          @(-65536),
                          @(65536),
                          @(3.14159),
                          @"hello world!",
                          @"",
                          uuid,
                          [NSNull null],
                          endArray,
                          endObject];

    co_reader_callback_t cb = {
        test_read_int64,
        test_read_double,
        test_read_string,
        test_read_uuid,
        test_read_bytes,
        test_read_begin_object,
        test_read_end_object,
        test_read_begin_array,
        test_read_end_array,
        test_read_null
    };

    co_reader_read(co_buffer_get_data(&buf),
                   co_buffer_get_length(&buf),
                   (__bridge void *)(self),
                   cb);
    UKObjectsEqual(expected, readObjects);

    co_buffer_free(&buf);
}

static volatile char dest[2048];

- (void)testWritePerf
{
    ETUUID *uuid = [ETUUID UUID];

    co_buffer_t buf;
    co_buffer_init(&buf);
    co_buffer_begin_object(&buf);
    co_buffer_begin_array(&buf);
    co_buffer_store_integer(&buf, 0);
    co_buffer_store_integer(&buf, -1);
    co_buffer_store_integer(&buf, 1);
    co_buffer_store_integer(&buf, -255);
    co_buffer_store_integer(&buf, 255);
    co_buffer_store_integer(&buf, -256);
    co_buffer_store_integer(&buf, 256);
    co_buffer_store_integer(&buf, -65535);
    co_buffer_store_integer(&buf, 65535);
    co_buffer_store_integer(&buf, -65536);
    co_buffer_store_integer(&buf, 65536);
    co_buffer_store_double(&buf, 3.14159);
    co_buffer_store_string(&buf, @"hello world!");
    co_buffer_store_uuid(&buf, uuid);
    co_buffer_end_array(&buf);
    co_buffer_end_object(&buf);

    memcpy((void *)dest, co_buffer_get_data(&buf), co_buffer_get_length(&buf));

    co_buffer_free(&buf);
}

@end
