/* Author: Quentin Mathe <qmathe@club-internet.fr> */

#import <Foundation/Foundation.h>
#import "LCIndexInput.h"
#import "LCMMapDirectory.h"

static int MAX_BBUF = INT_MAX;

/*
 * Objective-C Implementation overview
 *
 * Java -> GNUstep/Cocoa:
 * - File class -> NSString + NSFileManager + NSFileHandle classes (no direct
 * equivalent in GNUstep/Cocoa, NSString is used to store path)
 * - ByteBuffer class -> NSData, NSMutableData classes (no generic buffer
 * abstraction like Java class Buffer available in GNUstep/Cocoa)
 * - Channel class -> not needed (implementation detail in GNUstep/Cocoa)
 *
 * In Java, IndexInput related classes uses Java NIO buffer objects (ByteBuffer
 * class). ByteBuffer class has a position property incremented when methods 
 * like getXXX(), readXXX(), writeXXX() are called.
 * We use NSData/NSMutableData in ByteBuffer role for Objective-C
 * implementation, however there is an important difference:
 * NSData/NSMutableData doesn't store position when you call methods like
 * -getBytesXXX, -replaceBytesXXX similar to previously quoted Java methods. To
 * workaround this issue, we added a 'position' property for LCMMapIndexInput,
 * this ivar is used to store buffer's property position, and we added a
 * 'positions' array for LCMultiMMapIndexInput in similar way to store position
 * for each element in 'buffers' property array, each 'positions' entry
 * is indexed by the index of its corresponding buffer in 'buffers' array.
 */

/*
 * Interface for private classes
 */
 
@interface LCMMapIndexInput : LCIndexInput
{
	NSMutableData *buffer;
	unsigned long long length;
	int position;
	NSFileHandle *file;
}

+ (id) MMapIndexInputWithPath: (NSString *)path;
+ (id) MMapIndexInputWithURL: (NSURL *)url;

- (id) initWithPath: (NSString *)path;
- (id) initWithURL: (NSURL *)url; /* Designated initializer */

@end

/*
 * NOTE: Unlike in Java, LCMultiMMapIndexInput doesn't inherit from 
 * LCIndexInput but from LCMMapIndexInput because it avoids some ivars/methods
 * redeclaration.
 */
@interface LCMultiMMapIndexInput : LCMMapIndexInput 
{
	NSMutableArray *buffers; /* Declared as ByteBuffer[] in Java */
    int *bufferSizes; /* Array */
    int *positions; /* Array */

    /* private final long length; We don't need it because we inherit it from
       LCMMapIndexInput */
   int bufferIndex; /* curBufIndex in Java */
   int maxBufferSize;

	NSMutableData *currentBuffer; /* ByteBuffer curBuf in Java */ 
	// JAVA: redundant for speed: buffers[curBufIndex] */
	int currentAvailable; /* curAvailable in Java */ 
	// JAVA: redundant for speed: (bufSizes[curBufIndex] - curBuf.position())}
}

+ (id) MultiMMapIndexInputWithPath: (NSString *)path 
                     maxBufferSize: (int)maxBufferSize;
+ (id) MultiMMapIndexInputWithURL: (NSURL *)url 
                    maxBufferSize: (int)maxBufferSize;

- (id) initWithPath: (NSString *)path maxBufferSize: (int)bufferSize;
- (id) initWithURL: (NSURL *)url maxBufferSize: (int)bufferSize; 
    /* Designated initializer */

@end

/*
 * Main implementation
 */

@implementation LCMMapDirectory

