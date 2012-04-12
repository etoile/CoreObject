/// <summary>
/// This Class implements the Difference Algorithm published in
/// "An O(ND) Difference Algorithm and its Variations" by Eugene Myers
/// Algorithmica Vol. 1 No. 2, 1986, p 251.  
/// 
/// There are many C, Java, Lisp implementations public available but they all seem to come
/// from the same source (diffutils) that is under the (unfree) GNU public License
/// and cannot be reused as a sourcecode for a commercial application.
/// There are very old C implementations that use other (worse) algorithms.
/// Microsoft also published sourcecode of a diff-tool (windiff) that uses some tree data.
/// Also, a direct transfer from a C source to C# is not easy because there is a lot of pointer
/// arithmetic in the typical C solutions and i need a managed solution.
/// These are the reasons why I implemented the original published algorithm from the scratch and
/// make it avaliable without the GNU license limitations.
/// I do not need a high performance diff tool because it is used only sometimes.
/// I will do some performace tweaking when needed.
/// 
/// The algorithm itself is comparing 2 arrays of numbers so when comparing 2 text documents
/// each line is converted into a (hash) number. See DiffText(). 
/// 
/// Some chages to the original algorithm:
/// The original algorithm was described using a recursive approach and comparing zero indexed arrays.
/// Extracting sub-arrays and rejoining them is very performance and memory intensive so the same
/// (readonly) data arrays are passed arround together with their lower and upper bounds.
/// This circumstance makes the LCS and SMS functions more complicate.
/// I added some code to the LCS function to get a fast response on sub-arrays that are identical,
/// completely deleted or inserted.
/// 
/// The result from a comparisation is stored in 2 arrays that flag for modified (deleted or inserted)
/// lines in the 2 data arrays. These bits are then analysed to produce a array of Item objects.
/// 
/// Further possible optimizations:
/// (first rule: don't do it; second: don't do it yet)
/// The arrays DataA and DataB are passed as parameters, but are never changed after the creation
/// so they can be members of the class to avoid the paramter overhead.
/// In SMS is a lot of boundary arithmetic in the for-D and for-k loops that can be done by increment
/// and decrement of local variables.
/// The DownVector and UpVector arrays are alywas created and destroyed each time the SMS gets called.
/// It is possible to reuse tehm when transfering them to members of the class.
/// See TODO: hints.
/// 
/// diff.cs: A port of the algorythm to C#
/// 
/// Software License Agreement (BSD License)
/// Copyright (c) 2005-2009 by Matthias Hertel, http://www.mathertel.de/
///
/// All rights reserved.
///
/// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
/// 
/// Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
/// Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
/// Neither the name of the copyright owners nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
/// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
///
/// Changes:
/// 2002.09.20 There was a "hang" in some situations.
/// Now I undestand a little bit more of the SMS algorithm. 
/// There have been overlapping boxes; that where analyzed partial differently.
/// One return-point is enough.
/// A assertion was added in CreateDiffs when in debug-mode, that counts the number of equal (no modified) lines in both arrays.
/// They must be identical.
/// 
/// 2003.02.07 Out of bounds error in the Up/Down vector arrays in some situations.
/// The two vetors are now accessed using different offsets that are adjusted using the start k-Line. 
/// A test case is added. 
/// 
/// 2006.03.05 Some documentation and a direct Diff entry point.
/// 
/// 2006.03.08 Refactored the API to static methods on the Diff class to make usage simpler.
/// 2006.03.10 using the standard Debug class for self-test now.
///            compile with: csc /target:exe /out:diffTest.exe /d:DEBUG /d:TRACE /d:SELFTEST Diff.cs
/// 2007.01.06 license agreement changed to a BSD style license.
/// 2007.06.03 added the Optimize method.
/// 2007.09.23 UpVector and DownVector optimization by Jan Stoklasa ().
/// 2008.05.31 Adjusted the testing code that failed because of the Optimize method (not a bug in the diff algorithm).
/// 2008.10.08 Fixing a test case and adding a new test case.
/// 2010.06.27 C++ port by Eric Wasylishen
/// </summary>

#ifndef Difference_H
#define Difference_H

#include <vector>

namespace ManagedFusion
{
	class Range
	{
	public:
		size_t location;
		size_t length; 
		
		Range(size_t p, size_t l) : location(p), length(l) {}
		bool contains(size_t p) const
		{
			return p >= location && p <= (location + length);
		}
		bool intersects(Range const& r) const
		{
			return contains(r.location) || r.contains(location);
		}
	};
	
