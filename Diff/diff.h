#ifdef __cplusplus
extern "C" {
#endif

#ifndef nestedversioning_diff_h
#define nestedversioning_diff_h

#include <stdint.h>
#include <stdlib.h>

// types	
	
typedef struct
{
	size_t location;
	size_t length; 
} diffrange_t;

typedef enum 
{
	difftype_insertion,
	difftype_deletion,
	difftype_modification
} difftype_t;

typedef struct
{
	diffrange_t range_in_a;
	diffrange_t range_in_b;
	difftype_t type;
} diffedit_t;

typedef void diffresult_t;

/**
 * return true if array_a[i] is equal to array_b[j]
 */
typedef bool (*diff_arraycomparefn_t)(size_t i, size_t j, void *userdata1, void *userdata2);

// functions	

/**
 * generates a diff of array_a with array_b.
 *
 * caller provides the lengths of the arrays and a pointer to a function which
 * checks elements at two indices for equality.
 */
diffresult_t *diff_arrays(size_t alength, size_t blength, diff_arraycomparefn_t comparefn, 
						  void *userdata1, void *userdata2);
/**
 * returns the number of edits in the diff
 */
size_t diff_editcount(diffresult_t *result);
/**
 * returns the ith edit, starting at 0
 */
diffedit_t diff_edit_at_index(diffresult_t *result, size_t i);
	
void diff_free(diffresult_t *result);

#endif /* nestedversioning_diff_h */
	
#ifdef __cplusplus
}
#endif
