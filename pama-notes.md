In current notebook:
```
cpt_for_pama = ConceptBuilder.new("CPT", db).query_types_in(["PT"], cms_cpt_codes)
write_filter_to_file(cpt_for_pama, "./output/cpt-for-pama")
```
