/*
 *  ETCArray.h
 *
 *  Simple array opaque data type and manipulation functions
 *
 *  Created by David Chisnall on 01/10/2005.
 *
 */
#ifndef __ET_C_ARRAY_INCLUDED__
#define __ET_C_ARRAY_INCLUDED__

/**
 * Opaque type representing a thin layer of abstraction around a dynamic C
 * array.  An ETCArray can be used to store any pointer type.
 */
typedef struct _ETCArray* ETCArray;

/**
 * Creates a new array with some default initial capacity.
 */
ETCArray ETCArrayNew(void);
/**
 * Creates a new array with a specified initial capacity.
 */
ETCArray ETCArrayNewWithInitialSize(unsigned int initialSize);

/**
 * Adds object at the end of array, allocating more space if needed.
 */
int ETCArrayAdd(ETCArray array, void* object);
/**
 * Adds object to array at anIndex, replacing the existing value at that index.
 */
int ETCArrayAddAtIndex(ETCArray array, void* object, unsigned int anIndex);

/**
 * Appends the contents of otherArray to array.
 */
int ETCArrayAppendArray(ETCArray array, ETCArray otherArray);

/**
 * Returns the value at the specified index.
 */
void* ETCArrayObjectAtIndex(ETCArray array, unsigned int anIndex);
/**
 * Swap the values at two indexes.
 */
int ETCArraySwap(ETCArray array, unsigned int index1, unsigned int index2);

/**
 * Removes the object at the specified index.  All subsequent objects will
 * moved up the array by one element.
 */
int ETCArrayRemoveObjectAtIndex(ETCArray array, unsigned int anIndex);
/**
 * Removes the last object from an array.
 */
int ETCArrayRemoveLastObject(ETCArray array);
/**
 * Removes all objects from the array, giving an empty array.
 */
int ETCArrayRemoveAllObjects(ETCArray array, int freeObjects);
/**
 * Returns the number of objects in the array.
 */
unsigned int ETCArrayCount(ETCArray array);
/**
 * Returns the index of the specified value.
 */
int ETCArrayIndexOfObjectIdenticalTo(ETCArray array, void* object);
/**
 * Destroy the array.
 */
void ETCArrayFree(ETCArray array);
#endif
