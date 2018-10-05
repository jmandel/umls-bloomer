#!/bin/bash

cat sqlite/umls-init.config  | sqlite3 output/umls.sqlite
cat scratch/subset/MRREL.RRF | sqlite3 --init sqlite/mrrel_file.config output/umls.sqlite
cat scratch/subset/MRCONSO.RRF | sed "s/\"/'/g" | sqlite3 --init sqlite/mrconso_file.config output/umls.sqlite
cat sqlite/umls-finish.config  | sqlite3 output/umls.sqlite
