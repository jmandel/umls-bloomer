#!/usr/bin/python

import gzip
from collections import defaultdict
import io
import os

root = "2018AA-full/2018AA/META/"
concept_prefix = "MRCONSO.RRF"
concept_filenames = [f for f in os.listdir(root) if f.startswith(concept_prefix)]
concept_filenames

source_vocabulary_to_fhir_url = {
    'RXNORM': 'http://www.nlm.nih.gov/research/umls/rxnorm',
    'LNC': 'http://loinc.org',
    'SNOMEDCT_US': 'http://snomed.info/sct',
    'NCI_UCUM': 'http://unitsofmeasure.org',
    'CPT': 'http://www.ama-assn.org/go/cpt',
    'NDFRT': 'http://hl7.org/fhir/ndfrt',
    'CVX': 'http://hl7.org/fhir/sid/cvx',
    'DSM-5': 'http://hl7.org/fhir/sid/dsm5',
    'ICD9CM': 'http://hl7.org/fhir/sid/icd-9-cm',
    'ICD10CM': 'http://hl7.org/fhir/sid/icd-10',
    'ICF': 'http://hl7.org/fhir/sid/icf-nl',
    'ATC': 'http://www.whocc.no/atc',
    'NUCCPT': 'http://nucc.org/provider-taxonomy',
    'OMIM': 'http://www.omim.org'
}

count = 0
count_by_source_vocabulary = defaultdict(int)

idx_termtype = 2
idx_source_vocabulary = 11

for fn in concept_filenames:
    with io.TextIOWrapper(io.BufferedReader(gzip.open(os.path.join(root, fn), 'rb'))) as f:
        for l in f:
            #if count > 10: break
            parts = l.split("|")
            if parts[idx_termtype] != 'P': continue
            count_by_source_vocabulary[parts[idx_source_vocabulary]] += 1
            #print(parts[idx_termtype], parts[idx_source_vocabulary])
            #print(parts)
            count +=1

print(count, count_by_source_vocabulary)
