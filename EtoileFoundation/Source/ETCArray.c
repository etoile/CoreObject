/*
 * ETCArray.c
 *
 * Created by David Chisnall on 01/10/2005.
 *
 * Copyright (c) 2007, David Chisnall
 *
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * * Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 *
 * * Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * * Neither the name of the Étoilé project, nor the names of its contributors
 * may be used to endorse or promote products derived from this software
 * without specific prior written permission.
 *
 */

#include <stdlib.h>
#include <string.h>
#include "ETCArray.h"

struct _ETCArray
{
	void ** array;
	unsigned int elements;
	unsigned int space;
};

//TODO: Optimise this so deleting the first element doesn't require the whole array to be shuffled.

ETCArray ETCArrayNew(void)
{
	return ETCArrayNewWithInitialSize(8);
}

ETCArray ETCArrayNewWithInitialSize(unsigned int initialSize)
{
	ETCArray newArray = malloc(sizeof(struct _ETCArray));
	newArray->elements = 0;
	newArray->space = initialSize;
	newArray->array = malloc(initialSize * sizeof(void*));
	return newArray;
}
int ETCArrayResize(ETCArray array, unsigned int newSize)
{
	void ** resizedArray = realloc(array->array,newSize* sizeof(void*));
	if(resizedArray != NULL)
	{
		array->space = newSize;
		array->array = resizedArray;
		return 0;
	}
	return -1;
}

int ETCArrayAdd(ETCArray array, void* object)
{
	if((array->elements + 1) >= array->space)
	{
		if(ETCArrayResize(array, array->space * 4))
		{
			return -1;
		}
	}
	array->array[array->elements] = object;
	array->elements++;
	return 0;
}

int ETCArrayAddAtIndex(ETCArray array, void* object, unsigned int anIndex)
{
	if(anIndex > (array->elements+1))
	{
		return -2;
	}
	if((array->elements+1) >= array->space)
	{
		if(ETCArrayResize(array, array->space * 2))
		{
			return -1;
		}
	}
	if(anIndex < array->elements)
	{
		size_t bytes = (array->elements - anIndex) * sizeof(void*);
		memmove(&array->array[anIndex+1],&array->array[anIndex],bytes);
	}
	array->array[anIndex] = object;
	array->elements++;
	return 0;	
}

int ETCArrayAppendArray(ETCArray array, ETCArray otherArray)
{
	if(array->space < array->elements + otherArray->elements)
	{
		if(ETCArrayResize(array,array->elements + otherArray->elements))
		{
			return -1;
		}
	}
	memcpy(&array->array[array->elements], otherArray->array, otherArray->elements);
	array->elements += otherArray->elements;
	return 0;
}

void* ETCArrayObjectAtIndex(ETCArray array, unsigned int anIndex)
{
	if(array == NULL 
	   ||
	   anIndex >= array->elements)
	{
		return NULL;
	}
	return array->array[anIndex];
}

int ETCArrayRemoveLastObject(ETCArray array)
{
	if(array->elements > 0)
	{
		array->elements--;
		return 0;
	}
	return -1;
}
int ETCArrayRemoveObjectAtIndex(ETCArray array, unsigned int anIndex)
{
	if(anIndex > array->elements)
	{
		return -1;
	}
	if(array->elements == 0)
	{
		return -2;
	}
	if(anIndex < array->elements)
	{
		size_t bytes = (array->elements - (anIndex + 1)) * sizeof(void*);
		memmove(&array->array[anIndex],&array->array[anIndex + 1],bytes);
	}
	array->elements--;
	return 0;
}

int ETCArrayIndexOfObjectIdenticalTo(ETCArray array, void* object)
{
	for(int i=0 ; i<(int)array->elements ; i++)
	{
		if(object == array->array[i])
		{
			return i;
		}
	}
	return -1;
}

int ETCArrayRemoveAllObjects(ETCArray array, int freeObjects)
{
	if(freeObjects)
	{
		for(unsigned int i=0 ; i<array->elements ; i++)
		{
			free(array->array[i]);
		}
	}
	array->elements = 0;
	return 0;
}

int ETCArraySwap(ETCArray array, unsigned int index1, unsigned int index2)
{
	if(array == NULL)
	{
		return -1;
	}
	if(index1 >= array->elements
	   ||
	   index2 >= array->elements)
	{
		return -2;
	}
	void * a = array->array[index1];
	array->array[index1] = array->array[index2];
	array->array[index2] = a;
	return 0;
}

unsigned int ETCArrayCount(ETCArray array)
{
	if(array == NULL)
	{
		return 0;
	}
	return array->elements;
}
void ETCArrayFree(ETCArray array)
{
	free(array->array);
	free(array);
}
