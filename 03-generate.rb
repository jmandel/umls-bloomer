#!/usr/bin/ruby
#encoding: utf-8

#
##system 'gem install bloomer --user-install'
#system 'gem install fhir_dstu2_models --user-install'

require 'bloomer/msgpackable'
require 'digest/md5'
require 'fhir_dstu2_models'
require 'msgpack'
require 'bloomer'
require 'zlib'

$source_vocabulary_to_fhir_url = {
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

$count_by_source_vocabulary = Hash.new(0)
$all_by_source_vocabulary = Hash.new { |h, k| h[k] = [] }

idx_termtype = 2
idx_source_vocabulary = 11
idx_source_tty = 12
idx_source_code = 13
idx_display = 14

all_codes = []
for infile in Dir["2018AA-full/2018AA/META/MRCONSO.RRF.*.gz"]
  puts "test", infile
  gz = Zlib::GzipReader.new(open(infile))
  gz.each_line do |line|
    parts = line.split("|")
    # only keep preferred terms
    if parts[idx_termtype] != 'P'
      next
    end
    $count_by_source_vocabulary[parts[idx_source_vocabulary]] += 1
    if $source_vocabulary_to_fhir_url.key?(parts[idx_source_vocabulary])
      coding_system = $source_vocabulary_to_fhir_url[parts[idx_source_vocabulary]]
      coding_code = parts[idx_source_code]
      coding_display = parts[idx_display]
      tty = parts[idx_source_tty]
      $all_by_source_vocabulary[parts[idx_source_vocabulary]].push({
        :system => coding_system,
        :code => coding_code,
        :display => coding_display,
        :tty => parts[idx_source_tty]
      })
    end
  end
end


def include_codes_in_filter(vs_array, vocab_key, property, values)
  $all_by_source_vocabulary.each do |one_vocab_key, terms|
    next if vocab_key != '*' and vocab_key != one_vocab_key
    terms.each do |coding|
      if values == "*" or values.include? coding[property]
        vs_array.push(coding)
      end
    end
  end
end

$count_by_source_vocabulary.each do |k,c|
  if $source_vocabulary_to_fhir_url.key?(k)
    puts "#{k}\t\t\t#{c}"
  end
end


def write_filter_to_file(vs_array, output_file)
  Zlib::GzipWriter.open(output_file+".json.gz") { |gz| gz.write ({
    "resourceType"=> "ValueSet",
    "expansion"=> vs_array.map do |v|
      {
        :system => v[:system],
        :code => v[:code],
        :display => v[:display]
        }
    end
    }).to_json }

  expected_size = 100
  false_positive_probability = 0.0001

  vs_bloom = Bloomer::Scalable.new(expected_size, false_positive_probability)
  vs_array.each do |coding|
    vs_bloom.add "#{coding[:system]}|#{coding[:code]}"
  end

  File.open(output_file+".msgpck", "w") do |f|
    f.write(vs_bloom.to_msgpack())
  end
end

def bloom_filter_for_valueset(valueset_filename, output_file)
  vs_argonaut_codes_str = open(valueset_filename).read()
  vs_argonaut_codes = FHIR::DSTU2::Json.from_json(vs_argonaut_codes_str)
  vs_array = []

  vs_argonaut_codes.compose.include.each do |vs_include|
    required_system = vs_include.system
    raise "don't know system" unless $source_vocabulary_to_fhir_url.values.include?(required_system)

    required_key = ($source_vocabulary_to_fhir_url.select {|k,v| v == required_system}).keys[0]
    puts required_key
    raise "can't handle filter intersection" unless vs_include.filter.count <= 1
    if vs_include.filter.count == 0
      filter_property = nil
      filter_values = "*"
    else
      filter = vs_include.filter[0]
      if filter.op == "in"
        filter_property = filter.property.downcase.to_sym
        filter_values = filter.value.split(",")
      else
        puts "backing out for #{output_file} because of op"
        filter_values = "*"
      end
    end 
    puts(filter_property, filter_values)
    include_codes_in_filter(vs_array, required_key, filter_property, filter_values)
  end
  write_filter_to_file(vs_array, output_file)
  puts "#{output_file}: #{vs_array.count}"
end

[
  "ValueSet-medication-codes",
  "ValueSet-observation-codes",
  "ValueSet-procedure-type"
].each do |vs_filename|
  bloom_filter_for_valueset("./inferno/resources/argonauts/#{vs_filename}.json", "output/#{vs_filename}")
end
