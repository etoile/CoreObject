#include "LCRAMDirectory.h"
#include "LCIndexInput.h"
#include "LCCompoundFileWriter.h"
#include "LCCompoundFileReader.h"
#include <Foundation/Foundation.h>
#include <UnitKit/UnitKit.h>
#include "LCDirectory.h"

@interface TestCompoundFile: NSObject <UKTest>
{
	id <LCDirectory> dir;
}

@end

@implementation TestCompoundFile

- (id) init
{
	self = [super init];
	// FIXME: should test on file system
	dir = [[LCRAMDirectory alloc] init];
	return self;
}

/** Creates a file of the specified size with random data. */
- (void) createRandomFile: (id <LCDirectory>) d
					 name: (NSString *) name
					 size: (int) size
{
	LCIndexOutput *os = [d createOutput: name];
	int i;
	for (i = 0; i < size; i++)
	{
		char b = (char)(random() & 0xff);
		[os writeByte: b];
	}
	[os close];
}

/** Creates a file of the specified size with sequential data. The first
*  byte is written as the start byte provided. All subsequent bytes are
*  computed as start + offset where offset is the number of the byte.
*/
- (void) createSequenceFile: (id <LCDirectory>) d
					   name: (NSString *) name
					  start: (char) start
					   size: (int) size
{
	LCIndexOutput *os = [d createOutput: name];
	int i;
	for (i = 0; i < size; i++)
	{
		[os writeByte: start];
		start++;
	}
	[os close];
}

- (void) assertEqualArrays: (NSString *) msg
				  expected: (NSData *) expected
					actual: (NSData *) test
					 start: (int) start
					   len: (int) len
{
	UKNotNil(expected);
	UKNotNil(test);
	NSRange r = NSMakeRange(start, len);
	NSData *e = [expected subdataWithRange: r];
	NSData *t = [test subdataWithRange: r];
	UKTrue([e isEqualToData: t]);
}

- (void) assertSameStreams: (NSString *) msg
				  expected: (LCIndexInput *) expected
					actual: (LCIndexInput *) test
{
	UKNotNil(expected);
	UKNotNil(test);
	UKIntsEqual([expected length], [test length]);
	UKIntsEqual([expected offsetInFile], [test offsetInFile]);
	
	int size = 512;
	NSMutableData *expectedBuffer = [[NSMutableData alloc] init];
	NSMutableData *testBuffer = [[NSMutableData alloc] init];
	long long remainder = [expected length] - [expected offsetInFile];
	while(remainder > 0) {
		int readLen = (int) ((remainder < size) ? remainder : size);
		[expected readBytes: expectedBuffer offset: 0 length: readLen];
		[test readBytes: testBuffer offset: 0 length: readLen];
		[self assertEqualArrays: msg
					   expected: expectedBuffer
						 actual: testBuffer
						  start: 0
							len: readLen];
		remainder -= readLen;
	}
}

- (void) assertSameStreams: (NSString *) msg
				  expected: (LCIndexInput *) expected
					actual: (LCIndexInput *) actual
					  seek: (long) seekTo
{
	if (seekTo >= 0 && seekTo < [expected length])
    {
		[expected seekToFileOffset: seekTo];
		[actual seekToFileOffset: seekTo];
		[self assertSameStreams: msg
					   expected: expected
						 actual: actual];
    }
}

- (void) assertSameSeekBehavior: (NSString *) msg
					   expected: (LCIndexInput *) expected
						 actual: (LCIndexInput *) actual
{
	// seek to 0
	long point = 0;
	[self assertSameStreams: msg
				   expected: expected
					 actual: actual
					   seek: point];
	
	// seek to middle
	point = [expected length] / 2l;
	[self assertSameStreams: msg
				   expected: expected
					 actual: actual
					   seek: point];
	
	// seek to end - 2
	point = [expected length] - 2;
	[self assertSameStreams: msg
				   expected: expected
					 actual: actual
					   seek: point];
	
	// seek to end - 1
	point = [expected length] - 1;
	[self assertSameStreams: msg
				   expected: expected
					 actual: actual
					   seek: point];
	
	// seek to the end
	point = [expected length];
	[self assertSameStreams: msg
				   expected: expected
					 actual: actual
					   seek: point];
	
	// seek past end
	point = [expected length] + 1;
	[self assertSameStreams: msg
				   expected: expected
					 actual: actual
					   seek: point];
}