	/// <summary>Data on one input file being compared.</summary>
	template <class T>
	class DiffData
	{
	public:
		/// <summary>Number of elements (lines).</summary>
		size_t Length;
		
		/// <summary>Refence to collection of elements that will be compared.</summary>
		T &data;
		
		/// <summary>
		/// Vector of ranges that flag for modified data.
		/// This is the result of the diff.
		/// This means deleted in the first Data or inserted in the second Data.
		/// </summary>
		std::vector<Range> modified;
		
		/// <summary>
		/// Add a range to the modified vector. 
		/// If the range being added touches the last range in the vector,
		/// simply extend the last range.
		/// </summary>
		void addRange(Range const& r)
		{
			size_t l = modified.size();
			if (l > 0)
			{
				Range last = modified[l-1];
				if (last.location + last.length == r.location)
				{
					modified[l-1].length += r.length;
					return;
				}
			}
			modified.push_back(r);
		}
		
		/// <summary>
		/// Initialize the Diff-Data buffer.
		/// </summary>
		/// <param name="data">reference to the buffer</param>
		DiffData(T &initData, int size) : Length(size), data(initData)
		 {}
	};
	
	enum DifferenceType {
		INSERTION,
		DELETION,
		MODIFICATION
	};
	
	/// <summary>details of one difference.</summary>
	class DifferenceItem
	{
	public:
		enum DifferenceType type;
		Range rangeInA;
		Range rangeInB;
		DifferenceItem(DifferenceType t, Range a, Range b) :
		type(t), rangeInA(a), rangeInB(b) {}
	};
	