- (LCIndexInput *) openInput: (NSString *)name
{
    /* 
     * In Java:
     * File f =  new File(getFile(), name); 
     * RandomAccessFile raf = new RandomAccessFile(f, "r");
     * 
     * In Objective-C: because GNUstep/Cocoa has no file object but only file
     * handle object for low level abstraction without encapsulated path
     * reference, we need to pass the subpath to LCMMapIndexInput or its
     * subclasses and let them recreating a file handle when needed. 
     */
    NSString *subpath = [self->path stringByAppendingPathComponent: name];
    NSFileHandle *file = [[NSFileHandle fileHandleForUpdatingAtPath: subpath]
retain];
  
    NS_DURING
            
        return ([file seekToEndOfFile] <= MAX_BBUF)
            ? (LCIndexInput *)[LCMMapIndexInput MMapIndexInputWithPath: subpath]
            : (LCIndexInput *)[LCMultiMMapIndexInput
                MultiMMapIndexInputWithPath: subpath maxBufferSize: MAX_BBUF];
    
    NS_HANDLER 
  
    // FIXME: In Java, 'finally' statement is used here, we should support new
    // Objective-C exceptions format here when possible.
    NSLog(@"%@: Impossible to use file %@.", self, path);
    [file closeFile];
    return nil;
   
    NS_ENDHANDLER
}

@end

/*
 * Implementation for private classes 
 */

@implementation LCMMapIndexInput

+ (id) MMapIndexInputWithPath: (NSString *)path
{
	LCMMapIndexInput *indexInput = [LCMMapIndexInput 
        MMapIndexInputWithURL: [NSURL fileURLWithPath: path]];
	
	return [indexInput autorelease];
}

+ (id) MMapIndexInputWithURL: (NSURL *)url
{
	LCMMapIndexInput *indexInput = [[LCMMapIndexInput alloc] initWithURL: url];
	
	return [indexInput autorelease];
}

- (id) initWithPath: (NSString *)path
{
	return [self initWithURL: [NSURL fileURLWithPath: path]];
}

- (id) initWithURL: (NSURL *)url
{
	if ((self = [super init]) != nil)
	{
        NSString *path = [url path];
     
        if ([url isFileURL])
		{
			file = [NSFileHandle fileHandleForReadingAtPath: path];
			[file retain];
		}
		else 
		{
			NSException* exception = 
                [NSException exceptionWithName: NSInvalidArgumentException
                reason: @"LCMMapIndexput class cannot be used with URL \
                referencing non local file." userInfo: nil];
			[exception raise];
		}
		length = [file seekToEndOfFile];
		buffer = [[NSMutableData alloc] initWithContentsOfMappedFile: path];
		
		return self;
	}
	
	return nil;	
}

- (void) dealloc
{
    /* May be we should move this close call to -close method. */
    if ([file retainCount] <= 1)
        [file closeFile];
    [file release];
    [buffer release];
    [super dealloc];   
}

- (char) readByte
{
	/* For ByteBuffer get() in Java. */
    char byte;
    
    /* We could optimize it with &[buffer bytes] */
    [buffer getBytes: &byte length: 1];
	position++;
	
 return byte;
}

- (void) readBytes: (NSMutableData *) b 
				offset: (int) offset 
				length: (int) len;
{  
   char *readBytes;
   
   /* For ByteBuffer getBytes() in Java. */
   [buffer getBytes: &readBytes range: NSMakeRange(position, len - position)];
   [b replaceBytesInRange: NSMakeRange(offset, len - offset) 
                withBytes: readBytes];
}


// FIXME : - (unsigned long long) offsetInFile would fit better with GNUstep 
// vocabulary
- (unsigned long long) offsetInFile
{
	/* For ByteBuffer position() in Java. */
	return position;
}


// FIXME : - (unsigned long long) seekToEndOfFile would fit better with GNUstep 
// vocabulary
- (unsigned long long) length
{
	/* For ByteBuffer length() in Java. */
	return length;
}


// FIXME : - (void) seekToFileOffset: (unsigned long long)offset would fit 
// better with GNUstep vocabulary
- (void) seekToFileOffset: (unsigned long long)offset
{
	/* For ByteBuffer seek() in Java. */
	position = offset;
}

- (void) close { }

