# UMLS Bloom Filter Builder

```
docker build  -t umls .

docker run \
    --rm \
    -v $(pwd):/opt/node \
    -e UMLS_USERNAME=myusername \
    -e UMLS_PASSWORD=mypassword \
    umls ./01-download.py

docker run \
    --rm \
    -v $(pwd):/opt/node \
    umls ./02-extract.sh

docker run \
    --rm \
    -v $(pwd):/opt/node \
    umls ./03-generate.rb

```