	/// <summary>
	/// Shortest Middle Snake Return Data
	/// </summary>
	class SMSRD
	{
	public:
		int x, y;
		// int u, v;  // 2002.09.20: no need for 2 points 
	};
	
	
	/// <summary>
	/// If a sequence of modified lines starts with a line that contains the same content
	/// as the line that appends the changes, the difference sequence is modified so that the
	/// appended line and not the starting line is marked as modified.
	/// This leads to more readable diff sequences when comparing text files.
	/// </summary>
	/// <param name="Data">A Diff data buffer containing the identified changes.</param>
	template <class T>
	void Optimize(DiffData<T> &Data)
	{
		int StartPos, EndPos;
		
		StartPos = 0;
		for (size_t i=0; i<Data.modified.length(); i++)
		{
			StartPos = Data.modified[i].location;
			EndPos = Data.modified[i].location + Data.modified[i].length;
			if ((EndPos < Data.Length) && (Data.data.equal(StartPos, EndPos)))
			{
				Data.modified[i].location++;
			}
		}
	}
	
	
	/// <summary>
	/// Find the difference in 2 arrays of integers.
	/// </summary>
	/// <param name="ArrayA">A-version of the numbers (usualy the old one)</param>
	/// <param name="ArrayB">B-version of the numbers (usualy the new one)</param>
	/// <returns>Returns a array of Items that describe the differences.</returns>
	template <class T>
	std::vector<ManagedFusion::DifferenceItem> Diff(T &Arrays, size_t sizeA, size_t sizeB)
	{
		// The A-Version of the data (original data) to be compared.
		DiffData<T> DataA(Arrays, sizeA);
		
		// The B-Version of the data (modified data) to be compared.
		DiffData<T> DataB(Arrays, sizeB);
		
		size_t MAX = DataA.Length + DataB.Length + 1;
		/// vector for the (0,0) to (x,y) search
		std::vector<int> DownVector(2 * MAX + 2);
		/// vector for the (u,v) to (N,M) search
		std::vector<int> UpVector(2 * MAX + 2);
		
		LCS(DataA, 0, DataA.Length, DataB, 0, DataB.Length, DownVector, UpVector);
		return CreateDiffs(DataA, DataB);
	}
	
	
	/// <summary>
	/// This is the algorithm to find the Shortest Middle Snake (SMS).
	/// </summary>
	/// <param name="DataA">sequence A</param>
	/// <param name="LowerA">lower bound of the actual range in DataA</param>
	/// <param name="UpperA">upper bound of the actual range in DataA (exclusive)</param>
	/// <param name="DataB">sequence B</param>
	/// <param name="LowerB">lower bound of the actual range in DataB</param>
	/// <param name="UpperB">upper bound of the actual range in DataB (exclusive)</param>
	/// <param name="DownVector">a vector for the (0,0) to (x,y) search. Passed as a parameter for speed reasons.</param>
	/// <param name="UpVector">a vector for the (u,v) to (N,M) search. Passed as a parameter for speed reasons.</param>
	/// <returns>a MiddleSnakeData record containing x,y and u,v</returns>
	template <class T>
	SMSRD SMS(DiffData<T> &DataA, int LowerA, int UpperA, DiffData<T> &DataB, int LowerB, int UpperB,
			  std::vector<int> &DownVector, std::vector<int> &UpVector)
	{
		
		SMSRD ret;
		int MAX = DataA.Length + DataB.Length + 1;
		
		int DownK = LowerA - LowerB; // the k-line to start the forward search
		int UpK = UpperA - UpperB; // the k-line to start the reverse search
		
		int Delta = (UpperA - LowerA) - (UpperB - LowerB);
		bool oddDelta = (Delta & 1) != 0;
		
		// The vectors in the publication accepts negative indexes. the vectors implemented here are 0-based
		// and are access using a specific offset: UpOffset UpVector and DownOffset for DownVektor
		int DownOffset = MAX - DownK;
		int UpOffset = MAX - UpK;
		
		int MaxD = ((UpperA - LowerA + UpperB - LowerB) / 2) + 1;
		
		// Debug.Write(2, "SMS", String.Format("Search the box: A[{0}-{1}] to B[{2}-{3}]", LowerA, UpperA, LowerB, UpperB));
		
		// init vectors
		DownVector[DownOffset + DownK + 1] = LowerA;
		UpVector[UpOffset + UpK - 1] = UpperA;
		
		for (int D = 0; D <= MaxD; D++)
		{
			
			// Extend the forward path.
			for (int k = DownK - D; k <= DownK + D; k += 2)
			{
				// Debug.Write(0, "SMS", "extend forward path " + k.ToString());
				
				// find the only or better starting point
				int x, y;
				if (k == DownK - D)
				{
					x = DownVector[DownOffset + k + 1]; // down
				}
				else
				{
					x = DownVector[DownOffset + k - 1] + 1; // a step to the right
					if ((k < DownK + D) && (DownVector[DownOffset + k + 1] >= x))
						x = DownVector[DownOffset + k + 1]; // down
				}
				y = x - k;
				
				// find the end of the furthest reaching forward D-path in diagonal k.
				while ((x < UpperA) && (y < UpperB) && (DataA.data.equal(x, y)))
				{
					x++;
					y++;
				}
				DownVector[DownOffset + k] = x;
				
				// overlap ?
				if (oddDelta && (UpK - D < k) && (k < UpK + D))
				{
					if (UpVector[UpOffset + k] <= DownVector[DownOffset + k])
					{
						ret.x = DownVector[DownOffset + k];
						ret.y = DownVector[DownOffset + k] - k;
						// ret.u = UpVector[UpOffset + k];      // 2002.09.20: no need for 2 points 
						// ret.v = UpVector[UpOffset + k] - k;
						return (ret);
					} // if
				} // if
				
			} // for k
			
			// Extend the reverse path.
			for (int k = UpK - D; k <= UpK + D; k += 2)
			{
				// Debug.Write(0, "SMS", "extend reverse path " + k.ToString());
				
				// find the only or better starting point
				int x, y;
				if (k == UpK + D)
				{
					x = UpVector[UpOffset + k - 1]; // up
				}
				else
				{
					x = UpVector[UpOffset + k + 1] - 1; // left
					if ((k > UpK - D) && (UpVector[UpOffset + k - 1] < x))
						x = UpVector[UpOffset + k - 1]; // up
				} // if
				y = x - k;
				
				while ((x > LowerA) && (y > LowerB) && (DataA.data.equal(x - 1, y - 1)))
				{
					x--;
					y--; // diagonal
				}
				UpVector[UpOffset + k] = x;
				
				// overlap ?
				if (!oddDelta && (DownK - D <= k) && (k <= DownK + D))
				{
					if (UpVector[UpOffset + k] <= DownVector[DownOffset + k])
					{
						ret.x = DownVector[DownOffset + k];
						ret.y = DownVector[DownOffset + k] - k;
						// ret.u = UpVector[UpOffset + k];     // 2002.09.20: no need for 2 points 
						// ret.v = UpVector[UpOffset + k] - k;
						return (ret);
					} // if
				} // if
				
			} // for k
			
		} // for D
		
		throw "the algorithm should never come here.";
	} // SMS
	
