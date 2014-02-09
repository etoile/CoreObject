CoreObject Mac OS X and iOS INSTALL
===================================

Required software
-----------------

In addition to Xcode 4.6 or higher, you need Mac OS X 10.7 or higher to compile 
and use CoreObject.

You also need to have the SQLite and EtoileFoundation libraries installed:

  - libsqlite 3.7.7 (the one bundled with Mac OS X 10.7), see <http://www.sqlite.org/>
  - EtoileFoundation, see <https://github.com/etoile/EtoileFoundation>

**Note:** If you have the entire Etoile repository, EtoileFoundation is built 
together with CoreObject (as a workspace subproject).

**Warning:** There is no iOS support yet.


Build and Install
-----------------

For a simple build, open CoreObject.xcodeproj and choose CoreObject in the 
Scheme menu.

To run a simple example, open CoreObject.xcodeproj and choose BasicPersistence 
in the Scheme menu.

For a more complex demo, open Samples/ProjectDemo/ProjectDemo.xcodeproj and 
choose ProjectDemo in the Scheme menu.

To install in /Library/Frameworks, do the build in the shell: 

	sudo xcodebuild -scheme CoreObject -configuration Release clean install DSTROOT=/Library INSTALL_PATH=/Frameworks

**Note:** By default, INSTALL_PATH is set to @rpath and DSTROOT to the project 
directory.


Test suite
----------

UnitKit is required, see <https://github.com/etoile/UnitKit>

**Note:** If you have the entire Etoile repository, UnitKit is built together 
with CoreObject (as a workspace subproject).

To produce a test bundle and run the test suite, open CoreObject.xcodeproj and 
choose TestCoreObject in the Scheme menu.

In addition, the Xcode project includes a benchmark suite built as a test 
bundle. To run it, open CoreObject.xcodeproj and choose BenchmarkCoreObject in 
the Scheme menu.


Trouble
-------

Give us feedback! Tell us what you like; tell us what you think
could be better. Send bug reports and patches to <bug-etoile@gna.org>.