// ===========================================================
//  Tests of the basic CompoundFile functionality
// ===========================================================


/** This test creates compound file based on a single file.
*  Files of different sizes are tested: 0, 1, 10, 100 bytes.
*/
- (void) testSingleFile
{
	int data[4] = {0, 1, 10, 100};
	int i;
	for (i = 0; i < 4; i++)
    {
		NSString *name = [NSString stringWithFormat: @"t%d", data[i]];
		[self createSequenceFile: dir
							name: name
						   start: (char) 0
							size: data[i]];
		LCCompoundFileWriter *csw = [[LCCompoundFileWriter alloc] initWithDirectory: dir name: [name stringByAppendingPathExtension: @"cfs"]];
		[csw addFile: name];
		[csw close];
		
		LCCompoundFileReader *csr = [[LCCompoundFileReader alloc] initWithDirectory: dir name: [name stringByAppendingPathExtension: @"cfs"]];
		LCIndexInput *expected = [dir openInput: name];
		LCIndexInput *actual = [csr openInput: name];
		[self assertSameStreams: name expected: expected actual: actual];
		[self assertSameSeekBehavior: name expected: expected actual: actual];
		[expected close];
		[actual close];
		[csr close];
	}
}


/** This test creates compound file based on two files.
*
*/
- (void) testTwoFiles
{
	[self createSequenceFile: dir
						name: @"d1"
					   start: (char)0
						size: 15];
	[self createSequenceFile: dir
						name: @"d2"
					   start: (char)0
						size: 114];
	
	LCCompoundFileWriter *csw = [[LCCompoundFileWriter alloc] initWithDirectory: dir name: @"d.csf"];
	[csw addFile: @"d1"];
	[csw addFile: @"d2"];
	[csw close];
	
	LCCompoundFileReader *csr = [[LCCompoundFileReader alloc] initWithDirectory: dir name: @"d.csf"];
	LCIndexInput *expected = [dir openInput: @"d1"];
	LCIndexInput *actual = [csr openInput: @"d1"];
	[self assertSameStreams: @"d1" expected: expected actual: actual];
	[self assertSameSeekBehavior: @"d1" expected: expected actual: actual];
	[expected close];
	[actual close];
	
	expected = [dir openInput: @"d2"];
	actual = [csr openInput: @"d2"];
	[self assertSameStreams: @"d2" expected: expected actual: actual];
	[self assertSameSeekBehavior: @"d2" expected: expected actual: actual];
	[expected close];
	[actual close];
	[csr close];
}

/** This test creates a compound file based on a large number of files of
*  various length. The file content is generated randomly. The sizes range
*  from 0 to 1Mb. Some of the sizes are selected to test the buffering
*  logic in the file reading code. For this the chunk variable is set to
*  the length of the buffer used internally by the compound file logic.
*/
- (void) testRandomFiles
{
	// Setup the test segment
	NSString *segment = @"test";
	int chunk = 1024; // internal buffer size used by the stream
	[self createRandomFile: dir name: [segment stringByAppendingPathExtension: @"zero"] size: 0];
	[self createRandomFile: dir name: [segment stringByAppendingPathExtension: @"one"] size: 1];
	[self createRandomFile: dir name: [segment stringByAppendingPathExtension: @"ten"] size: 10];
	[self createRandomFile: dir name: [segment stringByAppendingPathExtension: @"hundred"] size: 100];
	[self createRandomFile: dir name: [segment stringByAppendingPathExtension: @"big1"] size: chunk];
	[self createRandomFile: dir name: [segment stringByAppendingPathExtension: @"big2"] size: chunk-1];
	[self createRandomFile: dir name: [segment stringByAppendingPathExtension: @"big3"] size: chunk+1];
	[self createRandomFile: dir name: [segment stringByAppendingPathExtension: @"big4"] size: chunk*3];
	[self createRandomFile: dir name: [segment stringByAppendingPathExtension: @"big5"] size: chunk*3-1];
	[self createRandomFile: dir name: [segment stringByAppendingPathExtension: @"big6"] size: chunk*3+1];
	[self createRandomFile: dir name: [segment stringByAppendingPathExtension: @"big7"] size: chunk*1000];
	
	// Setup extraneous files
	[self createRandomFile: dir name: @"onetwothree" size: 100];
	[self createRandomFile: dir name: [segment stringByAppendingPathExtension: @"notIn"] size: 50];
	[self createRandomFile: dir name: [segment stringByAppendingPathExtension: @"notIn2"] size: 51];
	
	// Now test
	LCCompoundFileWriter *csw = [[LCCompoundFileWriter alloc] initWithDirectory: dir name: @"test.cfs"];
	NSArray *data = [NSArray arrayWithObjects: @"zero", @"one", @"ten", @"hundred", @"big1", @"big2", @"big3", @"big4", @"big5", @"big6", @"big7", nil];
	int i;
	for (i = 0; i < [data count]; i++)
	{
		[csw addFile: [segment stringByAppendingPathExtension: [data objectAtIndex: i]]];
	}
	[csw close];
	
	LCCompoundFileReader *csr = [[LCCompoundFileReader alloc] initWithDirectory: dir name: @"test.cfs"];
	
	for (i = 0; i < [data count]; i++) 
	{
		LCIndexInput *check = [dir openInput: [segment stringByAppendingPathExtension: [data objectAtIndex: i]]];
		LCIndexInput *test= [csr openInput: [segment stringByAppendingPathExtension: [data objectAtIndex: i]]];
		[self assertSameStreams: [data objectAtIndex: i] expected: check actual: test];
		[self assertSameSeekBehavior: [data objectAtIndex: i] expected: check actual: test];
		[test close];
		[check close];
	}
	[csr close];
}


