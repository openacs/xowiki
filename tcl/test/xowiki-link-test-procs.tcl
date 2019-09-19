namespace eval ::xowiki::test {

    aa_register_case \
	-init_classes {xowiki_require_test_instance} \
	-cats {smoke production_safe} \
	-procs {
	    "::xowiki::Page instproc render"
	} \
	link_tests {
	    Test links pointing to folders in different instances
	} {
	    #
	    # Should we cleanup the test instances after run?
	    #
	    set finally_clean_test_instances_p 1

	    #
	    # Set up of the test case.
	    #
	    set main_xowiki_instance_name   /xowiki-test
	    set linked_xowiki_instance_name /xowiki-test-linked

	    set main_package_id [::acs::test::require_package_instance \
				     -package_key xowiki \
				     -instance_name $main_xowiki_instance_name]
	    set linked_package_id [::acs::test::require_package_instance \
				       -package_key xowiki \
				       -instance_name $linked_xowiki_instance_name]
	    aa_log main_package_id=$main_package_id
	    aa_log linked_package_id=$linked_package_id

	    foreach parameter {MenuBar MenuBarSymLinks} {
		#
		# Use directly the xo* interface to avoid surprises with
		# cached parameter values when creating new instances.
		#
		xo::parameter set_value -package_id $main_package_id   -parameter $parameter -value 1
		xo::parameter set_value -package_id $linked_package_id -parameter $parameter -value 1
	    }

	    set testfolder .testfolder

	    #
	    # Force the system locale to en_US. We have to reset the
	    # locale at the end of this run, since we have no
	    # transaction.
	    #
	    #set defined_locale [lang::system::locale]
	    #lang::system::set_locale en_US

	    set locale [lang::system::locale]
	    set lang [string range $locale 0 1]

	    ::xowiki::Package initialize -package_id $main_package_id
	    ::xowiki::Package initialize -package_id $linked_package_id


	    set main_root_folder_id   [::$main_package_id folder_id]
	    set linked_root_folder_id [::$linked_package_id folder_id]

	    set link_name          link-to-folder-with-no-index-page
	    set linked_folder_name folder-with-no-index-page

	    set linked_folder_id [xowiki::test::require_folder $linked_folder_name \
				      $linked_root_folder_id $linked_package_id]
	    aa_true "linked_folder_id $linked_folder_id is valid " {$linked_folder_id ne "0"}

	    set link_id [xowiki::test::require_link $link_name $main_root_folder_id \
			     $main_package_id /$linked_xowiki_instance_name/$linked_folder_name]
	    aa_true "link_id $link_id is valid " {$link_id ne "0"}

	    set p1_id [xowiki::test::require_page en:p1 $linked_folder_id $linked_package_id]
	    aa_true "link_id $p1_id is valid " {$p1_id ne "0"}

	    ::xo::db::CrClass get_instance_from_db -item_id $link_id
	    set link_content [::$link_id render]
	    #ns_log notice $link_content

	    #
	    # Check, if
	    # (a) the rendered link contains the page included in the linked folder and
	    # (b) that the page link points to the target instance (no resolve_local provided)
	    #
	    acs::test::dom_html root $link_content {
		set node [$root selectNodes //td\[@class='list'\]/a\[@title='en:p1'\]]
		aa_true "one page found" {[llength $node] == 1}
		if {[llength $node] == 1} {
		    set href [$node getAttribute href]
		    aa_equals "href points to linked folder" $href \
			$linked_xowiki_instance_name/$linked_folder_name/p1
		}
	    }

	    #
	    # reset system locale to saved value
	    #
    	    #lang::system::set_locale $defined_locale

	    if {$finally_clean_test_instances_p} {
		foreach instance_name [list $main_xowiki_instance_name $linked_xowiki_instance_name] {
		    set node_id [site_node::get_node_id -url /$instance_name]
		    site_node::unmount -node_id $node_id
		    site_node::delete -node_id $node_id -delete_package
		}
	    }
	}
}
