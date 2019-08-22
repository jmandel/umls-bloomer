In current notebook:
```
cpt_for_pama = ConceptBuilder.new("CPT", db).query_types_in(["PT"], cms_cpt_codes)
write_filter_to_file(cpt_for_pama, "./output/cpt-for-pama")
```




SNOMED CT Core Problem List:

Download and extract:
https://download.nlm.nih.gov/umls/kss/SNOMEDCT_CORE_SUBSET/SNOMEDCT_CORE_SUBSET_201905.zip



```
import json

f = open("SNOMEDCT_CORE_SUBSET_201905.txt").readlines()[1:]
json.dump({
    "resourceType": "ValueSet",
    "expansion": {
        "conains": [{"system": "http://snomed.info/sct",
                     "code": v.split("|")[0],
                     "display": v.split("|")[1]} for v in f]
    }
}, open("output/pama-reason-codes.json", "w"))
```

Then

    cat output/pama-reason-codes.json  | jq '.' --sort-keys '.expansion.contains |= sort_by(.code)' > ~/work/sandbox/src/assets/pama-reason-codes.json
