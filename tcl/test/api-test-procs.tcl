aa_register_case \
    -cats {smoke production_safe} \
    -procs {
        "::acs::test::require_package_instance"
        "::xo::PackageMgr instproc initialize"
        "::xowiki::Package instproc normalize_path"

        "::acs::root_of_host"
        "::ad_host"
        "::api_page_documentation_mode_p"
        "::auth::require_login"
        "::export_vars"
        "::site_node::get_url_from_object_id"        
        "::xo::ConnectionContext instproc user_id"
        "::xo::Context instproc export_vars"
        "::xo::Context instproc original_url_and_query"
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

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
