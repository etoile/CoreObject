#if 0

void test()
{	
	/*
	just pasting this here:
	
	I’m still not sure how to model a QuArK (3D game level editor) project-like document with various revision control possibilities: revision control graph per map, for the entire project, and undo over all changes. What about undo in the editor vs undo in the project? What about two editor windows open on the same map, and undo for each? What about undo of editor (view) data (scrollbar position, selection, etc, that shouldn’t be stored directly in the model? ) What about branching the project vs branching a map? Linking and embedding cross map and cross project? That about covers all the problems I can think of right now...
		
		
		*/
		
	// game development pack <<persistent root>> // not normally modified.. maybe read-only?
	//  |
	//  |--prefabs
	//  |   |
	//  |   |-door <<persistent root>>
	//  |   |
	//  |   \-elevator <<persistent root>>
	//  |
	//  \--textures
	//      |
	//      |--brick
	//      |   |
	//      |   \--brick1 <<persistent root>>
	//      |
	//      \--metal
	//          |
	//          \--metal1 <<persistent root>>

	
	// my project <<persistent root>>
	//  |
	//  |--local resources
	//  |   |
	//  |   |--prefabs
	//  |   |   |
	//  |   |   |-staircase <<persistent root>>
	//  |   |   |
	//  |   |   \-button <<persistent root>>
	//  |   |
	//  |   \--textures
	//  |       |
	//  |       |--rock
	//  |       |   |
	//  |       |   \--rock1 <<persistent root>>
	//  |       |
	//  |       \--wood
	//  |           |
	//  |           \--wood1 <<persistent root>>
	//  | 
	//   \-levels
	//      |
	//      |--sketches
	//      |   |
	//      |   \--map1 <<persistent root>>
	//      |
	//      \--finished
	//          |
	//          \--map2 <<persistent root>>
}

#endif