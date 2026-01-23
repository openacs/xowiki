aa_register_case \
    -cats {smoke production_safe} \
    -procs {
        "::acs::test::require_package_instance"
        "::xo::PackageMgr instproc initialize"

        "::acs::root_of_host"
        "::ad_host"
        "::api_page_documentation_mode_p"
        "::auth::require_login"
        "::export_vars"
        "::site_node::get_url_from_object_id"
        "::xo::ConnectionContext instproc user_id"
        "::xo::Context instproc export_vars"
        "::xo::Context instproc original_url_and_query"
        "::xowiki::Package instproc normalize_path"
        "::xo::PackageMgr proc get_package_class_from_package_key"
        "::xo::PackageMgr instproc require"
        "::xowiki::Package instproc require_root_folder"
    } package_normalize_path {

        Checks various forms of the xowiki::Package API method
        "normalize_path".

    } {
        set package_id [acs::test::require_package_instance \
                            -package_key xowiki]
        ::xowiki::Package initialize -package_id $package_id

        #
        # Don't allow addressing outside of the jail
        #
        foreach pair {
            {"view-default" "view-default"}
            {"view-default/." "view-default"}
            {"./view-default/." "view-default"}
            {"../view-default/." "view-default"}
            {"../../view-default/." "view-default"}
            {"/../../view-default/." "view-default"}
            {".." ""}
            {"/../../view-default/../" ""}
            {"/etc/hosts" "etc/hosts"}
            {"//etc/hosts" "etc/hosts"}
            {"/../etc/hosts" "etc/hosts"}
            {"view-default/../../etc" "etc"}
            {"view-default/../../../../../etc" "etc"}
        } {
            lassign $pair path expected
            aa_equals "check $path -> $expected" [$package_id normalize_path $path] $expected
        }
    }


aa_register_case \
    -cats {api smoke production_safe} \
    -procs {
        "::xowiki::randomized_index"
        "::xowiki::randomized_indices"
    } \
    api_randomized {

        Checks randomization functions.

    } {
        #
        # Single random value, seeded or not.
        #
        aa_true "randomized index upper" {[::xowiki::randomized_index 10] < 10}
        aa_true "randomized index lower" {[::xowiki::randomized_index 10] >= 0}
        aa_equals "randomized index seeded: [::xowiki::randomized_index -seed 123 10]" \
            [::xowiki::randomized_index -seed 123 10] 1
        aa_equals "randomized index seeded: [::xowiki::randomized_index -seed 456 10]" \
            [::xowiki::randomized_index -seed 456 10] 8

        #
        # Randomized indices, seeded or not.
        #
        aa_equals "randomized indices [::xowiki::randomized_indices -seed 789 5]" \
            [::xowiki::randomized_indices -seed 789 5] {3 0 4 1 2}
        aa_equals "randomized indices min " \
            [::tcl::mathfunc::min {*}[::xowiki::randomized_indices 5]] 0
        aa_equals "randomized indices min " \
            [::tcl::mathfunc::max {*}[::xowiki::randomized_indices 5]] 4
    }

aa_register_case \
    -cats {api smoke production_safe} \
    -procs {
        "xowiki::filter_option_list"
    } \
    api_filter_option_list {

        Checks Option list filtering.

    } {
        set option_list {{label1 1} {label2 2} {label3 3}}
        aa_equals "filter option_list with empty exclusion set" \
            [xowiki::filter_option_list $option_list {}] $option_list
        aa_equals "filter option_list filter 2 existing values" \
            [xowiki::filter_option_list $option_list {1 3}] "{label2 2}"

        aa_equals "filter option_list filter all values" \
            [xowiki::filter_option_list $option_list {2 1 3}] ""
        aa_equals "filter option_list filter non-existing value" \
            [xowiki::filter_option_list $option_list {4}] $option_list
        aa_equals "filter option_list filter from empty list" \
            [xowiki::filter_option_list {} {4}] {}
    }

aa_register_case \
    -cats {api smoke production_safe} \
    -procs {
        "::xowiki::hstore::dict_as_hkey"
        "::xowiki::hstore::double_quote"
    } \
    api_hstore {

        Checks conversion from dict to hstorage keys with proper escaping

    } {
        set dict {key1 value1 key2 a'b k'y value3 key4 1,2 c before\tafter d "hello world"}
        aa_equals "filter option_list with empty exclusion set" \
            [::xowiki::hstore::dict_as_hkey $dict] \
            {key1=>value1,key2=>"a''b","k''y"=>value3,key4=>"1,2",c=>"before	after",d=>"hello world"}
    }


