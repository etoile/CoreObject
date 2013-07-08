#import "COBinaryReader.h"
#import <EtoileFoundation/ETUUID.h>

static inline uint8_t readUint8(const unsigned char *bytes)
{
    return *bytes;
}

static inline uint16_t readUint16(const unsigned char *bytes)
{
    uint16_t unswapped;
    memcpy(&unswapped, bytes, 2);
    return CFSwapInt16BigToHost(unswapped);
}

static inline uint32_t readUint32(const unsigned char *bytes)
{
    uint32_t unswapped;
    memcpy(&unswapped, bytes, 4);
    return CFSwapInt32BigToHost(unswapped);
}

static inline uint64_t readUint64(const unsigned char *bytes)
{
    uint64_t unswapped;
    memcpy(&unswapped, bytes, 8);
    return CFSwapInt64BigToHost(unswapped);
}

void co_reader_read(const unsigned char *bytes, size_t length, void *context, co_reader_callback_t callbacks)
{
    size_t pos = 0;
    
    while (pos < length)
    {
        const char type = bytes[pos];
        pos++;
        
        switch (type)
        {
            case 'B':
                callbacks.co_read_int64(context, (int8_t)readUint8(bytes + pos));
                pos++;
                break;
            case 'i':
                callbacks.co_read_int64(context, (int16_t)readUint16(bytes + pos));
                pos += 2;
                break;
            case 'I':
                callbacks.co_read_int64(context, (int32_t)readUint32(bytes + pos));
                pos += 4;
                break;
            case 'L':
                callbacks.co_read_int64(context, (int64_t)readUint64(bytes + pos));
                pos += 8;
                break;
            case 'F':
            {
                CFSwappedFloat64 swapped;
                memcpy(&swapped, bytes + pos, 8);
                const double value = CFConvertDoubleSwappedToHost(swapped);
                callbacks.co_read_double(context, value);
                pos += 8;
                break;
            }
            case 's':
            {
                uint8_t dataLen = readUint8(&bytes[pos]);
                pos++;
                
                NSString *str = [[NSString alloc] initWithBytes: bytes + pos
                                                         length: dataLen
                                                       encoding: NSUTF8StringEncoding];
                callbacks.co_read_string(context, str);
                [str release];
                pos += dataLen;
                break;
            }
            case 'S':
            {
                uint32_t dataLen = readUint32(&bytes[pos]);
                pos += 4;

                NSString *str = [[NSString alloc] initWithBytes: bytes + pos
                                                         length: dataLen
                                                       encoding: NSUTF8StringEncoding];
                callbacks.co_read_string(context, str);
                [str release];
                pos += dataLen;
                break;
            }
            case 'd':
            {
                uint8_t dataLen = readUint8(&bytes[pos]);
                pos++;
                callbacks.co_read_bytes(context, bytes + pos, dataLen);
                pos += dataLen;
                break;
            }
            case 'D':
            {
                uint32_t dataLen = readUint32(&bytes[pos]);
                pos += 4;
                callbacks.co_read_bytes(context, bytes + pos, dataLen);
                pos += dataLen;
                break;
            }
            case '#':
            {
                ETUUID *uuid = [[ETUUID alloc] initWithUUID: bytes + pos];
                callbacks.co_read_uuid(context, uuid);
                [uuid release];
                pos += 16;
                break;
            }
            case '{':
                callbacks.co_read_begin_object(context);
                break;
            case '}':
                callbacks.co_read_end_object(context);
                break;
            case '[':
                callbacks.co_read_begin_array(context);
                break;
            case ']':
                callbacks.co_read_end_array(context);
                break;
            case '0':
                callbacks.co_read_null(context);
                break;
            default:
                [NSException raise: NSGenericException
                            format: @"unknown type '%c'", type];
        }
    }
}
