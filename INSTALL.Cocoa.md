CoreObject Mac OS X and iOS INSTALL
===================================

Required software
-----------------

CoreObject requires the following:

  - Mac OS X 10.7 or higher
  - Xcode 4.6 or higher
  - [libsqlite](http://www.sqlite.org/) 3.7.7 or higher (included with Mac OS X 10.7)
  - [EtoileFoundation](https://github.com/etoile/EtoileFoundation)
  - [UnitKit](https://github.com/etoile/UnitKit) (Only required for running the test suite)

The Xcode projects require the CoreObject, EtoileFoundation, and UnitKit directories
to be siblings; e.g., a layout like the following:

    ~/dev/CoreObject
	~/dev/EtoileFoundation
	~/dev/UnitKit

EtoileFoundation and UnitKit will be built together with CoreObject (as a workspace subproject).

**Warning:** There is no iOS support yet.


Building
--------

For a simple build, open CoreObject.xcodeproj and choose CoreObject in the 
Scheme menu.

To run a simple example, open CoreObject.xcodeproj and choose BasicPersistence 
in the Scheme menu.

For a more complex demo, open Samples/ProjectDemo/ProjectDemo.xcodeproj and 
choose ProjectDemo in the Scheme menu.

Installation
------------

We don't recommend installing frameworks on OS X, but if you want to,
the following shell command will install CoreObject.framework in /Library/Frameworks:

	sudo xcodebuild -scheme CoreObject -configuration Release clean install DSTROOT=/Library INSTALL_PATH=/Frameworks

**Note:** By default, INSTALL_PATH is set to @rpath and DSTROOT to the project 
directory.


Test suite
----------



**Note:** If you have the entire Etoile repository, UnitKit is built together 
with CoreObject (as a workspace subproject).

To produce a test bundle and run the test suite, open CoreObject.xcodeproj and 
choose TestCoreObject in the Scheme menu.

In addition, the Xcode project includes a benchmark suite built as a test 
bundle. To run it, open CoreObject.xcodeproj and choose BenchmarkCoreObject in 
the Scheme menu.


Trouble
-------

Give us feedback! Tell us what you like; tell us what you think could be better. 
Send bug reports and patches to <https://github.com/etoile/CoreObject>.
