#!/bin/sh

if [ -d config.h ]; then
   echo "Configuring UUID..."
   ./configure
else
   echo "UUID Configured"
fi

if [ -d config.h ]; then
   echo "UUID Configuration failed"
   exit 0
fi

echo "Building UUID"
make -f Makefile

