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

                ::xowiki::Package initialize -package $package_id
                set root_folder_id [::$package_id folder_id]

                lang::system::set_locale en_US

                set user_info [::acs::test::user::create -email xowiki@acs-testing.test -admin]
                set request_info [::acs::test::login $user_info]

                set folder_name "toc-folder"
                set f_id [::xowiki::test::require_folder \
                              $folder_name $root_folder_id $package_id]

                #
                # Simple ToC using the "list" style that will render
                # only pages at the first level of the hierarchy
                # represented by the page_order.
                #
                set page_name toc1
                set toc1_id [xowiki::test::require_page \
                                 -text [list "{{toc -style list}}" text/html] \
                                 en:$page_name \
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

                acs::test::dom_html root $response {
                    set toc_links [$root selectNodes \
                                       "//*\[@class='toc'\]//a\[@href\]"]
                    aa_equals "No links should be rendered in the ToC, as no pages specify an order." \
                        [llength $toc_links] 0
                }


                aa_section "Render ToC with pages to display"

                set page_orders {
                    1
                    1.1
                    1.1.1
                    2
                    2.1
                    3
                    3.1
                    4
                    5
                    6
                    7
                    8
                    9
                    10
                    10.1
                    100
                }

                set first_level_page_orders [list]
                foreach page_order $page_orders {
                    if {[string first . $page_order] == -1} {
                        lappend first_level_page_orders $page_order
                    }
                }

                foreach page_order $page_orders {
                    ::xowiki::test::require_page \
                        -page_order $page_order \
                        en:tocPage-${page_order} \
                        $f_id \
                        $package_id
                }

                set d [acs::test::http \
                           -user_info $user_info \
                           $instance/$folder_name/$page_name]
                acs::test::reply_has_status_code $d 200

                set response [dict get $d body]
                aa_true "Includelet was rendered correctly" \
                    {[string first "Error in includelet 'toc'" $response] == -1}

                set toc_urls [list]
                acs::test::dom_html root $response {
                    set toc_links [$root selectNodes \
                                       "//*\[@class='toc'\]//a\[@href\]"]
                    aa_equals "The expected number of links has been rendered" \
                        [llength $toc_links] [llength $first_level_page_orders]
                    foreach toc_link $toc_links {
                        lappend toc_urls [$toc_link getAttribute href]
                    }
                }

                foreach toc_url $toc_urls page_order $first_level_page_orders {
                    aa_true "'$toc_url' is in the expected order '$page_order'" \
                        [string match "*$page_order" $toc_url]
                }

                # Get one of the rendered linky and check that it
                # points to an existing page.
                set d [acs::test::http \
                           -user_info $user_info \
                           [lindex $toc_urls 0]]
                acs::test::reply_has_status_code $d 200


                #
                # This ToC is configured to expand all of the links
                #
                set page_name toc2
                set toc1_id [xowiki::test::require_page \
                                 -text [list "{{toc -style list -expand_all true}}" text/html] \
                                 en:$page_name \
                                 $f_id \
                                 $package_id]

                aa_section "Render a ToC that will expand all links"
                set d [acs::test::http \
                           -user_info $user_info \
                           $instance/$folder_name/$page_name]
                acs::test::reply_has_status_code $d 200

                set response [dict get $d body]
                aa_true "Includelet was rendered correctly" \
                    {[string first "Error in includelet 'toc'" $response] == -1}

                set toc_urls [list]
                acs::test::dom_html root $response {
                    set toc_links [$root selectNodes \
                                       "//*\[@class='toc'\]//a\[@href\]"]
                    aa_equals "The expected number of links has been rendered" \
                        [llength $toc_links] [llength $page_orders]
                    foreach toc_link $toc_links {
                        lappend toc_urls [$toc_link getAttribute href]
                    }
                }

                foreach toc_url $toc_urls page_order $page_orders {
                    aa_true "'$toc_url' is in the expected order '$page_order'" \
                        [string match "*$page_order" $toc_url]
                }

                # Get one of the rendered linky and check that it
                # points to an existing page.
                set d [acs::test::http \
                           -user_info $user_info \
                           [lindex $toc_urls 0]]
                acs::test::reply_has_status_code $d 200

            } finally {
                # set node_id [site_node::get_node_id -url /$instance]
                # site_node::unmount -node_id $node_id
                # site_node::delete -node_id $node_id -delete_package
            }
        }

}
