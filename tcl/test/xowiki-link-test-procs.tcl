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
	    aa_run_with_teardown -rollback=0 -test_code {
		set main_xowiki_instance_name /xowiki-test
		set linked_xowiki_instance_name /xowiki-test-linked

		set main_package_id [::acs::test::require_package_instance \
					 -package_key xowiki \
					 -instance_name $main_xowiki_instance_name]
		set linked_package_id [::acs::test::require_package_instance \
					   -package_key xowiki \
					   -instance_name $linked_xowiki_instance_name]
		aa_log main_package_id=$main_package_id
		aa_log linked_package_id=$linked_package_id

		set testfolder .testfolder

		#
		# Force the system locale to en_US. The value is
		# automatically reset to the previous value, since we are
		# running in an transaction.
		#
		lang::system::set_locale en_US

		set locale [lang::system::locale]
		set lang [string range $locale 0 1]

		::xowiki::Package initialize -package_id $main_package_id
		::xowiki::Package initialize -package_id $linked_package_id

		foreach parameter {MenuBar MenuBarSymLinks} {
		    parameter::set_value -package_id $main_package_id -parameter $parameter -value 1
		    parameter::set_value -package_id $linked_package_id -parameter $parameter -value 1
		}

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
	    }
	}
}
