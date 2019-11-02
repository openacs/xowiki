aa_register_case \
    -cats {smoke production_safe} \
    -procs {
        "::xowiki::Package instproc normalize_path"
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