/** Setup a larger compound file with a number of components, each of
*  which is a sequential file (so that we can easily tell that we are
							   *  reading in the right byte). The methods sets up 20 files - f0 to f19,
*  the size of each file is 1000 bytes.
*/
- (void) setUp_2
{
	LCCompoundFileWriter *cw = [[LCCompoundFileWriter alloc] initWithDirectory: dir name: @"f.comp"];
	int i;
	for (i=0; i<20; i++) 
	{
		[self createSequenceFile: dir name: [NSString stringWithFormat: @"f%d", i]
						   start: (char)0 size: 2000];
		[cw addFile: [NSString stringWithFormat: @"f%d", i]];
	}
	[cw close];
}

#if 0
public void testReadAfterClose() throws IOException {
	demo_FSIndexInputBug((FSDirectory) dir, "test");
}

private void demo_FSIndexInputBug(FSDirectory fsdir, String file)
throws IOException
{
	// Setup the test file - we need more than 1024 bytes
	IndexOutput os = fsdir.createOutput(file);
	for(int i=0; i<2000; i++) {
		os.writeByte((byte) i);
	}
	os.close();
	
	IndexInput in = fsdir.openInput(file);
	
	// This read primes the buffer in IndexInput
	byte b = in.readByte();
	
	// Close the file
	in.close();
	
	// ERROR: this call should fail, but succeeds because the buffer
	// is still filled
	b = in.readByte();
	
	// ERROR: this call should fail, but succeeds for some reason as well
	in.seek(1099);
	
	try {
		// OK: this call correctly fails. We are now past the 1024 internal
		// buffer, so an actual IO is attempted, which fails
		b = in.readByte();
	} catch (IOException e) {
	}
}
#endif

#if 0
+ (BOOL) isCSIndexInput: (LCIndexInput *) is
{
	return [is isKindOfClass: [LCCSIndexInput class]];
}

+ (BOOL) isCSIndexInputOpen: (LCIndexInput *) is
{
	if ([TestCompoundFile isCSIndexInput: is])
	{
		CompoundFileReader.CSIndexInput cis =
		(CompoundFileReader.CSIndexInput) is;
		
		return _TestHelper.isFSIndexInputOpen(cis.base);
	}
	else
		return NO;
}

