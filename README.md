# UMLS Bloom Filter Builder

```
docker build  -t umls .

docker run --rm \
    -v $(pwd):/opt/node \
    -e UMLS_USERNAME=myusername \
    -e UMLS_PASSWORD=mypassword \
    umls ./01-download.py

01-download.py  02-subset.sh  03-create-sqlite.sh  04-generate.rb

docker run --rm \
    -v $(pwd):/opt/node \
    umls ./02-subset.sh

docker run --rm \
    -v $(pwd):/opt/node \
    umls ./03-create-sqlite.sh

docker run --rm \
    -v $(pwd):/opt/node \
    umls ./04-generate-bloom-filters.sh
```