	/// <summary>
	/// This is the divide-and-conquer implementation of the longes common-subsequence (LCS) 
	/// algorithm.
	/// The published algorithm passes recursively parts of the A and B sequences.
	/// To avoid copying these arrays the lower and upper bounds are passed while the sequences stay constant.
	/// </summary>
	/// <param name="DataA">sequence A</param>
	/// <param name="LowerA">lower bound of the actual range in DataA</param>
	/// <param name="UpperA">upper bound of the actual range in DataA (exclusive)</param>
	/// <param name="DataB">sequence B</param>
	/// <param name="LowerB">lower bound of the actual range in DataB</param>
	/// <param name="UpperB">upper bound of the actual range in DataB (exclusive)</param>
	/// <param name="DownVector">a vector for the (0,0) to (x,y) search. Passed as a parameter for speed reasons.</param>
	/// <param name="UpVector">a vector for the (u,v) to (N,M) search. Passed as a parameter for speed reasons.</param>
	template <class T>
	void LCS(DiffData<T> &DataA, int LowerA, int UpperA, DiffData<T> &DataB, int LowerB, int UpperB, std::vector<int> &DownVector, std::vector<int> &UpVector)
	{
		// Debug.Write(2, "LCS", String.Format("Analyse the box: A[{0}-{1}] to B[{2}-{3}]", LowerA, UpperA, LowerB, UpperB));
		
		// Fast walkthrough equal lines at the start
		while (LowerA < UpperA && LowerB < UpperB && DataA.data.equal(LowerA, LowerB))
		{
			LowerA++;
			LowerB++;
		}
		
		// Fast walkthrough equal lines at the end
		while (LowerA < UpperA && LowerB < UpperB && DataA.data.equal(UpperA - 1, UpperB - 1))
		{
			--UpperA;
			--UpperB;
		}
		
		if (LowerA == UpperA)
		{
			// mark as inserted lines.
			//while (LowerB < UpperB)
			//  DataB.modified[LowerB++] = true;
			DataB.addRange(Range(LowerB, UpperB-LowerB)); // FIXME: off by 1?  
			
		}
		else if (LowerB == UpperB)
		{
			// mark as deleted lines.
			//while (LowerA < UpperA)
			//  DataA.modified[LowerA++] = true;
			DataA.addRange(Range(LowerA, UpperA-LowerA)); // FIXME: off by 1?  
		}
		else
		{
			// Find the middle snakea and length of an optimal path for A and B
			SMSRD smsrd = SMS<T>(DataA, LowerA, UpperA, DataB, LowerB, UpperB, DownVector, UpVector);
			// Debug.Write(2, "MiddleSnakeData", String.Format("{0},{1}", smsrd.x, smsrd.y));
			
			// The path is from LowerX to (x,y) and (x,y) to UpperX
			LCS<T>(DataA, LowerA, smsrd.x, DataB, LowerB, smsrd.y, DownVector, UpVector);
			LCS<T>(DataA, smsrd.x, UpperA, DataB, smsrd.y, UpperB, DownVector, UpVector);  // 2002.09.20: no need for 2 points 
		}
	} // LCS()
	
	/// <summary>Scan the tables of which lines are inserted and deleted,
	/// producing an edit script in forward order.  
	/// </summary>
	/// dynamic array
	template <class T>
	std::vector<DifferenceItem> CreateDiffs(DiffData<T> &DataA, DiffData<T> &DataB)
	{
		std::vector<DifferenceItem> result;
		
		int i=0, j=0;
		int offset=0;
		while (i < DataA.modified.size() || j < DataB.modified.size())
		{
			if ((i < DataA.modified.size() && j < DataB.modified.size()) && DataA.modified[i].location == DataB.modified[j].location + offset)
			{
				DifferenceItem it(MODIFICATION, DataA.modified[i], DataB.modified[j]);
				result.push_back(it);
				offset += (DataA.modified[i].length - DataB.modified[j].length);
				i++;
				j++;
			}
			else if ((j == DataB.modified.size()) || (i < DataA.modified.size() && DataA.modified[i].location < DataB.modified[j].location + offset))
			{
				DifferenceItem it(DELETION, DataA.modified[i], Range(0,0));
				result.push_back(it);
				offset += DataA.modified[i].length;
				i++;
			}
			else // (DataA.modified[i].location > DataB.modified[j].location + offset)
			{
				DifferenceItem it(INSERTION, Range(DataB.modified[j].location + offset, 0), DataB.modified[j]);
				result.push_back(it);
				offset -= DataB.modified[j].length;
				j++;
			}
		}
		return result;
	}
} // namespace ManagedFusion

#endif