public void testClonedStreamsClosing() throws IOException {
	setUp_2();
	CompoundFileReader cr = new CompoundFileReader(dir, "f.comp");
	
	// basic clone
	IndexInput expected = dir.openInput("f11");
	
	// this test only works for FSIndexInput
	if (_TestHelper.isFSIndexInput(expected)) {
		
		assertTrue(_TestHelper.isFSIndexInputOpen(expected));
		
		IndexInput one = cr.openInput("f11");
		assertTrue(isCSIndexInputOpen(one));
		
		IndexInput two = (IndexInput) one.clone();
		assertTrue(isCSIndexInputOpen(two));
		
		assertSameStreams("basic clone one", expected, one);
		expected.seek(0);
		assertSameStreams("basic clone two", expected, two);
		
		// Now close the first stream
		one.close();
		assertTrue("Only close when cr is closed", isCSIndexInputOpen(one));
		
		// The following should really fail since we couldn't expect to
		// access a file once close has been called on it (regardless of
		// buffering and/or clone magic)
		expected.seek(0);
		two.seek(0);
		assertSameStreams("basic clone two/2", expected, two);
		
		
		// Now close the compound reader
		cr.close();
		assertFalse("Now closed one", isCSIndexInputOpen(one));
		assertFalse("Now closed two", isCSIndexInputOpen(two));
		
		// The following may also fail since the compound stream is closed
		expected.seek(0);
		two.seek(0);
		//assertSameStreams("basic clone two/3", expected, two);
		
		
		// Now close the second clone
		two.close();
		expected.seek(0);
		two.seek(0);
		//assertSameStreams("basic clone two/4", expected, two);
	}
	
	expected.close();
}
#endif

/** This test opens two files from a compound stream and verifies that
*  their file positions are independent of each other.
*/
- (void) testRandomAccess
{
	[self setUp_2];
	LCCompoundFileReader *cr = [[LCCompoundFileReader alloc] initWithDirectory: dir name: @"f.comp"];
	
	// Open two files
	LCIndexInput *e1 = [dir openInput: @"f11"];
	LCIndexInput *e2 = [dir openInput: @"f3"];
	
	LCIndexInput *a1 = [cr openInput: @"f11"];
	LCIndexInput *a2 = [cr openInput: @"f3"];
	
	// Seek the first pair
	[e1 seekToFileOffset: 100];
	[a1 seekToFileOffset: 100];
	UKIntsEqual(100, [e1 offsetInFile]);
	UKIntsEqual(100, [a1 offsetInFile]);
	char be1 = [e1 readByte];
	char ba1 = [a1 readByte];
	UKIntsEqual(be1, ba1);
	
	// Now seek the second pair
	[e2 seekToFileOffset: 1027];
	[a2 seekToFileOffset: 1027];
	UKIntsEqual(1027, [e2 offsetInFile]);
	UKIntsEqual(1027, [a2 offsetInFile]);
	char be2 = [e2 readByte];
	char ba2 = [a2 readByte];
	UKIntsEqual(be2, ba2);
	
	// Now make sure the first one didn't move
	UKIntsEqual(101, [e1 offsetInFile]);
	UKIntsEqual(101, [a1 offsetInFile]);
	be1 = [e1 readByte];
	ba1 = [a1 readByte];
	UKIntsEqual(be1, ba1);
	
	// Now more the first one again, past the buffer length
	[e1 seekToFileOffset: 1910];
	[a1 seekToFileOffset: 1910];
	UKIntsEqual(1910, [e1 offsetInFile]);
	UKIntsEqual(1910, [a1 offsetInFile]);
	be1 = [e1 readByte];
	ba1 = [a1 readByte];
	UKIntsEqual(be1, ba1);
	
	// Now make sure the second set didn't move
	UKIntsEqual(1028, [e2 offsetInFile]);
	UKIntsEqual(1028, [a2 offsetInFile]);
	be2 = [e2 readByte];
	ba2 = [a2 readByte];
	UKIntsEqual(be2, ba2);
	
	// Move the second set back, again cross the buffer size
	[e2 seekToFileOffset: 17];
	[a2 seekToFileOffset: 17];
	UKIntsEqual(17, [e2 offsetInFile]);
	UKIntsEqual(17, [a2 offsetInFile]);
	be2 = [e2 readByte];
	ba2 = [a2 readByte];
	UKIntsEqual(be2, ba2);
	
	// Finally, make sure the first set didn't move
	// Now make sure the first one didn't move
	UKIntsEqual(1911, [e1 offsetInFile]);
	UKIntsEqual(1911, [a1 offsetInFile]);
	be1 = [e1 readByte];
	ba1 = [a1 readByte];
	UKIntsEqual(be1, ba1);
	
	[e1 close];
	[e2 close];
	[a1 close];
	[a2 close];
	[cr close];
}

