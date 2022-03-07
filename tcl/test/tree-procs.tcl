ad_library {
    Test the ToC facilities
}

namespace eval ::xowiki::test {

    aa_register_case \
        -cats {smoke production_safe} \
        -procs {
        } \
        toc_includelet {
            Test that basic ToC includelet work.
        } {
            set instance /xowiki-test
            set package_id [::acs::test::require_package_instance \
                                -package_key xowiki \
                                -empty \
                                -instance_name $instance]

            try {

                set testfolder .testfolder
                ::xowiki::Package initialize -package $package_id
                set root_folder_id [::$package_id folder_id]

                lang::system::set_locale en_US

                set user_info [::acs::test::user::create -email xowiki@acs-testing.test -admin]
                set request_info [::acs::test::login $user_info]

                set folder_name "toc-folder"
                set f_id [::xowiki::test::require_folder \
                              $folder_name $root_folder_id $package_id]

                #
                # Create a trivial ToC page with "list" style and
                # check that this won't return an error
                #
                set page_name en:toc1
                set toc1_id [xowiki::test::require_page \
                                 -text [list "{{toc -style list}}" text/html] \
                                 $page_name \
                                 $f_id \
                                 $package_id]


                aa_section "Render ToC with no pages to display"
                set d [acs::test::http \
                           -user_info $user_info \
                           $instance/$folder_name/$page_name]
                acs::test::reply_has_status_code $d 200

                set response [dict get $d body]
                aa_true "Includelet was rendered correctly" \
                    {[string first "Error in includelet 'toc'" $response] == -1}


                aa_section "Render ToC with one page to display"

                ::xowiki::test::require_page \
                    -page_order 10 \
                    p10 \
                    $f_id \
                    $package_id

                set d [acs::test::http \
                           -user_info $user_info \
                           $instance/$folder_name/$page_name]
                acs::test::reply_has_status_code $d 200

                set response [dict get $d body]
                aa_true "Includelet was rendered correctly" \
                    {[string first "Error in includelet 'toc'" $response] == -1}


            } finally {
                # set node_id [site_node::get_node_id -url /$instance]
                # site_node::unmount -node_id $node_id
                # site_node::delete -node_id $node_id -delete_package
            }
        }

}
