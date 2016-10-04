#!/bin/bash

set -o verbose

CLANG="clang-3.8"
CLANGXX="clang++-3.8"

# deps
sudo apt-get -y install libblocksruntime-dev libkqueue-dev libpthread-workqueue-dev cmake
sudo apt-get -y install libxml2-dev libxslt1-dev libffi-dev libssl-dev libgnutls-dev libicu-dev libgmp3-dev
sudo apt-get -y install libjpeg-dev libtiff-dev libpng-dev libgif-dev libx11-dev libcairo2-dev libxft-dev libxmu-dev 

# repos
git clone https://github.com/nickhutchinson/libdispatch.git
git clone https://github.com/gnustep/libobjc2
git clone https://github.com/gnustep/make
git clone https://github.com/gnustep/base
git clone https://github.com/gnustep/gui
git clone https://github.com/gnustep/back
git clone https://github.com/etoile/UnitKit
git clone https://github.com/etoile/EtoileFoundation

# libdispatch
cd libdispatch && git checkout bd1808980b04830cbbd79c959b8bc554085e38a1 && git clean -dfx
mkdir build && cd build
CC="$CLANG" CXX="$CLANGXX" ../configure && make && sudo make install || exit 1
cd ..
cd ..

# libobjc2
cd libobjc2 && git checkout 9a2f43ca7d579928279b5d854a19adfbe43d06d6 && git clean -dfx
mkdir build && cd build
CC="$CLANG" CXX="$CLANGXX" cmake .. -DCMAKE_BUILD_TYPE=Release -DLIBOBJC_NAME=objcgs
make -j8 || exit 1
sudo make install
cd ..
cd ..

# gnustep make
cd make && git checkout be209c7eaae9978bb694fdcc2541e1c89b528ce8 && git clean -dfx
CC="$CLANG" CXX="$CLANGXX" LDFLAGS=-L/usr/local/lib ./configure --enable-objc-nonfragile-abi --enable-objc-arc --with-objc-lib-flag=-lobjcgs --disable-strict-v2-mode || exit 1
make || exit 1
sudo make install
cd ..
source /usr/local/share/GNUstep/Makefiles/GNUstep.sh || exit 1

# gnustep base
cd base && git checkout 23a7a83dedf240ac52407426e791c8627116d59e && git clean -dfx
CC="$CLANG" CXX="$CLANGXX" LDFLAGS=-L/usr/local/lib ./configure || exit 1
make CC="$CLANG" CXX="$CLANGXX" && sudo -E make install || exit 1
cd ..

# gnustep gui
cd gui && git checkout 995effb347ee0da948840f1047c232c1a4231777 && git clean -dfx
CC="$CLANG" CXX="$CLANGXX" LDFLAGS=-L/usr/local/lib ./configure || exit 1
make CC="$CLANG" CXX="$CLANGXX" && sudo -E make install || exit 1
cd ..

# gnustep back
cd back && git checkout ef2088d3c7065418409cf1a6f53ac45e94eb5cb5 && git clean -dfx
CC="$CLANG" CXX="$CLANGXX" LDFLAGS=-L/usr/local/lib ./configure || exit 1
make CC="$CLANG" CXX="$CLANGXX" && sudo -E make install || exit 1
cd ..

# UnitKit
cd UnitKit && git clean -dfx
wget https://raw.githubusercontent.com/etoile/Etoile/master/etoile.make
make OBJCFLAGS="-fobjc-nonfragile-abi" && sudo -E make install || exit 1
cd ..

# EtoileFoundation
cd EtoileFoundation && git clean -dfx
wget https://raw.githubusercontent.com/etoile/Etoile/master/etoile.make
make OBJCFLAGS="-fobjc-nonfragile-abi" && sudo -E make install || exit 1
cd ..

# CoreObject
wget https://raw.githubusercontent.com/etoile/Etoile/master/etoile.make
make OBJCFLAGS="-fobjc-nonfragile-abi"