/** This test opens two files from a compound stream and verifies that
*  their file positions are independent of each other.
*/
- (void) testRandomAccessClones
{
	[self setUp_2];
	LCCompoundFileReader *cr = [[LCCompoundFileReader alloc] initWithDirectory: dir name: @"f.comp"];
	
	// Open two files
	LCIndexInput *e1 = [cr openInput: @"f11"];
	LCIndexInput *e2 = [cr openInput: @"f3"];
	
	LCIndexInput *a1 = [e1 copy];
	LCIndexInput *a2 = [e2 copy];
	
	// Seek the first pair
	[e1 seekToFileOffset: 100];
	[a1 seekToFileOffset: 100];
	UKIntsEqual(100, [e1 offsetInFile]);
	UKIntsEqual(100, [a1 offsetInFile]);
	char be1 = [e1 readByte];
	char ba1 = [a1 readByte];
	UKIntsEqual(be1, ba1);
	
	// Now seek the second pair
	[e2 seekToFileOffset: 1027];
	[a2 seekToFileOffset: 1027];
	UKIntsEqual(1027, [e2 offsetInFile]);
	UKIntsEqual(1027, [a2 offsetInFile]);
	char be2 = [e2 readByte];
	char ba2 = [a2 readByte];
	UKIntsEqual(be2, ba2);
	
	// Now make sure the first one didn't move
	UKIntsEqual(101, [e1 offsetInFile]);
	UKIntsEqual(101, [a1 offsetInFile]);
	be1 = [e1 readByte];
	ba1 = [a1 readByte];
	UKIntsEqual(be1, ba1);
	
	// Now more the first one again, past the buffer length
	[e1 seekToFileOffset: 1910];
	[a1 seekToFileOffset: 1910];
	UKIntsEqual(1910, [e1 offsetInFile]);
	UKIntsEqual(1910, [a1 offsetInFile]);
	be1 = [e1 readByte];
	ba1 = [a1 readByte];
	UKIntsEqual(be1, ba1);
	
	// Now make sure the second set didn't move
	UKIntsEqual(1028, [e2 offsetInFile]);
	UKIntsEqual(1028, [a2 offsetInFile]);
	be2 = [e2 readByte];
	ba2 = [a2 readByte];
	UKIntsEqual(be2, ba2);
	
	// Move the second set back, again cross the buffer size
	[e2 seekToFileOffset: 17];
	[a2 seekToFileOffset: 17];
	UKIntsEqual(17, [e2 offsetInFile]);
	UKIntsEqual(17, [a2 offsetInFile]);
	be2 = [e2 readByte];
	ba2 = [a2 readByte];
	UKIntsEqual(be2, ba2);
	
	// Finally, make sure the first set didn't move
	// Now make sure the first one didn't move
	UKIntsEqual(1911, [e1 offsetInFile]);
	UKIntsEqual(1911, [a1 offsetInFile]);
	be1 = [e1 readByte];
	ba1 = [a1 readByte];
	UKIntsEqual(be1, ba1);
	
	[e1 close];
	[e2 close];
	[a1 close];
	[a2 close];
	[cr close];
}

#if 0
- (void) testFileNotFound
{
	[self setUp_2];
	LCCompoundFileReader *cr = [[LCCompoundFileReader(dir, "f.comp");
		
        // Open two files
        try {
            IndexInput e1 = cr.openInput("bogus");
            fail("File not found");
			
        } catch (IOException e) {
            /* success */
            //System.out.println("SUCCESS: File Not Found: " + e);
        }
		
        cr.close();
    }
#endif


#if 0
public void testReadPastEOF() throws IOException {
	setUp_2();
	CompoundFileReader cr = new CompoundFileReader(dir, "f.comp");
	IndexInput is = cr.openInput("f2");
	is.seek(is.length() - 10);
	byte b[] = new byte[100];
	is.readBytes(b, 0, 10);
	
	try {
		byte test = is.readByte();
		fail("Single byte read past end of file");
	} catch (IOException e) {
		/* success */
		//System.out.println("SUCCESS: single byte read past end of file: " + e);
	}
	
	is.seek(is.length() - 10);
	try {
		is.readBytes(b, 0, 50);
		fail("Block read past end of file");
	} catch (IOException e) {
		/* success */
		//System.out.println("SUCCESS: block read past end of file: " + e);
	}
	
	is.close();
	cr.close();
}
}
#endif

@end