/* For clone() and ByteBuffer duplicate() in Java. */
- (id) copyWithZone: (NSZone *)zone
{
    LCMMapIndexInput *clone = [super copyWithZone:  NSDefaultMallocZone()];
	
    /* [buffer copyWithZone: NSDefaultMallocZone()] */
    clone->buffer = (NSMutableData *)NSCopyObject(buffer, 0,
NSDefaultMallocZone()); 
    // NOTE: clone->file must be closed only when its retain count equals 1;
    // the fact is we cannot copy NSFileHandle object, that's why we retain it.
    [clone->file retain]; 
	 
	return clone;
}

@end

@implementation LCMultiMMapIndexInput

+ (id) MultiMMapIndexInputWithPath: (NSString *)path
                     maxBufferSize: (int)bufferSize
{
	LCMultiMMapIndexInput *indexInput = [LCMultiMMapIndexInput
        MultiMMapIndexInputWithURL: [NSURL fileURLWithPath: path] 
                     maxBufferSize: bufferSize];
	
	return [indexInput autorelease];
}

+ (id) MultiMMapIndexInputWithURL: (NSURL *)url 
                    maxBufferSize: (int)bufferSize
{
	LCMultiMMapIndexInput *indexInput = [[LCMultiMMapIndexInput alloc]
         initWithURL: url maxBufferSize: bufferSize];
	
	return [indexInput autorelease];
}

- (id) initWithPath: (NSString *)path maxBufferSize: (int)bufferSize
{
    return [self initWithURL: [NSURL fileURLWithPath: path] 
               maxBufferSize: bufferSize];
}

- (id) initWithURL: (NSURL *)url maxBufferSize: (int)bufferSize
{
	if ((self = [super initWithURL: url]) != nil)
	{
        self->maxBufferSize = maxBufferSize;
        if (maxBufferSize <= 0)
        {
            [NSException raise: NSInvalidArgumentException 
                format: @"%@ class cannot be initialized with non positive \
                maximum buffer size.", self, nil];
        }
		
        if ((length / maxBufferSize) > INT_MAX)
        {
            [NSException raise: NSInvalidArgumentException format: @"%@: File \
                %@ is too big for maximum buffer size.", self, [url path], nil];
        }
      
        int buffersCount = (int) (length / maxBufferSize);
        if ((buffersCount * maxBufferSize) < length) 
            buffersCount++;
      
        self->buffers = [[NSArray alloc] initWithCapacity: buffersCount];
        self->bufferSizes = calloc(buffersCount, sizeof(int));
        self->positions = calloc(buffersCount, sizeof(int));
      
        long bufferStart = 0;
#ifdef GNUSTEP
        NSMutableData *fileMap = 
            [NSMutableData dataWithContentsOfMappedFile: [url path]];
#else
        // FIXME: -dataWithContentsOfURL:options:error: needs to be implemented
        // in GNUstep.
        NSError *err = nil;
        NSMutableData *fileMap = [NSMutableData dataWithContentsOfURL: url
            options: NSMappedRead error: &err];
        if (err != nil)
        {
            [NSException raise: @"FileIOException" format: @"%@: Failed to \
                map in memory contents of url %@.", self, [url path], nil];
            // FIXME: Implement error checking and eventually recovery.
        }
#endif
        
        // NOTE: With C99 enabled, we could write 
        //for (int i = 0; i < buffersCount; i++) 
        int i;
        for (i = 0; i < buffersCount; i++) 
        { 
            int bufferSize = (length > (bufferStart + maxBufferSize))
                ? maxBufferSize
                : (int) (length - bufferStart);
            NSData *newBuffer = [NSData dataWithBytesNoCopy: 
                    (void *)([fileMap bytes] + bufferStart) length: bufferSize];
            
            [buffers addObject: newBuffer]; /* At index i */
            self->bufferSizes[i] = bufferSize;
            bufferStart += bufferSize;
        }
        [self seekToFileOffset: 0L];
 
        return self;
    }

    return nil;	
}


- (void) dealloc
{
    free(bufferSizes);
    free(positions);
    
    [currentBuffer release];
    [buffers release];
    [super dealloc];   
}

