#!/bin/bash

# check out dependencies in the parent directory
cd ..

if [ -e "EtoileFoundation" ]
then
  echo "You already have EtoileFoundation in the parent directory of CoreObject. This script is meant to be run in a fresh "
  echo "checkout of CoreObject on a continuous integration server."
  exit 1
fi

git clone https://github.com/etoile/UnitKit
git clone https://github.com/etoile/EtoileFoundation

# build & run the tests
cd CoreObject
./testcoreobject-macosx.sh
