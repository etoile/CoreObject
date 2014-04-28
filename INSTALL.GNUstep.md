CoreObject GNUstep INSTALL
==========================

Required software
-----------------

You need to have the GNUstep core libraries installed in order to compile and 
use CoreObject, see <http://www.gnustep.org/>. The core packages are, at a minimum:

  - gnustep-make 2.6.6 or higher
  - gnustep-base trunk
  - gnustep-gui recent release
  - gnustep-back recent release

**Note**: GNUstep GUI and Back dependencies are temporary.

You also need to have the SQLite and EtoileFoundation libraries installed:

  - libsqlite 3.7.7, see <http://www.sqlite.org/>
  - EtoileFoundation, see <https://github.com/etoile/EtoileFoundation>

**Note:** If you have the entire Etoile repository, EtoileFoundation is built 
together with CoreObject, by running 'make' in Frameworks or any other parent 
directories.


Build and Install
-----------------

Square brackets "[ ]" are used to indicate optional parameters.

To build and install the CoreObject framework (use gmake on non-GNU systems):

	make
	
	[sudo [-E]] make install


Test suite
----------

UnitKit is required, see <https://github.com/etoile/UnitKit>

**Note:** If you have the entire Etoile repository, UnitKit is built together 
with CoreObject, by running 'make' in Frameworks or any other parent directories.

Square brackets "[ ]" are used to indicate optional parameters.

To produce a test bundle and run the test suite:

	make test=yes 
	
	ukrun [-q]
	
In addition, the project includes a benchmark suite built as a test bundle. To 
build and run it:

	make benchmark=yes
	
	ukrun [-q] BenchmarkCoreObject.bundle


Trouble
-------

Give us feedback! Tell us what you like; tell us what you think could be better. 
Send bug reports and patches to <https://github.com/etoile/CoreObject>.
