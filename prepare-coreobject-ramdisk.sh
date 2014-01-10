#!/bin/sh

mkdir -p /tmp/coreobject-ramdisk
sudo mount -t tmpfs -o size=512M tmpfs /tmp/coreobject-ramdisk/
