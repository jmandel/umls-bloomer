#!/bin/bash

cd scratch
unzip umls.zip "2018AA-full/2018aa-1-meta.nlm"
cd 2018AA-full
mv 2018aa-1-meta.nlm 2018aa-1-meta.nlm.zip
unzip 2018aa-1-meta.nlm.zip "2018AA/META/MRCONSO.RRF.*.gz"
