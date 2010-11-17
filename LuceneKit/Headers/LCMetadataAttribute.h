#ifndef __LuceneKit_LCMetadata_Attribute__
#define __LuceneKit_LCMetadata_Attribute__

#include <Foundation/NSString.h>

/* These attributes will be stored in index data. */
  /* Importer usually doesn't set LCMetadataChangeDateAttribute. LCIndexManager will do. */
extern NSString *LCMetadataChangeDateAttribute;
extern NSString *LCContentCreationDateAttribute;
extern NSString *LCContentModificationDateAttribute;
extern NSString *LCContentTypeAttribute;
extern NSString *LCCreatorAttribute;
extern NSString *LCEmailAddressAttribute;
extern NSString *LCIdentifierAttribute;
extern NSString *LCPathAttribute;

/* These attributes will NOT be stored in index data */
extern NSString *LCTextContentAttribute;

#endif /*  __LuceneKit_LCMetadata_Attribute__ */
