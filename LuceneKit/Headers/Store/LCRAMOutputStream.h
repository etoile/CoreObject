#ifndef __LUCENE_STORE_RAM_OUTPUT_STREAM__
#define __LUCENE_STORE_RAM_OUTPUT_STREAM__

#include "LCIndexOutput.h"
#include "LCRAMFile.h"

@interface LCRAMOutputStream: LCIndexOutput
{
	LCRAMFile *file;
	int pointer;
}

- (id) initWithFile: (LCRAMFile *) f;
- (void) writeTo: (LCIndexOutput *) o;
- (void) reset;

@end

#endif /* __LUCENE_STORE_RAM_OUTPUT_STREAM__ */
