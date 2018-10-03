FROM beevelop/nodejs-python-ruby:latest
COPY 01-download.py 02-extract.sh 03-generate.rb ./

RUN apt-get update && apt-get install -y zlib1g-dev libxml2

RUN pip install requests && \
    gem install fhir_dstu2_models && \
    gem install bloomer
