FROM beevelop/nodejs-python-ruby:latest

RUN apt-get update && apt-get install -y zlib1g-dev libxml2 sqlite3-dev

RUN pip install requests && \
    gem install fhir_dstu2_models && \
    gem install bloomer \
    gem install sqlite3

# https://github.com/docker-library/ruby/issues/45
ENV LANG=C.UTF-8

RUN useradd -r -u 1000 appuser
USER appuser
