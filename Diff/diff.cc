#include "diff.h"
#include "diff.hh"

class diffarray_wrapper
{
private:
	diff_arraycomparefn_t comparefn;
	void *userdata1, *userdata2;
public:
	bool equal(size_t i, size_t j)
	{
		return comparefn(i, j, userdata1, userdata2);
	}
	diffarray_wrapper(diff_arraycomparefn_t comparefn,
					  void *userdata1, void *userdata2) :
        comparefn(comparefn), userdata1(userdata1), userdata2(userdata2) {};
};

typedef struct
{
	size_t editcount;
	diffedit_t *edits;
} diffresult_internal_t;

diffresult_t *diff_arrays(size_t alength, size_t blength, diff_arraycomparefn_t comparefn,
						  void *userdata1, void *userdata2)
{
	diffarray_wrapper wrapper(comparefn, userdata1, userdata2);
	
	std::vector<ManagedFusion::DifferenceItem> items = 
		ManagedFusion::Diff<diffarray_wrapper>(wrapper, alength, blength);
    
	diffedit_t *edits = (diffedit_t *)malloc(sizeof(diffedit_t) * items.size());
	diffresult_internal_t *result = (diffresult_internal_t *)malloc(sizeof(diffresult_internal_t));
	result->edits = edits;
	result->editcount = items.size();
	
	for (size_t i=0; i<result->editcount; i++)
	{
		ManagedFusion::DifferenceItem &it = items[i];
		
		diffrange_t firstRange = {it.rangeInA.location, it.rangeInA.length};
		diffrange_t secondRange = {it.rangeInB.location, it.rangeInB.length};
		int difftype;
		
		switch (it.type)
		{
			case ManagedFusion::INSERTION: difftype = difftype_insertion; break;
			case ManagedFusion::DELETION: difftype = difftype_deletion; break;
			case ManagedFusion::MODIFICATION: difftype = difftype_modification; break;
		}
		
		edits[i].range_in_a = firstRange;
		edits[i].range_in_b = secondRange;
		edits[i].type = (difftype_t)difftype;
	}

	return (diffresult_t *)result;
}

size_t diff_editcount(diffresult_t *result)
{
	return ((diffresult_internal_t*)result)->editcount;
}

diffedit_t diff_edit_at_index(diffresult_t *result, size_t i)
{
	return ((diffresult_internal_t*)result)->edits[i];
}

void diff_free(diffresult_t *result)
{
	free(((diffresult_internal_t*)result)->edits);
	free(result);
}