namespace eval ::xowiki::test {

  aa_register_case \
      -cats {smoke production_safe} \
      -procs {
        "::acs::test::dom_html"
        "::acs::test::require_package_instance"
        "::lang::system::locale"
        "::lang::system::set_locale"
        "::xo::PackageMgr instproc initialize"
        "::xo::db::CrClass proc get_instance_from_db"
        "::xowiki::test::require_folder"
        "::xowiki::test::require_link"
        "::xowiki::test::require_page"

        "::acs::root_of_host"
        "::ad_acs_kernel_id"
        "::ad_host"
        "::api_page_documentation_mode_p"
        "::auth::require_login"
        "::export_vars"
        "::general_comments_delete_messages"
        "::site_node::get_url_from_object_id"
        "::xo::ConnectionContext instproc get_parameter"
        "::xo::ConnectionContext instproc user_id"
        "::xo::Context instproc export_vars"
        "::xo::Context instproc original_url_and_query"
        "::xo::Context instproc package_id"
        "::xo::PackageMgr proc get_package_class_from_package_key"
        "::xo::db::Class proc object_type_to_class"
        "::xo::db::CrClass proc ensure_item_ids_instantiated"
        "::xowiki::FormPage instproc update_item_index"
        "::xowiki::FormPage proc fetch_object"
        "::xowiki::Package instproc folder_path"
        "::xowiki::Package instproc pretty_link"
        "::xowiki::Page instproc render"
        "::xowiki::utility proc formCSSclass"
      } \
      link_tests {
        Test links pointing to folders in different instances
      } {
        #
        # Set up of the test case.
        #

        set main_xowiki_instance_name   /xowiki-test
        set linked_xowiki_instance_name /xowiki-test-linked

        set main_package_id [::acs::test::require_package_instance \
                                 -package_key xowiki \
                                 -empty \
                                 -instance_name $main_xowiki_instance_name]
        set linked_package_id [::acs::test::require_package_instance \
                                   -package_key xowiki \
                                   -empty \
                                   -instance_name $linked_xowiki_instance_name]
        aa_log main_package_id=$main_package_id
        aa_log linked_package_id=$linked_package_id

        foreach parameter {MenuBar MenuBarSymLinks} {
          ::parameter::set_value -package_id $main_package_id   -parameter $parameter -value 1
          ::parameter::set_value -package_id $linked_package_id -parameter $parameter -value 1
        }

        set testfolder .testfolder

        #
        # Force the system locale to en_US. We have to reset the
        # locale at the end of this run, since we have no
        # transaction.
        #
        set defined_locale [lang::system::locale]
        lang::system::set_locale en_US

        set locale [lang::system::locale]
        set lang [string range $locale 0 1]

        #
        # Perform a full initialize on both packages to get ::xo::cc
        # also set.
        #
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
        set link_content [::$link_id render_content]
        #ns_log notice $link_content

        aa_section "Check links in rendered child-resources (default render_local)"
        #
        # Check, if
        # (a) the rendered link contains the page included in the linked folder and
        # (b) that the page link points to the target instance (no resolve_local provided)
        #
        aa_log "check content of /$linked_xowiki_instance_name/$linked_folder_name"
        #ns_log notice "search for link with title en:p1: link_content $link_content"
        acs::test::dom_html root $link_content {
          set node [$root selectNodes //td\[@class='list'\]/a\[@title='en:p1'\]]
          aa_true "one page found" {[llength $node] == 1}
          if {[llength $node] == 1} {
            set href [$node getAttribute href]
            aa_equals "href points to linked folder" $href \
                $linked_xowiki_instance_name/$linked_folder_name/p1
          }
        }

        aa_section "Check links in rendered child-resources (default render_local=true)"

        #
        # Now we test the behavior, if the link is defined with
        # "resolve_local=true". Since the defining is coming from
        # the site-wide-pages, and many of these values are
        # already loaded, we modify the loaded content. In
        # particular, the form-field responsible for rendering can
        # be looked up, and we can modify in this form-field the
        # instance variable "resolve_local" directly.
        #
        # This is by-passing the API, but little code. Caveat:
        # When form-field caching is modified, we might have to
        # change this code as well

        foreach f [::xowiki::formfield::FormField info instances -closure] {
          if {[$f name] eq "link"} {
            $f set resolve_local true
          }
        }

        acs::test::dom_html root [::$link_id render_content] {
          set node [$root selectNodes //td\[@class='list'\]/a\[@title='en:p1'\]]
          aa_true "one page found" {[llength $node] == 1}
          if {[llength $node] == 1} {
            set href [$node getAttribute href]
            aa_equals "href points to local folder" $href \
                $main_xowiki_instance_name/$link_name/p1
          }
        }


        #
        # reset system locale to saved value
        #
        lang::system::set_locale $defined_locale
      }
}

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
