/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  March 2013
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"
#import "COBinaryReader.h"
#import "COBinaryWriter.h"

#define WRITE_ITERATIONS 10000LL

#define READ_ITERATIONS 10000LL

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
    NSDate *startDate = [NSDate date];

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

    for (NSUInteger i = 0; i < READ_ITERATIONS; i++)
    {
        [readObjects removeAllObjects];
        co_reader_read(co_buffer_get_data(&buf),
                       co_buffer_get_length(&buf),
                       (__bridge void *)(self),
                       cb);

        if (i == 0)
        {
            UKObjectsEqual(expected, readObjects);
        }
    }
    co_buffer_free(&buf);

    NSLog(@"reading %lld iterations of the reading test took %lf ms",
          READ_ITERATIONS,
          1000.0 * [[NSDate date] timeIntervalSinceDate: startDate]);
}


static volatile char dest[2048];

- (void)testWritePerf
{
    ETUUID *uuid = [ETUUID UUID];
    NSDate *startDate = [NSDate date];
    int64_t iter = 0;
    for (int64_t i = 0; i < WRITE_ITERATIONS; i++)
    {
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

        iter++;
    }

    NSLog(@"writing %lld iterations of the writing test took %lf ms",
          iter,
          1000.0 * [[NSDate date] timeIntervalSinceDate: startDate]);
}

@end
