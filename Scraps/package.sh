#!/bin/bash

CHECKOUTDIR=coreobjectpackaging
ARCHIVENAME="CoreObject-0.5.tgz"

rm -fr $CHECKOUTDIR
mkdir $CHECKOUTDIR
cd $CHECKOUTDIR
git clone https://github.com/etoile/Etoile.git
git clone https://github.com/etoile/CoreObject.git
git clone https://github.com/etoile/EtoileFoundation.git
git clone https://github.com/etoile/UnitKit.git

cp Etoile/etoile.make CoreObject 
cp Etoile/etoile.make EtoileFoundation
cp Etoile/etoile.make UnitKit

rm -fr CoreObject/.git
rm -fr EtoileFoundation/.git
rm -fr UnitKit/.git

tar czvvf $ARCHIVENAME CoreObject EtoileFoundation UnitKit

rm -fr Etoile CoreObject EtoileFoundation UnitKit
cd ..

