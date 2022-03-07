

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
    includelet_toc {

        test toc includelet.

    } {
        set instance /xowiki-test
        set package_id [::acs::test::require_package_instance \
                            -package_key xowiki \
                            -empty \
                            -instance_name $instance]
        
        try {

            ::xowiki::Package initialize -package $package_id
            set root_folder_id [::$package_id folder_id]

            lang::system::set_locale en_US
            set f_id [::xowiki::test::require_folder \
                          "toc-folder" $root_folder_id $package_id]

            #
            # Create a trivial ToC page with "list" style and
            # check that this won't return an error
            #
            foreach {name po} {
                p1 1
                p1_1 1.1
                p1_2 1.2                
                p1_10 1.10
                p1_2 2
            } {
                set id($name) [xowiki::test::require_page \
                                   -page_order $po \
                                   en:$name \
                                   $f_id $package_id]
            }
            ::xo::db::CrClass get_instance_from_db -item_id $id(p1)            
            set HTML [$id(p1) include {toc -full 1 -decoration plain}]
            
            acs::test::dom_html root $HTML {
                set elements [lmap node [$root selectNodes //li] {lindex [$node asText] 0}]
            }
            aa_log elements=$elements
            aa_true "find 1.1" {[lsearch $elements 1.1] > -1}
            aa_true "find 1.2" {[lsearch $elements 1.2] > -1}
            aa_true "find 1.10" {[lsearch $elements 1.10] > -1}
            aa_true "1.1 before 1.2" {[lsearch $elements 1.1] < [lsearch $elements 1.2]}
            aa_true "1.2 before 1.10" {[lsearch $elements 1.2] < [lsearch $elements 1.10]}            
            ns_log notice R=$HTML
            
        } finally {
            # set node_id [site_node::get_node_id -url /$instance]
            # site_node::unmount -node_id $node_id
            # site_node::delete -node_id $node_id -delete_package
        }
            
    }