- (char) readByte
{
  char b;
  
    // JAVA:
    // Performance might be improved by reading ahead into an array of
    // eg. 128 bytes and readByte() from there.
    if (currentAvailable == 0) {
        bufferIndex++;
        // JAVA: index out of bounds when too many bytes requested
        currentBuffer = [buffers objectAtIndex: bufferIndex];
        positions[bufferIndex] = 0; /* curBuf.position(0); in Java */
        currentAvailable = bufferSizes[bufferIndex];
    }
    currentAvailable--;
    
    [currentBuffer getBytes: &b length: 1];
    positions[bufferIndex]++;
    
    return b;
}

- (void) readBytes: (NSMutableData *)b offset: (int) offset length: (int) len;
{
    char *readBytes;
    
    while (len > currentAvailable) 
    {
        /* For curBuf.get(b, offset, curAvail); in Java we do: */
        [currentBuffer getBytes: &readBytes 
                        range: NSMakeRange(position, currentAvailable)];
        [b replaceBytesInRange: NSMakeRange(offset, [b length]) 
                    withBytes: readBytes];
    
        len -= currentAvailable;
        offset += currentAvailable;
        bufferIndex++;
        // JAVA: index out of bounds when too many bytes requested
        currentBuffer = [buffers objectAtIndex: bufferIndex];
        positions[bufferIndex] = 0; /* currentBuffer = position(0); in Java */
        currentAvailable = bufferSizes[bufferIndex];
    }
  
    /* For curBuf.get(b, offset, len); in Java we do: */
    [currentBuffer getBytes: &readBytes range: NSMakeRange(position, len)];
    [b replaceBytesInRange: NSMakeRange(offset, [b length]) 
                 withBytes: readBytes];
   
    currentAvailable -= len;
}

// NOTE: I would prefer to have this method called -offsetInFile, it would look
// more steppish.
- (unsigned long long) offsetInFile
{
   return (bufferIndex * (long) maxBufferSize) + positions[bufferIndex];
}

// NOTE: - (unsigned long long) seekToEndOfFile would fit better with GNUstep 
// vocabulary.
/* - (long) length is implemented in superclass. */

// NOTE: - (void) seekToFileOffset: (unsigned long long)offset would fit better
// with GNUstep vocabulary
- (void) seekToFileOffset: (unsigned long long)pos
 {
  bufferIndex = (int) (pos / maxBufferSize);
  currentBuffer = [buffers objectAtIndex: bufferIndex];
  int bufferOffset = (int) (pos - (bufferIndex * maxBufferSize));
  
  /* curBuf.position(bufOffset); in Java */
  positions[bufferIndex] = bufferOffset; 
  currentAvailable = bufferSizes[bufferIndex] - bufferOffset;
}

- (id) copyWithZone: (NSZone *)zone 
{
    LCMultiMMapIndexInput *clone = [super copyWithZone:  NSDefaultMallocZone()];
    int n = [buffers count];
    
    clone->buffers = [[NSMutableArray alloc] initWithCapacity: n];
    memcpy(clone->positions, positions, sizeof(int) * n);
	// JAVA:
    // No need to clone bufSizes.
    // Since most clones will use only one buffer, duplicate() could also be
    // done lazy in clones, eg. when adapting curBuf
    
    // NOTE: With C99 enabled, we could write 
    // for (int i = 0; i < [buffers count]; i++)
    int i;
    for (i = 0; i < n; i++) {
        /* Objects will be added at index i */
        NSMutableData *bufferToCopy = [buffers objectAtIndex: i];
        
        bufferToCopy = (NSMutableData *)NSCopyObject((NSObject *)bufferToCopy,
0, NSDefaultMallocZone());
        [(clone->buffers) addObject: bufferToCopy];
    }
    
    NS_DURING

      [clone seekToFileOffset: [self offsetInFile]];
    
    NS_HANDLER
        
        // FIXME: That's not really useful...
        // In Java, we have: catch(IOException ioe) { throw new
        // RuntimeException(ioe); } [localException raise];
    
    NS_ENDHANDLER
   
    return clone;
 }
 
- (void) close { }

@end
