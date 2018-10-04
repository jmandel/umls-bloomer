#!/bin/bash

export CONFIG_FILE=$(pwd)/all-active.config.prop
export CLASSPATH=".:lib/jpf-boot.jar"
cd scratch
export SCRATCH_DIR=$(pwd)

unzip -o umls.zip
cd 20*
unzip mmsys.zip

./jre/linux/bin/java \
    -Djava.awt.headless=true \
    -Djpf.boot.config=./etc/subset.boot.properties \
    -Dlog4j.configuration=./etc/subset.log4j.properties \
    -Dinput.uri=. \
    -Doutput.uri=$SCRATCH_DIR \
    -Dmmsys.config.uri=$CONFIG_FILE \
    -Xms300M -Xmx8G \
    org.java.plugin.boot.Boot
