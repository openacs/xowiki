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
    } \
    package_normalize_path {

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
#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
