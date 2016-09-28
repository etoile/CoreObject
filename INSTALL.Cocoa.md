CoreObject macOS and iOS INSTALL
================================

Required software
-----------------

CoreObject requires the following:

  - macOS 10.8 or higher
  - Xcode 4.6 or higher
  - [libsqlite](http://www.sqlite.org/) 3.7.7 or higher (included with macOS 10.8)
  - [EtoileFoundation](https://github.com/etoile/EtoileFoundation)
  - [UnitKit](https://github.com/etoile/UnitKit) (Only required for running the test suite)

You can either get CoreObject and its dependencies from git:

    git clone https://github.com/etoile/CoreObject.git
    git clone https://github.com/etoile/EtoileFoundation.git
    git clone https://github.com/etoile/UnitKit.git

(The Xcode projects require that these three repos are cloned into the same directory.)

Or, get the entire [Étoilé repository](https://github.com/etoile/Etoile), which has
a script to check out CoreObject and all of the other Etoile frameworks.

**Warning:** There is no iOS support yet.


Build and Install
-----------------

For a simple build, open CoreObject.xcodeproj and choose CoreObject or 
CoreObject (iOS) in the Scheme menu. EtoileFoundation and UnitKit will be built 
together with CoreObject (as workspace subprojects).

To run a simple example, open CoreObject.xcodeproj and choose BasicPersistence 
or BasicPersistence (iOS) in the Scheme menu.

For a more complex demo, open Samples/ProjectDemo/ProjectDemo.xcodeproj and 
choose ProjectDemo in the Scheme menu.

Framework Installation
----------------------

We don't recommend installing frameworks on macOS, but if you want to,
the following shell command will install CoreObject.framework in /Library/Frameworks:

    sudo xcodebuild -scheme CoreObject -configuration Release clean install DSTROOT=/Library INSTALL_PATH=/Frameworks

**Note:** By default, INSTALL_PATH is set to @rpath and DSTROOT to the project 
directory.

iOS support
-----------

To build a CoreObject-based application, include CoreObject.xcodeproject in your 
project's workspace, then include the CoreObject/English.lproj directory 
content among your project resources, and link libCoreObject.a and its dependencies:

 - libSystem.dylib
 - libsqlite3.dylib
 - Foundation.framwework
 - CoreGraphics.framework
 - UIKit.framework

You are now ready to use CoreObject by  importing CoreObject.h as you would usually:

#import <CoreObject/CoreObject.h>

For a concrete example, check BasicPersistence (iOS) target.


Test suite
----------

**Note:** If you have the entire Etoile repository, UnitKit is built together 
with CoreObject (as a workspace subproject).

To produce a test bundle and run the test suite, open CoreObject.xcodeproj and 
choose TestCoreObject or TestCoreObject (iOS) in the Scheme menu.

In addition, the Xcode project includes a benchmark suite built as a test 
bundle. To run it, open CoreObject.xcodeproj and choose BenchmarkCoreObject in 
the Scheme menu.


Trouble
-------

Give us feedback! Tell us what you like; tell us what you think could be better. 
Send bug reports and patches to <https://github.com/etoile/CoreObject>.
