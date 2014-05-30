#!/bin/bash
pandoc --template=template.html --toc index.md -o index.html

#for file in *.png; do
#	mogrify -trim -matte -bordercolor none -border 10 $file
#done

#for file in *.png; do
#	mogrify -trim -matte -bordercolor none -border 10 $file
#	convert $file -fuzz 10% -transparent white $file
#done
