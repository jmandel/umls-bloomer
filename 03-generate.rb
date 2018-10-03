#!/usr/bin/ruby
#system 'gem install bloomer --user-install'

require 'zlib'
require 'msgpack'
require 'digest/md5'
require 'bloomer/msgpackable'

source_vocabulary_to_fhir_url = {
    'RXNORM'=> 'http://www.nlm.nih.gov/research/umls/rxnorm',
    'LNC'=> 'http://loinc.org',
    'SNOMEDCT_US'=> 'http://snomed.info/sct',
    'NCI_UCUM'=> 'http://unitsofmeasure.org',
    'CPT'=> 'http://www.ama-assn.org/go/cpt',
    'NDFRT'=> 'http://hl7.org/fhir/ndfrt',
    'CVX'=> 'http://hl7.org/fhir/sid/cvx',
    'DSM-5'=> 'http://hl7.org/fhir/sid/dsm5',
    'ICD9CM'=> 'http://hl7.org/fhir/sid/icd-9-cm',
    'ICD10CM'=> 'http://hl7.org/fhir/sid/icd-10',
    'ICF'=> 'http://hl7.org/fhir/sid/icf-nl',
    'ATC'=> 'http://www.whocc.no/atc',
    'NUCCPT'=> 'http://nucc.org/provider-taxonomy',
    'OMIM'=> 'http://www.omim.org'
}

count = 0
count_by_source_vocabulary = Hash.new(0)

idx_termtype = 2
idx_source_vocabulary = 11

expected_size = 1_500_000
false_positive_probability = 0.001

umls_bloom = Bloomer::Scalable.new(expected_size, false_positive_probability)

count =  0
for infile in Dir["2018AA-full/2018AA/META/MRCONSO.RRF.*.gz"]
  puts "test", infile
  gz = Zlib::GzipReader.new(open(infile))
  gz.each_line do |line|
    parts = line.split("|")
    # only keep preferred terms
    if parts[idx_termtype] != 'P' 
      next
    end
    count_by_source_vocabulary[parts[idx_source_vocabulary]] += 1
    if source_vocabulary_to_fhir_url.key?(parts[idx_source_vocabulary])
      coding_system = source_vocabulary_to_fhir_url[parts[idx_source_vocabulary]]
      coding_code = parts[13]
      bval = "#{coding_system}|#{coding_code}"
      umls_bloom.add bval
    end
    count +=1
  end
end

puts umls_bloom.count

count_by_source_vocabulary.each do |k,c|
  if source_vocabulary_to_fhir_url.key?(k)
    puts "#{k}\t\t\t#{c}"
  end
end

File.open("umls_bloom.mpac", "w") do |f|
  f.write(umls_bloom.to_msgpack())
end
