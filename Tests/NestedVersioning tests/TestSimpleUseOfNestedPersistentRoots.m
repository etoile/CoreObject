#if 0

void test()
{
	// library <<persistent root>>
	//  |
	//  |--document <<persistent root>>
	//  |   |
	//  |   \--item1
	//  |
	//   \-item2
	
	/**
	 1. create a context for library
	 */
	
	/**
	 2. create a context for document
	 */
	
	/**
	 3. edit item2 (library context) and commit
	 */
	
	/**
	 4. edit item1 (document context) and commit.

	    note that this causes a 'synthetic' commit for the
	    library object, which will be a child of the
	    commit made in step 3. Note that this is 
	    after the library context was created.
	 */
	
	// Test a case where committing requires a merge
	// and a case where a merge fails.
	
	// Test that the contents of a persistent root need
	// to be committed before you can open another context
	// on an embedded persistent root.
	// Why? If you could open a context on 'document' before
	// 'library' had ever been committed, committing in 'document'
	// would not be able to actually commit to the store.
}

#endif