aa_register_case \
    -init_classes {xowiki_require_test_instance} \
    -cats {smoke production_safe} \
    package_api_calls {

    Checks various API calls on package level

    @author Gustaf Neumann
} {

    set instance $_test_instance_name
    ::xowiki::Package initialize -url $_test_instance_name

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
