#!/bin/bash

# check out dependencies in the parent directory
cd ..

if [ -e "EtoileFoundation" ]
then
  echo "You already have EtoileFoundation in the parent directory of CoreObject. This script is meant to be run in a fresh "
  echo "checkout of CoreObject on a continuous integration server."
  exit 1
fi

svn co svn://svn.gna.org/svn/etoile/trunk/Etoile/Frameworks/UnitKit
svn co svn://svn.gna.org/svn/etoile/trunk/Etoile/Frameworks/EtoileFoundation

# build & run the tests
cd CoreObject
./testcoreobject-macosx.sh
