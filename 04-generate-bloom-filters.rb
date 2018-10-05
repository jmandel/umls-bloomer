#!/usr/bin/ruby
#encoding: utf-8

require 'zlib'
require 'msgpack'
require 'digest/md5'
require 'bloomer/msgpackable'
require 'bloomer'
require 'sqlite3'
require 'fhir_dstu2_models'

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

count = 0
$count_by_source_vocabulary = Hash.new(0)
$all_by_source_vocabulary = Hash.new { |h, k| h[k] = [] }
db = SQLite3::Database.open "output/umls.sqlite"

class AncestryBuilder

  attr_accessor :sab, :system, :parents, :ancestry

  def initialize(sab, db)

    @sab = sab
    @system = $source_vocabulary_to_fhir_url[sab]

    @parents =  Hash.new {|h, k| h[k] = Set.new()}
    @ancestry = Hash.new {|h, k| h[k] = Set.new()}

    rels = db.execute("
      select c1.code, c2.code
      from
        mrrel r
        join mrconso c1 on c1.aui=r.aui1
        join mrconso c2 on c2.aui=r.aui2
      where r.rel='CHD' and r.SAB=?
      ",@sab) do |row|
      rparent,rchild = row
      @parents[rchild].add(rparent)
    end
    puts "Selected #{@sab} rels from db"
    aa_cached = {}

    @parents.keys.each do |root_code|
      @ancestry[root_code] = if aa_cached[root_code]
        aa_cached[root_code]
      else
        count=0
        ancestor_pool = Set.new()
        new_next_ancestors = Set.new([root_code])
        until new_next_ancestors.empty? do
          count+=1
          next_ancestors = Set.new()
          new_next_ancestors.each do |code|
            next_ancestors += @parents[code]
          end
          new_next_ancestors = next_ancestors - ancestor_pool
          ancestor_pool += new_next_ancestors
        end
        aa_cached[root_code] = ancestor_pool
        ancestor_pool
      end
    end
    puts "Populated ancestry for #{@sab}"
  end

  def to_coding(code)
    return {
        :system => @system,
        :code => code}
  end

  def subsumed_by(ancestor_code)
    count = 0
    members = Set.new()
    @ancestry.each do |code, ancestor_set|
      if ancestor_set.include? ancestor_code
        count +=1
        members.add(to_coding(code))
      end
    end
    return members
  end
end

t1 = Time.now
snomed_hierarchy = AncestryBuilder.new("SNOMEDCT_US", db)
t2 = Time.now
puts t2-t1

snomed_hierarchy.subsumed_by("404684003").take(10)

class ConceptBuilder
  def initialize(sab, db)
    @sab = sab
    @system = $source_vocabulary_to_fhir_url[sab]
    @db = db
  end
  
  def to_coding(code)
    return {
        :system => @system,
        :code => code}
  end

  def query_types(type_list)
    matching_concepts = Set.new
    type_list.each do |t|
      by_type = @db.execute("select code from MRCONSO where sab=? and tty=?", [@sab, t])
      matching_concepts += by_type.map {|cl| to_coding(cl[0])}
    end
    return matching_concepts
  end
  
  def query_all()
    matching_concepts = Set.new
    by_type = @db.execute("select code from MRCONSO where sab=?", [@sab])
    matching_concepts += by_type.map {|cl| to_coding(cl[0])}
    return matching_concepts
  end
end

ConceptBuilder.new("RXNORM", db).query_types(["GPCK", "BPCK"]).take(10)
ConceptBuilder.new("RXNORM", db).query_all().take(10)
ConceptBuilder.new("LNC", db).query_all().take(10)

$ancestry_builders = {
  'SNOMEDCT_US' => snomed_hierarchy
  }

def codes_for_valueset(vs_argonaut_codes, db)


  vs_set = Set.new
  puts "Num includes: #{vs_argonaut_codes.compose.include.count}"
  apply_filters = lambda do |vs_element, logtag|

    puts "include #{vs_element}: #{logtag}"
    required_system = vs_element.system
    raise "don't know system" unless $source_vocabulary_to_fhir_url.values.include?(required_system)

    required_key = ($source_vocabulary_to_fhir_url.select {|k,v| v == required_system}).keys[0]
    puts required_key
    raise "can't handle filter intersection" unless vs_element.filter.count <= 1

    if vs_element.filter.count == 0
      return ConceptBuilder.new(required_key, db).query_all()
    else
      filter = vs_element.filter[0]
      if filter.op == "in"
        return ConceptBuilder.new(required_key, db).query_types(filter.value.split(","))
      elsif filter.op == "is-a"
        return $ancestry_builders[required_key].subsumed_by(filter.value)
      end
    end
    puts "filter done with size: #{vs_set.count}"
  end

  vs_argonaut_codes.compose.include.each do |vs_include|
    vs_set += apply_filters.(vs_include, :include)
  end

  vs_argonaut_codes.compose.exclude.each do |vs_exclude|
    vs_set -= apply_filters.(vs_exclude, :exclude)
  end

  puts vs_set.count
  return vs_set
end


def write_filter_to_file(vs_set, output_file)
  vs_array = vs_set.to_a.map do |v|
      {
        :system => v[:system],
        :code => v[:code],
        }
  end

  Zlib::GzipWriter.open(output_file+".json.gz") { |gz| gz.write ({
    "resourceType"=> "ValueSet",
    "expansion"=> vs_array
  }).to_json}

  expected_size = 100
  false_positive_probability = 0.001

  vs_bloom = Bloomer::Scalable.new(expected_size, false_positive_probability)
  vs_array.each do |coding|
    vs_bloom.add "#{coding[:system]}|#{coding[:code]}"
  end

  File.open(output_file+".msgpck", "w") do |f|
    f.write(vs_bloom.to_msgpack())
  end
end

manifest = {
  "filters"=> []
  }

[
  "daf-problem.canonical",
  "substance-sct",
  "medication-codes",
  "observation-codes",
  "observation-value-codes",
  "procedure-type"].each do |vs_json_file|
    vs = open("./inferno/resources/argonauts/ValueSet-#{vs_json_file}.json").read()
    vs = FHIR::DSTU2::Json.from_json(vs)
    vs_set = codes_for_valueset(vs, db)
    vs_url = vs.url
    write_filter_to_file(vs_set, "./output/valueset-#{vs_json_file}")
    manifest["filters"] << {
      "valueSetUrl" => vs_url,
      "probability"=> 0.001,
      "file"=> "valueset-#{vs_json_file}.msgpck"
    }
end

all_umls_terms = Set.new
$source_vocabulary_to_fhir_url.keys.each do |k|
  puts k
  these_terms = ConceptBuilder.new(k, db).query_all()
  write_filter_to_file(these_terms, "./output/all-#{k.downcase}")
  all_umls_terms += these_terms
  manifest["filters"] << {
    "codeSystemUrl" => $source_vocabulary_to_fhir_url[k],
    "probability"=> 0.001,
    "file"=> "all-#{k.downcase}.msgpck"
  }

end
write_filter_to_file(all_umls_terms, "./output/all-umls-terms")

open("./output/manifest.json", "w") { |mfile| mfile.write(JSON.pretty_generate manifest) }

0
