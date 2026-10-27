aa_register_case -cats {smoke production_safe} xowiki_json_fields {
  Typed export preserves stored values and recursively exports compound/repeated fields.
} {
  if {![::acs::icanuse "ns_json"]} {
    aa_log "Skipping JSON export tests: ns_json is unavailable"
    return
  }
  ::xo::library require -package xowiki json-procs
  set objects {}
  try {
    # Field specifications resolve package-dependent conditions through their
    # owning page, even when the specification itself is just "text".
    set package_id [::acs::test::require_package_instance -package_key xowiki]
    ::xowiki::Package initialize -package_id $package_id
    set page [::xowiki::Page new \
                  -package_id $package_id \
                  -parent_id [::$package_id folder_id]]
    lappend objects $page
    set text [::xowiki::formfield::FormField new -object $page -locale en_US -name text -spec text]
    lappend objects $text
    foreach value [list 00123 false "a\"b\\c\n\t<script>" ""] {
      aa_equals "text stays a string" [$text json_value $value] [list string $value]
      set json [ns_json value -type object [list text {*}[$text json_value $value]]]
      aa_equals "text survives JSON encoding" [dict get [::util::json2dict $json] text] $value
    }
    set flag [::xowiki::formfield::FormField new -object $page -locale en_US -name flag -spec boolean]
    lappend objects $flag
    aa_equals "true boolean" [$flag json_value t] {boolean true}
    aa_equals "false boolean" [$flag json_value f] {boolean false}
    aa_equals "empty boolean becomes null" [$flag json_value ""] {null {}}
    aa_equals "invalid boolean remains text" [$flag json_value invalid] {string invalid}
    set number [::xowiki::formfield::FormField new -object $page -locale en_US -name amount -spec numeric]
    lappend objects $number
    aa_equals "empty numeric becomes null" [$number json_value ""] {null {}}
    aa_equals "numeric zero is retained" [$number json_value 0] {number 0}
    aa_equals "numeric value" [$number json_value 12.5] {number 12.5}
    aa_equals "non-JSON number preserved" [$number json_value NaN] {string NaN}
    set nullable [list amount {*}[$number json_value ""] flag {*}[$flag json_value ""] text {*}[$text json_value ""]]
    aa_equals "typed nulls and empty text encoded distinctly" \
        [ns_json value -type object $nullable] {{"amount":null,"flag":null,"text":""}}
    $number set keep_string_rep 1
    aa_equals "empty numeric with keep_string_rep becomes null" [$number json_value ""] {null {}}
    aa_equals "localized string preserved" [$number json_value 1,5] {string 1,5}

    set compound [::xowiki::formfield::CompoundField new -object $page -locale en_US -name person]
    lappend objects $compound
    $compound create_components {{caption text} {enabled boolean}}
    aa_equals "compound uses component names and types" \
        [$compound json_value {person.caption 00123 person.enabled t person.old retained}] \
        {object {caption string 00123 enabled boolean true old string retained}}
    aa_equals "compound does not inject defaults" [$compound json_value {}] {object {}}
    aa_equals "retyped legacy value preserved" [$compound json_value invalid] {string invalid}

    set scalar_repeat [::xowiki::formfield::FormField new -object $page -locale en_US -name tags -spec "text,repeat=0..5"]
    lappend objects $scalar_repeat
    aa_equals "scalar repeat uses actual occurrence factory" \
        [$scalar_repeat json_value {tags.0 {} tags.3 third tags.1 first}] \
        {array {0 string first 1 string third}}
    set compound_class ::xowiki::formfield::json_test_compound
    ::xotcl::Class create $compound_class -superclass ::xowiki::formfield::CompoundField
    lappend objects $compound_class
    # A component called "label" would shadow the inherited label accessor:
    # repeat occurrence specifications invoke it through "label=<index>".
    $compound_class instproc initialize {} {
      :create_components {{caption text} {enabled boolean}}
      next
    }
    set repeat [::xowiki::formfield::FormField new -object $page -locale en_US -name people \
                    -spec "json_test_compound,repeat=0..20"]
    lappend objects $repeat
    aa_equals "repeat skips template, sorts numerically and recurses" \
        [$repeat json_value {
          people.0 template
          people.10 {people.10.caption ten people.10.enabled f}
          people.2 {people.2.caption two people.2.enabled t}
        }] \
        {array {0 object {caption string two enabled boolean true} 1 object {caption string ten enabled boolean false}}}
    aa_equals "empty repeat" [$repeat json_value {}] {array {}}
    aa_equals "template-only repeat" [$repeat json_value {people.0 template}] {array {}}
    set json [ns_json value -type object [list rows {*}[$repeat json_value {}]]]
    aa_equals "empty array is encoded as array" $json {{"rows":[]}}

    foreach policy {policy1 policy2 policy3 policy5} {
      aa_equals "$policy JSON requires site-wide admin" \
          [::xowiki::${policy}::Page set require_permission(json)] swa
    }

    foreach name {package_id parent_id creation_user modifying_user} {
      if {$name ne "package_id"} {$page set $name 704}
      aa_equals "$name uses numeric metadata" [$page json_attribute_type $name] number
    }
    $page set modifying_user ""
    foreach name {absolute_links do_substitutions render_adp} {
      $page set $name 1
      aa_equals "$name is boolean" [$page json_attribute_type $name] boolean
    }
    $page set name 00123
    $page set extra "a\nb"
    $page set __temporary secret
    set data [$page json_data]
    aa_true "all ordinary attributes are exported" [expr {[lsearch -exact $data extra] >= 0}]
    aa_false "transient attributes are omitted" [expr {[lsearch -exact $data __temporary] >= 0}]
    set pretty [$page as_json -pretty true]
    aa_true "pretty JSON has line breaks" [expr {[string first "\n" $pretty] >= 0}]
    aa_equals "pretty and compact JSON contain the same values" \
        [::util::json2dict $pretty] [::util::json2dict [$page as_json]]
    aa_true "empty optional ID is JSON null" \
        [string match {*"modifying_user":null*} [$page as_json]]
    aa_equals "page text preserved" [dict get [::util::json2dict [$page as_json]] name] 00123
  } finally {
    foreach object [lreverse $objects] {$object destroy}
  }
}