aa_register_case \
    -cats {api smoke production_safe} \
    -procs {
        "::xowiki::formfield::dict_to_spec"
        "::xowiki::formfield::dict_value"
        "::xowiki::formfield::fc_to_dict"

        "::xowiki::formfield::dict_to_fc"
        "::xowiki::formfield::FormField proc fc_encode"
        "::xowiki::formfield::FormField proc fc_decode"
    } \
    dict_to_xx {

        Checks conversion from dict to specs and form constraints.
        dict_to_spec is based on dict_to_fc.

    } {
        set dict {_name myname _type text label "Hello, world!" enabled 1}

        aa_equals "convert to spec" \
            [::xowiki::formfield::dict_to_spec $dict] \
            {myname:text,label=Hello__COMMA__ world!,enabled=1}
        aa_equals "convert to spec -aspair" \
            [::xowiki::formfield::dict_to_spec -aspair $dict] \
            {myname {text,label=Hello__COMMA__ world!,enabled=1}}

        #
        # Common idiom constructing form constraints
        #
        set fc ""; lappend fc \
            @categories:off @cr_fields:hidden \
            [::xowiki::formfield::dict_to_spec $dict]

        aa_equals "lappend + dict_to_spec fc idiom" \
            [concat $fc] \
            {@categories:off @cr_fields:hidden {myname:text,label=Hello__COMMA__ world!,enabled=1}}

        #
        # Common idiom to create component structure
        #

        set struct [subst {
            [list [::xowiki::formfield::dict_to_spec -aspair $dict]]
            {pattern {text,default=*,label=pool_question_pattern}}
        }]
        aa_equals "lappend + dict_to_spec component structure idiom" \
            [concat $struct] \
            {{myname {text,label=Hello__COMMA__ world!,enabled=1}}
            {pattern {text,default=*,label=pool_question_pattern}}}

        #
        # fc_to_dct
        #
        set fc ""; lappend fc \
            @categories:off @cr_fields:hidden \
            [::xowiki::formfield::dict_to_spec $dict]

        aa_equals "fc_to_dict (show results of reverse operation)" \
            [::xowiki::formfield::fc_to_dict $fc] \
            {myname {_name myname _type text label {Hello, world!} enabled 1 _definition {text,label=Hello__COMMA__ world!,enabled=1}}}

        #
        # dict_value
        #
        aa_equals "dict_value exists" \
            [::xowiki::formfield::dict_value $dict label] \
            {Hello, world!}
        aa_equals "dict_value not exists, no default" \
            [::xowiki::formfield::dict_value $dict title] \
            {}
        aa_equals "dict_value not exists, default" \
            [::xowiki::formfield::dict_value $dict title xxx] \
            {xxx}
    }

aa_register_case \
    -cats {api smoke production_safe} \
    -procs {
        "::xowiki::Page instproc create_form_fields_from_form_constraints"
    } \
    form_fields_from_form_constraints {

        Create (different) types of form-field with minimal interface.

    } {
        ::xo::require_html_procs
        set p1 [xowiki::Page new \
                    -name en:foo \
                    -package_id [ad_conn package_id] \
                    -destroy_on_cleanup]
        aa_log "p1 = $p1"
        foreach fc {
            {t:textarea,value=foo}
            {show_ip:boolean,horizontal=true,default=t,label=Show_IP}
            {date:date,default=2022-02-01 22:03:00}
        } props {
            {name t rows 2 cols 80}
            {name show_ip value t horizontal true required false label Show_IP}
            {name date value "2022-02-01 22:03:00"}
        } {
            set ff [$p1 create_form_fields_from_form_constraints \
                        [list $fc]]

            aa_log "<pre>[$ff serialize]</pre>"
            #aa_log "[$ff name] [$ff info class] [$ff value]"
            foreach {k v} $props {
                aa_true "$k has value '$v' == '[$ff $k]'" {[$ff $k] eq $v}
            }
            dom createDocument html doc
            set root [$doc documentElement]
            $root appendFromScript {
                $ff render_input
            }
            #
            # Here we could check with xpath the content of the rended
            # form field.
            #
            set HTML [lmap n [$root childNode] {$n asHTML}]
            aa_log "<pre>[ns_quotehtml $HTML]</pre>"
        }
    }

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
