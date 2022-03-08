aa_register_case \
    -cats {smoke production_safe} \
    -procs {
        "::acs::test::require_package_instance"
        "::xo::PackageMgr instproc initialize"
        "::xowiki::Page instproc include"

        "::xo::OrderedComposite::IndexCompare instproc __compare"
        "::xowiki::includelet::toc instproc build_toc"
        "::xowiki::includelet::toc instproc initialize"
        "::xowiki::includelet::toc instproc render"
        "::xowiki::includelet::toc instproc render_list"
        "::xowiki::includelet::toc instproc render_yui_list"
    } \
    includelet_toc {

        Test includelet "toc".

    } {
        set system_locale [lang::system::locale]
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
            # Create pages for toc testing, including page_order comparsions
            #
            foreach po {
                1
                1.1
                1.1.1
                1.10
                1.2
                10
                10.1
                100
                2
                2.1
                3
                3.1
                4
                9
            } {
                set id($po) [xowiki::test::require_page \
                                 -page_order $po \
                                 en:p$po $f_id $package_id]
            }
            ::xo::db::CrClass get_instance_from_db -item_id $id(1)

            foreach includelet {
                {toc -full 1 -decoration plain}
                {toc -style list -expand_all true -decoration plain}
                {toc -style yuitree -decoration none}
            } {
                aa_section "$includelet"

                set HTML [$id(1) include $includelet]
                #ns_log notice "R $includelet => $HTML "

                acs::test::dom_html root $HTML {
                    set elements [lmap node [$root selectNodes //li] {lindex [$node asText] 0}]
                }
                aa_log "elements: $elements"

                aa_true "find 1.1"  {[lsearch $elements 1.1] > -1}
                aa_true "find 1.2"  {[lsearch $elements 1.2] > -1}
                aa_true "find 1.10" {[lsearch $elements 1.10] > -1}
                aa_true "find 9"    {[lsearch $elements 9] > -1}
                aa_true "find 100"  {[lsearch $elements 100] > -1}

                aa_true "1.1 before 1.2"  {[lsearch $elements 1.1] < [lsearch $elements 1.2]}
                aa_true "1.2 before 1.10" {[lsearch $elements 1.2] < [lsearch $elements 1.10]}
                aa_true "3.1 before 9"    {[lsearch $elements 3.1] < [lsearch $elements 9]}
                aa_true "2 before 100"    {[lsearch $elements 2]   < [lsearch $elements 100]}
            }

        } finally {
            lang::system::set_locale $system_locale

            # set node_id [site_node::get_node_id -url /$instance]
            # site_node::unmount -node_id $node_id
            # site_node::delete -node_id $node_id -delete_package
        }
    }


aa_register_case \
    -cats {smoke production_safe} \
    -procs {
        "::acs::test::require_package_instance"
        "::xo::PackageMgr instproc initialize"
        "::xowiki::Page instproc include"

        "::xo::OrderedComposite instproc __compare"
        "::xowiki::FormPage proc get_all_children"
        "::xowiki::includelet::child-resources instproc render"
    } \
    includelet_childresources {

        Test includelet "child-resources". In particular this tests
        the effects of ns_strcoll (when available) for UTF-8 collation
        sequence. Notice, that the C-library is differently
        implemented in e.g. Linux and BSD* systems, but for the used test
        case it should be identical.

    } {
        set system_locale [lang::system::locale]
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
                          "childresources-folder" $root_folder_id $package_id]

            #
            # Create sample pages for testing
            #
            foreach {title} {
                a
                A
                b
                c
                Bor
                Bar
                Bär
                bb
                -bb
                zz
            } {
                set id($title) [xowiki::test::require_form_page \
                                 -title $title \
                                 en:p$title $f_id $package_id]
            }
            ::xo::db::CrClass get_instance_from_db -item_id $id(a)

            foreach includelet {
                {child-resources -parent .. -columns {name title} -orderby title,asc}
            } {
                aa_section "$includelet"

                set HTML [$id(a) include $includelet]
                #ns_log notice "RRR $includelet => $HTML "

                acs::test::dom_html root $HTML {
                    set elements [lmap node [$root selectNodes {//tr/td[2]}] {lindex [$node asText] 0}]
                }
                aa_log "elements: $elements"

                #
                # Run these test only when "ns_strcoll" is available
                #
                if {![::acs::icanuse "ns_strcoll"]} {
                    continue
                }

                aa_true "find Bar"  {[lsearch $elements Bar] > -1}
                aa_true "find Bär"  {[lsearch $elements Bär] > -1}
                aa_true "find Bor"  {[lsearch $elements Bor] > -1}

                aa_true "Bar before Bär"  {[lsearch $elements Bar] < [lsearch $elements Bär]}
                aa_true "Bar before Bor"  {[lsearch $elements Bar] < [lsearch $elements Bor]}
                aa_true "Bar before Bär"  {[lsearch $elements Bar] < [lsearch $elements Bär]}
                aa_true "Bär before Bor"  {[lsearch $elements Bär] < [lsearch $elements Bor]}
            }

        } finally {
            lang::system::set_locale $system_locale

            # set node_id [site_node::get_node_id -url /$instance]
            # site_node::unmount -node_id $node_id
            # site_node::delete -node_id $node_id -delete_package
        }
    }
