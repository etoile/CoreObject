#include "LCMetadataAttribute.h"
#include "GNUstep.h"

/* These attributes will be stored in index data. */
  /* Importer usually doesn't set LCMetadataChangeDateAttribute. LCIndexManager will do. */
NSString *LCMetadataChangeDateAttribute = @"LCMetadataChangeDateAttribute";
NSString *LCContentCreationDateAttribute = @"LCContentCreationDateAttribute";
NSString *LCContentModificationDateAttribute = @"LCContentModificationDateAttribute";
NSString *LCContentTypeAttribute = @"LCContentTypeAttribute";
NSString *LCCreatorAttribute = @"LCCreatorAttribute";
NSString *LCEmailAddressAttribute = @"LCEmailAddressAttribute";
NSString *LCIdentifierAttribute = @"LCIdentifierAttribute";
NSString *LCPathAttribute = @"LCPathAttribute";

/* These attributes will NOT be stored in index data */
NSString *LCTextContentAttribute = @"LCTextContentAttribute";
