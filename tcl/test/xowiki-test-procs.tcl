namespace eval ::xowiki::formfield {

    #
    # Define a compound field just for regression testing purposes
    # (used in test case create_form_with_form_instance)
    #
    Class create regression_test_mycompound -superclass CompoundField
    regression_test_mycompound instproc initialize {} {
        if {${:__state} ne "after_specs"} return
        :create_components  [subst {
            {start_on_publish {checkbox,default=t,options={YES t}}}
            {whatever   {text}}
        }]
        set :__initialized 1
    }

    Class create regression_test_compound_numeric -superclass CompoundField
    regression_test_compound_numeric instproc initialize {} {
        :create_components  {
            {anumber {numeric,label=The Number}}
        }
    }

    #
    # A compound field containing a repeated compound field
    #
    Class create regression_test_compound_with_repeat -superclass CompoundField
    regression_test_compound_with_repeat instproc initialize {} {
        :create_components  {
            {anumber {numeric,label=The Number}}
            {atext {text,label=The Text}}
            {arichtext {richtext,label=The Richtext}}
            {aradio {radio,label=The Radio,options={X X} {Y Y} {Z Z}}}
            {acheckbox {checkbox,label=The Checkbox,options={X X} {Y Y} {Z Z}}}
            {aselect {select,label=The Select,options={X X} {Y Y} {Z Z}}}
            {amultiselect {select,multiple=true,label=The Select,options={X X} {Y Y} {Z Z}}}
            {arepeatedcompound {regression_test_compound_with_repeat2,repeat=0..5,label=The nested compound}}
        }
    }

    Class create regression_test_compound_with_repeat2 -superclass CompoundField
    regression_test_compound_with_repeat2 instproc initialize {} {
        :create_components  {
            {anumber {numeric,label=The Number}}
            {atext {text,label=The Text}}
            {arichtext {richtext,label=The Richtext}}
            {aradio {radio,label=The Radio,options={A A} {B B} {C C}}}
            {acheckbox {checkbox,label=The Checkbox,options={A A} {B B} {C C}}}
            {aselect {select,label=The Select,options={A A} {B B} {C C}}}
            {amultiselect {select,multiple=true,label=The Select,options={A A} {B B} {C C}}}
        }
    }

}

namespace eval ::xowiki {
  FormPage instproc configure_page=regression_test {name} {
    set :description "foo"
  }
}

namespace eval ::xowiki::test {

    aa_register_case \
        -cats {smoke production_safe} \
        -procs {
            "::acs::test::require_package_instance"
            "::lang::system::set_locale"
            "::site_node::delete"
            "::site_node::get_node_id"
            "::site_node::unmount"
            "::xo::PackageMgr instproc initialize"
            "::xo::db::CrClass proc get_instance_from_db"
            "::xo::db::CrItem instproc update_attribute_from_slot"
            "::xowiki::FormPage instproc update_attribute_from_slot"
            "::xowiki::test::require_folder"
            "::xowiki::test::require_page"
            "::xowiki::update_item_index"

            "::acs::root_of_host"
            "::ad_host"
            "::api_page_documentation_mode_p"
            "::auth::require_login"
            "::export_vars"
            "::site_node::get_url_from_object_id"
            "::xo::ConnectionContext instproc user_id"
            "::xo::Context instproc export_vars"
            "::xo::Context instproc original_url_and_query"
            "::xo::db::Class proc object_type_to_class"
            "::xo::db::DB-postgresql instproc dml"
            "::xowiki::Page instproc find_slot"
            "::xowiki::Page proc find_slot"
        } \
        slot_interactions {
            Test slot interactions
        } {

        set instance /xowiki-test
        set package_id [::acs::test::require_package_instance \
                            -package_key xowiki \
                            -empty \
                            -instance_name $instance]

        aa_run_with_teardown -rollback -test_code {

            set testfolder .testfolder
            ::xowiki::Package initialize -package $package_id
            set root_folder_id [::$package_id folder_id]

            lang::system::set_locale en_US

            set f1_id        [xowiki::test::require_folder "f1"    $root_folder_id $package_id]
            set p0_id        [xowiki::test::require_page   en:p0   $root_folder_id $package_id]

            ::xo::db::CrClass get_instance_from_db -item_id $f1_id
            ::xo::db::CrClass get_instance_from_db -item_id $p0_id

            aa_section "update from slot on extend_slot (description)"
            set s [$p0_id find_slot description]
            aa_true "slot found: $s" {$s ne ""}
            aa_equals "slot is " $s ::xowiki::Page::slot::description
            aa_equals "slot domain is " [$s domain] ::xo::db::CrItem

            aa_equals "old description is" [$p0_id description] ""
            $p0_id update_attribute_from_slot $s "new description"
            aa_equals "new description is" [$p0_id description] "new description"

            set item_id [$p0_id item_id]
            set d [::xo::dc get_value get_description {select description from xowiki_pagex where item_id = :item_id}]
            aa_equals "new description from db is" $d "new description"

            $p0_id destroy
            ::xo::db::CrClass get_instance_from_db -item_id $p0_id
            aa_equals "new description is" [$p0_id description] "new description"


            aa_section "update from slot on plain_slot (creator)"
            set s [$p0_id find_slot creator]
            aa_true "slot found: $s" {$s ne ""}
            aa_equals "slot is " $s ::xowiki::Page::slot::creator
            aa_equals "slot domain is " [$s domain] ::xowiki::Page

            aa_equals "old creator is" [$p0_id creator] ""
            $p0_id update_attribute_from_slot $s "the creator"
            aa_equals "new creator is" [$p0_id creator] "the creator"

            set item_id [$p0_id item_id]
            set d [::xo::dc get_value get_creator {select creator from xowiki_pagex where item_id = :item_id}]
            aa_equals "new creator from db is" $d "the creator"

            $p0_id destroy
            ::xo::db::CrClass get_instance_from_db -item_id $p0_id
            aa_equals "new creator is" [$p0_id creator] "the creator"

            #
            # Form page, update instance attributes (hstore is probably
            # not activated on most instances)
            #
            aa_section "update from slot on instance attributes"
            set s [$f1_id find_slot instance_attributes]
            aa_true "slot found: $s" {$s ne ""}
            aa_equals "slot is " $s ::xowiki::PageInstance::slot::instance_attributes
            aa_equals "slot domain is " [$s domain] ::xowiki::PageInstance

            aa_equals "old instance_attributes is" [$f1_id instance_attributes] ""
            $f1_id update_attribute_from_slot $s "a 1"
            aa_equals "new instance_attributes is" [$f1_id instance_attributes] "a 1"

            set item_id [$f1_id item_id]
            set d [::xo::dc get_value get_description {select instance_attributes from xowiki_form_pagex where item_id = :item_id}]
            aa_equals "new instance_attributes from db is" $d "a 1"

            #
            # Form page, update attribute in item index.
            #
            aa_section "update from slot on form page and item index"
            set s [$f1_id find_slot state]
            aa_true "slot found: $s" {$s ne ""}
            aa_equals "slot is " $s ::xowiki::FormPage::slot::state
            aa_equals "slot domain is " [$s domain] ::xowiki::FormPage

            set state [::xo::dc get_value get_state {select state from xowiki_form_pagex where item_id = :item_id}]
            aa_equals "state directly from item index" $state [$f1_id state]

            foreach state {"" initial teststate} {
                $f1_id update_attribute_from_slot $s $state
                aa_equals "state from object is '$state'" [$f1_id state] $state
                set db_state [::xo::dc get_value get_state {select state from xowiki_form_pagex where item_id = :item_id}]
                aa_equals "state directly from item index is '$state'" $db_state $state

                #
                # Now destroy in memory and refetch to double check, if all is OK.
                #
                $f1_id destroy
                ::xo::db::CrClass get_instance_from_db -item_id $f1_id
                aa_equals "new instance_attributes is" [$f1_id instance_attributes] "a 1"
                aa_equals "new state is" [$f1_id state] $state
            }

        } -teardown_code {
            set node_id [site_node::get_node_id -url /$instance]
            site_node::unmount -node_id $node_id
            site_node::delete -node_id $node_id -delete_package
        }
    }

    aa_register_case \
        -cats {smoke production_safe} \
        -procs {
            "::acs::test::require_package_instance"
            "::lang::system::locale"
            "::lang::system::set_locale"
            "::site_node::delete"
            "::site_node::get_node_id"
            "::site_node::unmount"
            "::xo::PackageMgr instproc initialize"
            "::xo::db::CrClass proc get_instance_from_db"
            "::xowiki::test::require_folder"
            "::xowiki::test::require_page"

            "::acs::root_of_host"
            "::ad_host"
            "::api_page_documentation_mode_p"
            "::auth::require_login"
            "::export_vars"
            "::site_node::get_url_from_object_id"
            "::xo::ConnectionContext instproc query_parameter"
            "::xo::ConnectionContext instproc user_id"
            "::xo::Context instproc export_vars"
            "::xo::Context instproc original_url_and_query"
            "::xo::Page proc requireCSS"
            "::xo::Page proc requireJS"
            "::xo::db::Class proc object_type_to_class"
            "::xo::db::CrClass proc lookup"
            "::xo::db::DB-postgresql instproc get_value"
            "::xowiki::Package instproc item_info_from_url"
            "::xowiki::Package instproc item_ref"
            "::xowiki::Package instproc lookup"
            "::xowiki::Package instproc resolve_page"
            "::xowiki::Page instproc create_link"
            "::xowiki::FormPage proc fetch_object"
            "::xo::PackageMgr proc get_package_class_from_package_key"
        } \
        path_resolve {
            Test various forms of path resolving
        } {

        set instance /xowiki-test
        set package_id [::acs::test::require_package_instance \
                            -package_key xowiki \
                            -empty \
                            -instance_name $instance]

        aa_run_with_teardown -rollback -test_code {

            set testfolder .testfolder

            ::xowiki::Package initialize -package $package_id
            set root_folder_id [::$package_id folder_id]

            # Create the test folder
            ::xowiki::test::require_folder $testfolder $root_folder_id $package_id

            set testfolder_id [::$package_id lookup -parent_id $root_folder_id -name $testfolder]
            aa_true "can resolve '$testfolder'" {$testfolder_id > 0}

            #
            # Force the system locale to en_US. The value is
            # automatically reset to the previous value, since we are
            # running in a transaction.
            #
            lang::system::set_locale en_US

            set locale [lang::system::locale]
            set lang [string range $locale 0 1]

            aa_log "package_id $package_id system locale $locale"

            set f1_id        [xowiki::test::require_folder "f1"    $root_folder_id $package_id]
            set f3_id        [xowiki::test::require_folder "f3"    $f1_id $package_id]
            set subf3_id     [xowiki::test::require_folder "subf3" $f3_id $package_id]
            set enpage_id    [xowiki::test::require_page   en:page $root_folder_id $package_id]
            set p0_id        [xowiki::test::require_page   en:p0   $root_folder_id $package_id]
            set f1_p1_id     [xowiki::test::require_page   en:p1   $f1_id $package_id]

            ::xo::db::CrClass get_instance_from_db -item_id $enpage_id
            set enpage_pl [::$enpage_id pretty_link]
            aa_equals "Pretty link of en:page: $enpage_pl" $enpage_pl "/xowiki-test/page"

            ::xo::db::CrClass get_instance_from_db -item_id $p0_id
            set p0_pl [::$p0_id pretty_link]
            aa_equals "Pretty link of p0 $p0_pl" $p0_pl "/xowiki-test/p0"

            ::xo::db::CrClass get_instance_from_db -item_id $f1_p1_id
            set f1_p1_pl [::$f1_p1_id pretty_link]
            aa_equals "Pretty link of f1/page $f1_p1_pl" $f1_p1_pl "/xowiki-test/f1/p1"

            ::xo::db::CrClass get_instance_from_db -item_id $testfolder_id
            set testfolder_pl [::$testfolder_id pretty_link]
            aa_equals "Pretty link of $testfolder $testfolder_pl" $testfolder_pl "$instance/$testfolder"

            #
            # Try to resolve folders, pages and inherited folder.form via URL.
            # The method resolve_page receives the "object" instance variable
            # initialized via "Package initialize" ALWAYS without a leading "/".
            #
            aa_section "resolve_page"
            foreach url {
                f1 page f1/p1
                en:folder.form folder.form
            } {
                set page [$package_id resolve_page $url m]
                aa_true "can resolve url $url -> $page" {$page ne ""}
            }

            #
            # Try to obtain item_info from URLs pointing to folders,
            # pages and inherited folder.form via URL. This function
            # is a helper function of resolve_page, so same rules
            # apply here as well.
            #
            aa_section "item_info_from_url -with_package_prefix false"
            foreach url {
                f1 page f1/p1
            } {
                set info [$package_id item_info_from_url \
                              -with_package_prefix false \
                              -default_lang $lang \
                              $url]
                aa_true "can get item_info from url $url -> $info" {[dict get $info item_id] ne "0"}
            }

            aa_section "item_info_from_url -with_package_prefix true"
            foreach url {
                /xowiki-test/f1 /xowiki-test/page /xowiki-test/f1/p1
            } {
                set info [$package_id item_info_from_url \
                              -with_package_prefix true \
                              -default_lang $lang \
                              $url]
                aa_true "can get item_info from url $url -> $info" {[dict get $info item_id] ne "0"}
            }

            #
            # item_refs are different to URLs, but look similar.  The
            # item refs can be used to navigate in the tree and they
            # are allow symbolic names not necessarily possible via
            # URLs (e.g. prefixed names).
            #
            aa_section "resolve item refs"
            foreach item_ref {
                f1 page f1/p1
                ./f1 ./page ./f1/p1
                /f1 /page /f1/p1
            } {
                set info [$package_id item_ref -parent_id $root_folder_id -default_lang $lang $item_ref]
                aa_true "can resolve item_ref $item_ref -> $info" {[dict get $info item_id] ne "0"}
            }

            aa_section "bi-directional resolving via URLs"

            ::xo::db::CrClass get_instance_from_db -item_id $enpage_id
            set pretty_link1 [::$enpage_id pretty_link]
            set item_info1   [$package_id item_info_from_url $pretty_link1]
            aa_true "can resolve $pretty_link1 => $enpage_id" \
                [expr {[dict get $item_info1 item_id] eq $enpage_id}]

            set folder_clash_id [xowiki::test::require_folder "page" $root_folder_id $package_id]
            ::xo::db::CrClass get_instance_from_db -item_id $folder_clash_id
            set pretty_link2 [::$folder_clash_id pretty_link]
            set item_info2   [$package_id item_info_from_url $pretty_link2]
            aa_true "same-named folder: can resolve $pretty_link2 => $folder_clash_id" \
                [expr {[dict get $item_info2 item_id] eq $folder_clash_id}]

            set pretty_link1 [::$enpage_id pretty_link]
            set item_info1   [$package_id item_info_from_url $pretty_link1]
            aa_true "same-named page: can resolve $pretty_link1 => $enpage_id" \
                [expr {[dict get $item_info1 item_id] eq $enpage_id}]

            #
            # Due to the adding of the folder named "page", we might
            # have a confusion when referring to item_refs.
            #
            aa_section "Ambiguous item_refs"

            foreach pair [subst {
                {page $enpage_id en}
                {f1 $f1_id ""}
            }] {
                lassign $pair item_ref id prefix
                set info [$package_id item_ref -parent_id $root_folder_id -default_lang $lang $item_ref]
                #aa_log info=$info
                aa_true "can resolve item_ref '$item_ref' -> $id" {[dict get $info item_id] eq $id}
                aa_true "check prefix of item_ref $item_ref -> $prefix" {[dict get $info prefix] eq $prefix}
            }

            #
            # Link rendering
            #
            aa_section "render links (\[\[somelink\]\]"
            ns_log notice "---render links---"

            foreach pair [subst {
                {page /en:page}
                {./page /en:page}
                {./page/ /page}
                {en:page/ /en:page}
                {f1 /f1}
                {./f1 /f1}
                {f1/p1 /f1/p1}
                {f1/f3 /f1/f3}
            }] {
                lassign $pair link pattern
                set l [::$p0_id create_link $link]
                set html [$l render]
                aa_true "render link \[\[$link\]\] -> *'$instance$pattern'*" [string match *'$instance$pattern'* $html]
                aa_log "[ns_quotehtml $html]"
            }
        } -teardown_code {
            set node_id [site_node::get_node_id -url /$instance]
            site_node::unmount -node_id $node_id
            site_node::delete -node_id $node_id -delete_package
        }
    }


    aa_register_case -cats {web} -procs {
        "::acs::test::dom_html"
        "::acs::test::http"
        "::acs::test::reply_has_status_code"
        "::acs::test::require_package_instance"
        "::acs::test::user::create"
        "::export_vars"
        "::lang::system::locale"
        "::xowiki::Page instproc www-create-new"
        "::xowiki::Page instproc www-edit"
        "::xowiki::test::create_form"
        "::xowiki::test::create_form_page"
        "::xowiki::test::edit_form_page"
        "::xowiki::test::get_content"
        "::xowiki::test::get_form_CSSclass"
        "::xowiki::test::get_object_name"
        "::xowiki::test::require_test_folder"

        "::ad_log"
        "::ad_return_complaint"
        "::ad_script_abort"
        "::ad_text_to_html"
        "::ad_urlencode_query"
        "::cookieconsent::CookieConsent instproc render_js"
        "::template::util::lpop"
        "::xo::ConnectionContext instproc get_all_form_parameter"
        "::xo::ConnectionContext instproc user_id"
        "::xo::Context instproc invoke_object"
        "::xo::Package instproc initialize"
        "::xo::Package instproc reply_to_user"
        "::xo::PackageMgr instproc first_instance"
        "::xo::PackageMgr instproc initialize"
        "::xo::PackageMgr instproc require"
        "::xo::Page proc get_property"
        "::xo::Page proc set_property"
        "::xo::Table instproc column_names"
        "::xo::db::CrClass instproc get_instance_from_db"
        "::xo::db::CrClass instproc get_instances_from_db"
        "::xo::db::CrClass proc id_belongs_to_package"
        "::xo::db::CrItem instproc rename"
        "::xo::tdom::AttributeManager instproc get_attributes"
        "::xowiki::FormPage instproc combine_data_and_form_field_default"
        "::xowiki::FormPage instproc load_values_into_form_fields"
        "::xowiki::FormPage instproc set_form_data"
        "::xowiki::FormPage instproc set_property"
        "::xowiki::Includelet proc html_encode"
        "::xowiki::Package instproc get_parameter"
        "::xowiki::Package instproc invoke"
        "::xowiki::Package instproc require_root_folder"
        "::xowiki::Package instproc www-edit-new"
        "::xowiki::Package instproc www-import-prototype-page"
        "::xowiki::Page instproc get_form_data"
        "::xowiki::Page instproc include"
        "::xowiki::PageInstance instproc get_from_template"
        ::acs::test::form_get_fields
        ::acs::test::form_reply
        ::acs::test::form_set_fields
        ::acs::test::get_form
        ::acs::test::get_url_from_location
        ::acs::test::xpath::get_form
        ::acs::test::xpath::get_form_values
        "::xo::PackageMgr proc get_package_class_from_package_key"
        "::xowiki::utility proc formCSSclass"
        ad_parse_template
        db_driverkey
        ad_try

    } create_form_with_form_instance {

        Create an xowiki form and an instance of this form.  Here we
        test primarily checkboxes (plain, repeated and in a compound
        form), which are especially nasty in cases, where e.g. a
        per-default marked checkbox is unmarked. In this case, the
        server has to detect the new value by the fact that no value
        was sent by the browser.

    } {

        #
        # Create a new admin user and login
        #
        #
        # Setup of test user_id and login
        #
        set user_info [::acs::test::user::create -email xowiki@acs-testing.test -admin]
        set request_info [::acs::test::login $user_info]

        set instance /xowiki-test
        set package_id [::acs::test::require_package_instance \
                            -package_key xowiki \
                            -empty \
                            -instance_name $instance]
        set testfolder .testfolder

        try {
            ###########################################################
            aa_section "Require test folder"
            ###########################################################

            set folder_info [::xowiki::test::require_test_folder \
                                 -last_request $request_info \
                                 -instance $instance \
                                 -folder_name $testfolder \
                                 -fresh \
                                ]

            set folder_id  [dict get $folder_info folder_id]
            set package_id [dict get $folder_info package_id]
            aa_true "folder_id '$folder_id' is not 0" {$folder_id != 0}

            set locale [lang::system::locale]
            set lang [string range $locale 0 1]
            set form_name $lang:checkbox-testing.form
            ###########################################################
            aa_section "Create Form $form_name"
            ###########################################################

            #
            # The created form contains several checkboxes, which are
            # nasty to handle. When a checkbox was marked, but is then
            # unchecked, its value is NOT returned by the
            # browser. The server has to detect by the fact of
            # untransmitted values that the instance attribute value
            # has to be altered. This is very different to the
            # standard cases, where the edited values are transmitted.
            #
            # The created form below handles also more complex cases:
            #
            # a) a checkbox box1, where a default is set
            # b) a repeated checkbox, where one value is provided
            # c) a compound field, where the compound field definition
            #    contains a default for the subcomponent.

            ::xowiki::test::create_form \
                -last_request $request_info \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -name $form_name \
                -update [subst {
                    title "Checkbox Testing Form"
                    nls_language $locale
                    text {<p>@_text@</p><p>box1 @box1@ box2 @box2@ box3 @box3@</p>}
                    text.format text/html
                    form {<form>@ignored@ @assignee@ @box1@ @box2@ @box3@ @mycompound@</form>}
                    form.format text/html
                    form_constraints {
                        _page_order:omit _title:omit _nls_language:omit _description:omit
                        ignored:text,disabled _assignee:text,disabled
                        {box1:checkbox,options={1 1} {2 2},horizontal=true,default=1}
                        {box2:checkbox,options={a a} {b b},horizontal=true,repeat=1..3,default=a}
                        {box3:checkbox,options={30 30} {31 31},horizontal=true,default=30,disabled}
                        mycompound:regression_test_mycompound
                    }
                    anon_instances t
                }]
            aa_log "Form $form_name created"

            ###########################################################
            aa_section "Create an instance of $form_name named '$lang:cb1'"
            ###########################################################
            set page_name $lang:cb1

            set user_id [dict get $user_info user_id]
            set another_user_id [::xo::dc get_value get_another_user {
                select max(user_id) from users where user_id <> :user_id
            }]

            set d [::xowiki::test::create_form_page \
                -last_request $request_info \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -form_name $form_name \
                -update [subst {
                    _name $page_name
                    _title "fresh $page_name"
                    _nls_language $locale
                    ignored {I should not be stored}
                    _assignee $another_user_id
                }]]

            aa_log "Page $page_name created"

            set extra_url_parameter {{m edit}}
            aa_log "Check content of the fresh instance"
            set d [acs::test::http -last_request $request_info \
                       [export_vars -base $instance/$testfolder/$page_name $extra_url_parameter]]
            acs::test::reply_has_status_code $d 200

            set response [dict get $d body]
            acs::test::dom_html root $response {
                set f_id     [::xowiki::test::get_object_name $root]
                set CSSclass [::xowiki::test::get_form_CSSclass $root]
                aa_true "page_name '$f_id' non empty" {$f_id ne ""}
                aa_true "CSSclass: '$CSSclass' non empty"  {$CSSclass ne ""}
                set id_part [string map {: _} $page_name]
                set ignored [$root getElementById F.$id_part.ignored]
                set assignee [$root getElementById F.$id_part._assignee]
                set page_order [$root getElementById F.$id_part._page_order]
                set input_box1_1 [$root getElementById F.$id_part.box1:1]
                set input_box1_2 [$root getElementById F.$id_part.box1:2]
                set input_box2_1_a [$root getElementById F.$id_part.box2.1:a]
                set input_box2_1_b [$root getElementById F.$id_part.box2.1:b]
                set input_box5 [$root getElementById F.$id_part.mycompound.start_on_publish:t]
                set input_box6 [$root getElementById F.$id_part.box3:30]
                set input_box7 [$root getElementById F.$id_part.box3:31]
                aa_equals "ignored text field is empty"  [$ignored getAttribute value] ""
                aa_equals "assignee text field is empty" [$assignee getAttribute value] ""
                aa_equals "input_box1_1 box checked (box1: simple box)"   [$input_box1_1 hasAttribute checked] 1
                aa_equals "input_box1_2 box checked (box1: simple box)"   [$input_box1_2 hasAttribute checked] 0
                aa_equals "input_box2_1_a box checked (box2: repeated box)" [$input_box2_1_a hasAttribute checked] 1
                aa_equals "input_box2_1_b box checked (box2: repeated box)" [$input_box2_1_b hasAttribute checked] 0
                aa_equals "input_box5 box checked (mycompound)"         [$input_box5 hasAttribute checked] 1
                aa_equals "input_box6 box checked (box3: simple disabled box)" [$input_box6 hasAttribute checked] 1
                aa_equals "input_box7 box checked (box3: simple disabled box)" [$input_box7 hasAttribute checked] 0
                aa_equals "page_order should be omitted and not be rendered" $page_order ""
                #ns_log notice "XXXX box3\n[$input_box6 asHTML] \n[$input_box7 asHTML]"
            }

            ###########################################################
            aa_section "Edit the instance of $form_name"
            ###########################################################

            ::xowiki::test::edit_form_page \
                -last_request $request_info \
                -instance $instance \
                -path $testfolder/$page_name \
                -remove {box1 box2.1 mycompound.start_on_publish} \
                -update [subst {
                    _title "edited $page_name"
                }]

            aa_log "Check content of the edited instance"
            set d [acs::test::http -user_info $user_info [export_vars -base $instance/$testfolder/$page_name $extra_url_parameter]]
            acs::test::reply_has_status_code $d 200

            set response [dict get $d body]
            acs::test::dom_html root $response {
                set id_part [string map {: _} $page_name]
                set input_box1 [$root getElementById F.$id_part.box1:1]
                set input_box2 [$root getElementById F.$id_part.box1:2]
                set input_box3 [$root getElementById F.$id_part.box2.1:a]
                set input_box4 [$root getElementById F.$id_part.box2.1:b]
                set input_box5 [$root getElementById F.$id_part.mycompound.start_on_publish:t]
                set input_box6 [$root getElementById F.$id_part.box3:30]
                set input_box7 [$root getElementById F.$id_part.box3:31]
                aa_equals "input_box1 box checked (box1: simple box)"   [$input_box1 hasAttribute checked] 0
                aa_equals "input_box2 box checked (box1: simple box)"   [$input_box2 hasAttribute checked] 0
                aa_equals "input_box3 box checked (box2: repeated box)" [$input_box3 hasAttribute checked] 0
                aa_equals "input_box4 box checked (box2: repeated box)" [$input_box4 hasAttribute checked] 0
                aa_equals "input_box5 box checked (mycompound)"         [$input_box5 hasAttribute checked] 0
                aa_equals "input_box6 box checked (box3: simple disabled box)" [$input_box6 hasAttribute checked] 1
                aa_equals "input_box7 box checked (box3: simple disabled box)" [$input_box7 hasAttribute checked] 0
                #ns_log notice "XXXX box3\n[$input_box6 asHTML] \n[$input_box7 asHTML]"
            }


            set form_name $lang:Misc.form
            ###########################################################
            aa_section "Create form $form_name"
            ###########################################################
            #
            # Create a form with date fields in different formats
            # (date is a repeated field).
            #
            ::xowiki::test::create_form \
                -last_request $request_info \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -name $form_name \
                -update [subst {
                    title "Form for miscelaneus form fields"
                    nls_language $locale
                    text {<p>@date@</p><p>@date2@</p>}
                    text.format text/html
                    form {<form>@date@ @date2@</form>}
                    form.format text/html
                    form_constraints {
                        _page_order:omit _title:omit _nls_language:omit _description:omit
                        date:date
                        {date2:date,format=DD_MONTH_YYYY_HH24_MI,default=2011-01-01 20:55,disabled}
                    }
                }]
            aa_log "Form $form_name created"


            set page_name $lang:m1
            ###########################################################
            aa_section "Create an instance $page_name of $form_name"
            ###########################################################

            ::xowiki::test::create_form_page \
                -last_request $request_info \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -form_name $form_name \
                -update [subst {
                    _name $page_name
                    _title "fresh $page_name"
                    _nls_language $locale
                }]

            aa_log "Page $page_name created"

            set extra_url_parameter {{m edit}}
            aa_log "Check content of the fresh instance"
            set d [acs::test::http -last_request $request_info \
                       [export_vars -base $instance/$testfolder/$page_name $extra_url_parameter]]
            acs::test::reply_has_status_code $d 200

            set response [dict get $d body]
            acs::test::dom_html root $response {
                set f_id     [::xowiki::test::get_object_name $root]
                set CSSclass [::xowiki::test::get_form_CSSclass $root]
                aa_true "page_name '$f_id' non empty" {$f_id ne ""}
                aa_true "CSSclass: '$CSSclass' non empty"  {$CSSclass ne ""}
                set id_part F.[string map {: _} $page_name]
                set input1 [$root getElementById $id_part.date.DD]
                set input2 [$root getElementById $id_part.date.month]
                set input3 [$root getElementById $id_part.date.YYYY]
                aa_true "input1 (1st element of date)" {$input1 ne ""}
                aa_true "input2 (2nd element of date)" {$input2 ne ""}
                aa_true "input3 (3rd element of date)" {[$input3 getAttribute value] eq ""}

                set input4 [$root selectNodes \
                                "//select\[@id='$id_part.date2.DD'\]/option\[@selected\]"]
                set input5 [$root selectNodes \
                                "//select\[@id='$id_part.date2.month'\]/option\[@selected\]"]
                set input6 [$root getElementById $id_part.date2.YYYY]
                set input7 [$root selectNodes \
                                "//select\[@id='$id_part.date2.HH24'\]/option\[@selected\]"]
                set input8 [$root selectNodes \
                                "//select\[@id='$id_part.date2.MI'\]/option\[@selected\]"]
                aa_true "input4 (1st element of date2)" {[$input4 getAttribute value] eq "1"}
                aa_true "input5 (2nd element of date2)" {[$input5 getAttribute value] eq "1"}
                aa_true "input6 (3rd element of date2)" {[$input6 getAttribute value] eq "2011"}
                aa_true "input7 (4th element of date2)" {[$input7 getAttribute value] eq "20"}
                aa_true "input8 (5th element of date2)" {[$input8 getAttribute value] eq "55"}
            }

            ################################################################################
            aa_section "Edit an instance $page_name of $form_name to set the dates"
            ################################################################################

            ::xowiki::test::edit_form_page \
                -last_request $request_info \
                -instance $instance \
                -path $testfolder/$page_name \
                -update [subst {
                    _title "edited $page_name"
                    date.DD 1
                    date.month 1
                    date.YYYY 2022

                    date2.YYYY 2021
                }]

            aa_log "Check content of the edited instance"
            set d [acs::test::http -user_info $user_info \
                       [export_vars -base $instance/$testfolder/$page_name $extra_url_parameter]]
            acs::test::reply_has_status_code $d 200

            #ns_log notice CONTENT=[::xowiki::test::get_content $d]
            acs::test::dom_html root [::xowiki::test::get_content $d] {
                set id_part F.[string map {: _} $page_name]
                set input1 [$root selectNodes "//select\[@id='$id_part.date.DD'\]/option\[@value='1'\]"]
                set input2 [$root selectNodes "//select\[@id='$id_part.date.month'\]/option\[@value='1'\]"]
                set input3 [$root getElementById $id_part.date.YYYY]
                aa_true "input1 (1st element of date)" {$input1 ne ""}
                aa_true "input2 (2nd element of date)" {$input2 ne ""}
                aa_true "input3 (3rd element of date)" {[$input3 getAttribute value] eq "2022"}
                foreach v [list $input1 $input2] {
                    if {$v eq ""} continue
                    aa_true "input selected '[$v getAttribute selected]'" \
                        {[$v getAttribute selected] eq "selected"}
                }

                set input4 [$root getElementById $id_part.date2.YYYY]
                aa_true "input4 (year element of date2)" {[$input4 getAttribute value] eq "2011"}
            }


            set form_name $lang:Repeat.form
            ###########################################################
            aa_section "Create form $form_name"
            ###########################################################
            #
            # Create a form with a repeated field.
            #
            ::xowiki::test::create_form \
                -last_request $request_info \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -name $form_name \
                -update [subst {
                    title "Repeat Form"
                    nls_language $locale
                    text {<p>@txt@</p>}
                    text.format text/html
                    form {<form>@txt@</form>}
                    form.format text/html
                    form_constraints {
                        _page_order:omit _title:omit _nls_language:omit _description:omit
                        txt:text,repeat=1..5,default=t1
                    }
                }]
            aa_log "Form $form_name created"


            set page_name $lang:r1
            ###########################################################
            aa_section "Create an instance $page_name of $form_name"
            ###########################################################

            ::xowiki::test::create_form_page \
                -last_request $request_info \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -form_name $form_name \
                -update [subst {
                    _name $page_name
                    _title "fresh $page_name"
                    _nls_language $locale
                }]

            aa_log "Page $page_name created"

            set extra_url_parameter {{m edit}}
            aa_log "Check content of the fresh instance"
            set d [acs::test::http -last_request $request_info \
                       [export_vars -base $instance/$testfolder/$page_name $extra_url_parameter]]
            acs::test::reply_has_status_code $d 200

            set response [dict get $d body]
            acs::test::dom_html root $response {
                set f_id     [::xowiki::test::get_object_name $root]
                set CSSclass [::xowiki::test::get_form_CSSclass $root]
                aa_true "page_name '$f_id' non empty" {$f_id ne ""}
                aa_true "CSSclass: '$CSSclass' non empty"  {$CSSclass ne ""}
                set id_part F.[string map {: _} $page_name]
                set input1 [$root getElementById $id_part.txt.1]
                set input2 [$root getElementById $id_part.txt.2]
                aa_equals "input1 (1st element of repeated field)" [$input1 getAttribute value] t1
                aa_equals "input2 (2nd element of repeated field)" "" ""
            }

            ################################################################################
            aa_section "Edit an instance $page_name of $form_name to add 2nd repeated field"
            ################################################################################

            ::xowiki::test::edit_form_page \
                -last_request $request_info \
                -instance $instance \
                -path $testfolder/$page_name \
                -update [subst {
                    _title "edited $page_name"
                    txt.2 t2
                }]

            aa_log "Check content of the edited instance"
            set d [acs::test::http -user_info $user_info \
                       [export_vars -base $instance/$testfolder/$page_name $extra_url_parameter]]
            acs::test::reply_has_status_code $d 200

            #ns_log notice CONTENT=[::xowiki::test::get_content $d]

            acs::test::dom_html root [::xowiki::test::get_content $d] {
                set id_part F.[string map {: _} $page_name]
                set input1 [$root getElementById $id_part.txt.1]
                set input2 [$root getElementById $id_part.txt.2]
                aa_log "input1 '$input1' input2 '$input2'"
                aa_equals "input1 (1st element of repeated field)" [$input1 getAttribute value] t1
                aa_equals "input2 (2nd element of repeated field)" [$input2 getAttribute value] t2
            }

            set form_name $lang:repeated-compound.form
            ###########################################################
            aa_section "Create Form $form_name"
            ###########################################################

            #
            # We now generate a form where a nested compound field is
            # used as as template for a repeated field.
            #

            ::xowiki::test::create_form \
                -last_request $request_info \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -name $form_name \
                -update [subst {
                    title "Repeated Compound Form"
                    nls_language $locale
                    text {<p>@_text@</p><p>@mycompoundwithrepeat@</p>}
                    text.format text/html
                    form {<form>@mycompoundwithrepeat@</form>}
                    form.format text/html
                    form_constraints {
                        _page_order:omit _title:omit _nls_language:omit _description:omit
                        {mycompoundwithrepeat:regression_test_compound_with_repeat,label=The Compound With Repeat}
                    }
                }]
            aa_log "Form $form_name created"

            set page_name $lang:rc1
            ###########################################################
            aa_section "Create an instance of $form_name named '$page_name'"
            ###########################################################

            ::xowiki::test::create_form_page \
                -last_request $request_info \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -form_name $form_name \
                -update [subst {
                    _name $page_name
                    _title "fresh $page_name"
                    _nls_language $locale
                }]

            aa_log "Page $page_name created"

            set extra_url_parameter {{m edit}}
            aa_log "Check content of the fresh instance"
            set d [acs::test::http -last_request $request_info \
                       [export_vars -base $instance/$testfolder/$page_name $extra_url_parameter]]
            acs::test::reply_has_status_code $d 200

            ::xowiki::test::edit_form_page \
                -last_request $request_info \
                -instance $instance \
                -path $testfolder/$page_name \
                -update [subst {
                    _title "edited $page_name"
                    mycompoundwithrepeat.acheckbox X

                    mycompoundwithrepeat.arepeatedcompound.1.anumber 1
                    mycompoundwithrepeat.arepeatedcompound.1.acheckbox C

                    mycompoundwithrepeat.arepeatedcompound.2.anumber 2
                    mycompoundwithrepeat.arepeatedcompound.2.acheckbox B

                    mycompoundwithrepeat.arepeatedcompound.3.anumber 3
                    mycompoundwithrepeat.arepeatedcompound.3.acheckbox A

                    mycompoundwithrepeat.arepeatedcompound.4.anumber 4
                }]

            aa_log "Check content of the edited instance"
            set d [acs::test::http -user_info $user_info \
                       [export_vars -base $instance/$testfolder/$page_name $extra_url_parameter]]
            acs::test::reply_has_status_code $d 200

            set response [dict get $d body]
            acs::test::dom_html root $response {
                set f_id     [::xowiki::test::get_object_name $root]
                set CSSclass [::xowiki::test::get_form_CSSclass $root]
                aa_true "page_name '$f_id' non empty" {$f_id ne ""}
                aa_true "CSSclass: '$CSSclass' non empty"  {$CSSclass ne ""}
                set id_part [string map {: _} $page_name]
                set radio1 [$root getElementById F.$id_part.mycompoundwithrepeat.aradio:X]
                set radio2 [$root getElementById F.$id_part.mycompoundwithrepeat.aradio:Y]
                set radio3 [$root getElementById F.$id_part.mycompoundwithrepeat.aradio:Z]
                aa_equals "Radio 'X' not checked"   [$radio1 hasAttribute checked] 0
                aa_equals "Radio 'Y' not checked"   [$radio2 hasAttribute checked] 0
                aa_equals "Radio 'Z' not checked"   [$radio3 hasAttribute checked] 0

                set anumber_3 [$root getElementById F.$id_part.mycompoundwithrepeat.arepeatedcompound.3.anumber]
                # Note: we check on purpose for math equality, not string equality
                aa_true "Number in 3rd repeat field is correct" {[$anumber_3 getAttribute value] == 3}
                set acheckbox_3_a [$root getElementById F.$id_part.mycompoundwithrepeat.arepeatedcompound.3.acheckbox:A]
                set acheckbox_3_b [$root getElementById F.$id_part.mycompoundwithrepeat.arepeatedcompound.3.acheckbox:B]
                set acheckbox_3_c [$root getElementById F.$id_part.mycompoundwithrepeat.arepeatedcompound.3.acheckbox:C]
                aa_equals "Checkbox in 3rd repeat field 'A' checked"     [$acheckbox_3_a hasAttribute checked] 1
                aa_equals "Checkbox in 3rd repeat field 'B' not checked" [$acheckbox_3_b hasAttribute checked] 0
                aa_equals "Checkbox in 3rd repeat field 'C' not checked" [$acheckbox_3_c hasAttribute checked] 0
            }

            ::xowiki::test::edit_form_page \
                -last_request $request_info \
                -instance $instance \
                -path $testfolder/$page_name \
                -update [subst {
                    _title "twice-edited $page_name"

                    mycompoundwithrepeat.arepeatedcompound.3.aselect B
                }]

            aa_log "Check content of the twice-edited instance"
            set d [acs::test::http -user_info $user_info \
                       [export_vars -base $instance/$testfolder/$page_name $extra_url_parameter]]
            acs::test::reply_has_status_code $d 200

            set response [dict get $d body]
            acs::test::dom_html root $response {
                set f_id     [::xowiki::test::get_object_name $root]
                set CSSclass [::xowiki::test::get_form_CSSclass $root]
                aa_true "page_name '$f_id' non empty" {$f_id ne ""}
                aa_true "CSSclass: '$CSSclass' non empty"  {$CSSclass ne ""}
                set id_part [string map {: _} $page_name]
                set radio1 [$root getElementById F.$id_part.mycompoundwithrepeat.aradio:X]
                set radio2 [$root getElementById F.$id_part.mycompoundwithrepeat.aradio:Y]
                set radio3 [$root getElementById F.$id_part.mycompoundwithrepeat.aradio:Z]
                aa_equals "Radio 'X' not checked"   [$radio1 hasAttribute checked] 0
                aa_equals "Radio 'Y' not checked"   [$radio2 hasAttribute checked] 0
                aa_equals "Radio 'Z' not checked"   [$radio3 hasAttribute checked] 0

                set anumber_3 [$root getElementById F.$id_part.mycompoundwithrepeat.arepeatedcompound.3.anumber]
                # Note: we check on purpose for math equality, not string equality
                aa_true "Number in 3rd repeat field is correct" {[$anumber_3 getAttribute value] == 3}
                set acheckbox_3_a [$root getElementById F.$id_part.mycompoundwithrepeat.arepeatedcompound.3.acheckbox:A]
                set acheckbox_3_b [$root getElementById F.$id_part.mycompoundwithrepeat.arepeatedcompound.3.acheckbox:B]
                set acheckbox_3_c [$root getElementById F.$id_part.mycompoundwithrepeat.arepeatedcompound.3.acheckbox:C]
                aa_equals "Checkbox in 3rd repeat field 'A' checked"     [$acheckbox_3_a hasAttribute checked] 1
                aa_equals "Checkbox in 3rd repeat field 'B' not checked" [$acheckbox_3_b hasAttribute checked] 0
                aa_equals "Checkbox in 3rd repeat field 'C' not checked" [$acheckbox_3_c hasAttribute checked] 0

                set aselect_1_selected [$root selectNodes \
                                            "//select\[@id='F.$id_part.mycompoundwithrepeat.arepeatedcompound.3.aselect'\]/option\[@selected\]"]
                aa_equals "Select was set to B" [$aselect_1_selected getAttribute value] B
            }

        } on error {errorMsg} {
            aa_true "Error msg: $errorMsg" 0
        } finally {
            #
            # In case something has to be cleaned manually, do it here.
            #
            if {$package_id ne "" && $instance ne ""} {
                #set node_id [site_node::get_element -url $instance -element node_id]
                #site_node::delete -node_id $node_id -delete_package
            }
        }
    }

    aa_register_case -cats {web} -procs {
        "::acs::test::dom_html"
        "::acs::test::http"
        "::acs::test::reply_has_status_code"
        "::acs::test::require_package_instance"
        "::acs::test::user::create"
        "::lang::system::locale"
        "::lang::user::locale"
        "::lang::user::set_locale"
        "::xowiki::Page instproc www-create-new"
        "::xowiki::Page instproc www-edit"
        "::xowiki::test::create_form"
        "::xowiki::test::create_form_page"
        "::xowiki::test::edit_form_page"
        "::xowiki::test::get_form_CSSclass"
        "::xowiki::test::get_object_name"
        "::xowiki::test::require_test_folder"

        "::xowiki::FormPage instproc load_values_into_form_fields"
    } create_form_with_numeric {

        Create an xowiki form and an instance of this form.  Here we
        test primarily the numeric field with its interactions to
        preferred language settings.

    } {
        #
        # Setup of test user_id and login
        #
        set user_info [::acs::test::user::create -email xowiki@acs-testing.test -admin]
        set request_info [::acs::test::login $user_info]

        set instance /xowiki-test
        set package_id [::acs::test::require_package_instance \
                            -package_key xowiki \
                            -empty \
                            -instance_name $instance]
        set testfolder .testfolder

        try {
            ###########################################################
            aa_section "Require test folder"
            ###########################################################

            set folder_info [::xowiki::test::require_test_folder \
                                 -last_request $request_info \
                                 -instance $instance \
                                 -folder_name $testfolder \
                                 -fresh \
                                ]

            set folder_id  [dict get $folder_info folder_id]
            set package_id [dict get $folder_info package_id]
            aa_true "folder_id '$folder_id' is not 0" {$folder_id != 0}

            ###########################################################
            aa_section "Check locales"
            ###########################################################
            set installed_locales [lang::system::get_locales]
            # en_US must be always in installed_locales
            #
            # The tests below check conversion from to values with
            # decimal points and decimal commas. This test can only be
            # performed, when the locale of the package
            # (package_locale) to be tested is installed and loaded,
            # and its decimal point is a comma.
            #
            set package_locale [lang::conn::locale -package_id $package_id]
            set user_locale en_US
            foreach locale $installed_locales {
                if {[lang::message::lookup $locale acs-lang.localization-decimal_point .] eq ","} {
                    set user_locale $locale
                    break
                }
            }
            aa_log "package_locale $package_locale user_locale $user_locale"

            if {$user_locale ne "en_US"} {
                aa_log "perform tests with user_locale $user_locale (assuming the decimal point is a comma)"
                set test_user_id [dict get $user_info user_id]

                lang::user::set_locale -user_id $test_user_id "en_US"
                aa_equals "check if locale of test_user can be set to en_US" \
                    [lang::user::locale -user_id $test_user_id] en_US

                lang::user::set_locale -user_id $test_user_id $user_locale
                aa_equals "check if locale of test_user can be set to $user_locale" \
                    [lang::user::locale -user_id $test_user_id] $user_locale

                set locale [lang::system::locale]
                set lang [string range $locale 0 1]
                set form_name en:numeric-testing.form

                ###########################################################
                aa_section "Create Form $form_name"
                ###########################################################
                #
                ::xowiki::test::create_form \
                    -last_request $request_info \
                    -instance $instance \
                    -path $testfolder \
                    -parent_id $folder_id \
                    -name $form_name \
                    -update [subst {
                        title "Numeric Testing Form"
                        nls_language en_US
                        text {
                            <p>
                               @numeric@
                               @nums@
                               @mycompoundnumeric@
                            </p>
                        }
                        text.format text/html
                        form {
                            <form>
                               @numeric@
                               @nums@
                               @mycompoundnumeric@
                            </form>
                        }
                        form.format text/html
                        form_constraints {
                            _page_order:omit _title:omit _nls_language:omit _description:omit
                            {numeric:numeric}
                            {nums:numeric,repeat=1..3}
                            mycompoundnumeric:regression_test_compound_numeric
                        }
                    }]
                aa_log "Form $form_name created"

                set page_name en:num1
                ###########################################################
                aa_section "Create an instance of $form_name named '$page_name'"
                ###########################################################

                #
                # provide the value "1.2" and "6.66" as the
                # numeric value in the compound field
                #
                ::xowiki::test::create_form_page \
                    -last_request $request_info \
                    -instance $instance \
                    -path $testfolder \
                    -parent_id $folder_id \
                    -form_name $form_name \
                    -update [subst {
                        _name $page_name
                        _title "fresh $page_name"
                        _nls_language $locale
                        numeric 1.2
                        nums.1 1.1
                        nums.2 1.2
                        mycompoundnumeric.anumber 6.66
                    }]

                aa_log "Page $page_name created"

                ###########################################################
                aa_section "Edit $form_name named '$page_name'"
                ###########################################################
                set extra_url_parameter {{m edit}}
                aa_log "Edit page with $page_name [lang::user::locale -user_id $test_user_id]"
                set d [acs::test::http -last_request $request_info \
                           [export_vars -base $instance/$testfolder/$page_name $extra_url_parameter]]
                acs::test::reply_has_status_code $d 200

                set response [dict get $d body]
                acs::test::dom_html root $response {
                    set f_id     [::xowiki::test::get_object_name $root]
                    set CSSclass [::xowiki::test::get_form_CSSclass $root]
                    aa_true "page_name '$f_id' non empty" {$f_id ne ""}
                    aa_true "CSSclass: '$CSSclass' non empty"  {$CSSclass ne ""}
                    set id_part [string map {: _} $page_name]
                    set node [$root getElementById F.$id_part.numeric]
                    aa_true "initial numeric field is found" {$node ne ""}

                    set value [$node getAttribute value]
                    aa_equals "initial numeric value is '$value'" $value "1,20"

                    set node [$root getElementById F.$id_part.mycompoundnumeric.anumber]
                    aa_true "initial compound numeric field is found" {$node ne ""}

                    set value [$node getAttribute value]
                    aa_equals "initial compound numeric value is '$value'" $value "6,66"
                }

                ###########################################################
                aa_section "Edit and change $form_name named '$page_name'"
                ###########################################################
                ::xowiki::test::edit_form_page \
                    -last_request $d \
                    -instance $instance \
                    -path $testfolder/$page_name \
                    -update [subst {
                        _title "edited $page_name"
                        numeric "1,3"
                        nums.1 "1,11"
                        nums.2 "1,21"
                        mycompoundnumeric.anumber "6,7"
                    }]

                set d [acs::test::http -last_request $request_info \
                           [export_vars -base $instance/$testfolder/$page_name $extra_url_parameter]]
                acs::test::reply_has_status_code $d 200
                set response [dict get $d body]
                acs::test::dom_html root $response {
                    set f_id    [::xowiki::test::get_object_name $root]
                    set id_part [string map {: _} $page_name]
                    set node    [$root getElementById F.$id_part.numeric]
                    set value   [$node getAttribute value]
                    aa_equals "edit numeric value is '$value'" $value "1,30"

                    set node  [$root getElementById F.$id_part.nums.1]
                    set value [$node getAttribute value]
                    aa_equals "edit compound numeric value is '$value'" $value "1,11"

                    set compoundNumNode [$root getElementById F.$id_part.mycompoundnumeric.anumber]
                    set compoundNumValue [$compoundNumNode getAttribute value]
                    aa_equals "edit compound numeric value is '$compoundNumValue'" $compoundNumValue "6,70"
                }

                ###########################################################
                aa_section "Edit in en_US $form_name named '$page_name'"
                ###########################################################
                #
                # We have now the numeric value with the comma, now
                # change language to en. The value displayed (in edit
                # field, or in view should be now the value with the
                # period).
                #
                lang::user::set_locale -user_id $test_user_id "en_US"
                set d [acs::test::http -last_request $request_info \
                           [export_vars -base $instance/$testfolder/$page_name $extra_url_parameter]]
                acs::test::reply_has_status_code $d 200
                set response [dict get $d body]
                acs::test::dom_html root $response {
                    set f_id    [::xowiki::test::get_object_name $root]
                    set id_part [string map {: _} $page_name]
                    set node  [$root getElementById F.$id_part.numeric]
                    set value [$node getAttribute value]
                    aa_equals "en_US numeric value is '$value'" $value "1.30"

                    set node  [$root getElementById F.$id_part.nums.1]
                    set value [$node getAttribute value]
                    aa_equals "en_US compound numeric value is '$value'" $value "1.11"

                    set node  [$root getElementById F.$id_part.mycompoundnumeric.anumber]
                    set value [$node getAttribute value]
                    aa_equals "en_US compound numeric value is '$value'" $value "6.70"
                }


            } else {
                aa_log "This test needs a locale with the decimal point set to comma, installed locales '[lang::system::get_locales]'"
            }

        } on error {errorMsg} {
            aa_true "Error msg: $errorMsg" 0
        } finally {
            #
            # In case something has to be cleaned manually, do it here.
            #
            if {$package_id ne "" && $instance ne ""} {
                set node_id [site_node::get_element -url $instance -element node_id]
                site_node::delete -node_id $node_id -delete_package
            }
        }
    }


    aa_register_case -cats {web} -procs {
        "::acs::test::dom_html"
        "::acs::test::http"
        "::acs::test::reply_has_status_code"
        "::acs::test::require_package_instance"
        "::acs::test::user::create"
        "::export_vars"
        "::lang::system::locale"
        "::xowiki::test::create_form"
        "::xowiki::test::create_form_page"
        "::xowiki::test::edit_form_page"
        "::xowiki::test::get_form_CSSclass"
        "::xowiki::test::get_object_name"
        "::xowiki::test::require_test_folder"
        "::xowiki::Page instproc www-create-new"
        "::xowiki::Page instproc www-edit"

    } form_validate {

        Create an xowiki form and an instance of this form.  The
        instance contains validation errors.

    } {
        #
        # Setup of test user_id and login
        #
        set user_info [::acs::test::user::create -email xowiki@acs-testing.test -admin]
        set request_info [::acs::test::login $user_info]

        set instance /xowiki-test
        set package_id [::acs::test::require_package_instance \
                            -package_key xowiki \
                            -empty \
                            -instance_name $instance]
        set testfolder .testfolder

        try {
            ###########################################################
            aa_section "Require test folder"
            ###########################################################

            set folder_info [::xowiki::test::require_test_folder \
                                 -last_request $request_info \
                                 -instance $instance \
                                 -folder_name $testfolder \
                                 -fresh \
                                ]

            set folder_id  [dict get $folder_info folder_id]
            set package_id [dict get $folder_info package_id]
            aa_true "folder_id '$folder_id' is not 0" {$folder_id != 0}

            set locale [lang::system::locale]
            set lang [string range $locale 0 1]
            set form_name $lang:validation.form
            ###########################################################
            aa_section "Create Form $form_name"
            ###########################################################

            #
            # The created form contains fields to be validated.
            #

            ::xowiki::test::create_form \
                -last_request $request_info \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -name $form_name \
                -update [subst {
                    title "Validation Form"
                    nls_language $locale
                    text {}
                    text.format text/html
                    form {<form>@number@</form>}
                    form.format text/plain
                    form_constraints {
                        number:numeric
                    }
                }]
            aa_log "Form $form_name created"

            ###########################################################
            aa_section "Create an instance of $form_name named '${lang}:validate1'"
            ###########################################################
            set page_name ${lang}:validate1

            #
            # A FormPage title containing a javascript injection
            # attempt.
            #
            set title "fresh $page_name for validation <script>console.log('Injected!');</script>"

            set d [::xowiki::test::create_form_page \
                       -last_request $request_info \
                       -instance $instance \
                       -path $testfolder \
                       -parent_id $folder_id \
                       -form_name $form_name \
                       -expect_validation_error "Invalid numeric value" \
                       -update [subst {
                           _name "$page_name"
                           _title "$title"
                           _nls_language $locale
                           number a
                       }]]

            #ns_log notice "::xowiki::test::create_form_page returns $d"
            acs::test::reply_has_status_code $d 200

            set response [dict get $d body]
            acs::test::dom_html root $response {
                set f_id [::xowiki::test::get_object_name $root]
                aa_true "page_name '$f_id' non empty" {$f_id ne ""}

                #
                # The title displayed in the form field should be the
                # one coming from the rejected FormPage in order for
                # the user to receive feedback and rework their
                # submission.
                #
                set new_title [$root getElementById F.$f_id._title]
                aa_equals "_title stays '[ns_quotehtml $title]'" $title [$new_title getAttribute value]

                #
                # On a standard installation, the page title is set to
                # the (potentially no yet validated) FormPage title. Here
                # we make sure that our injection attempt has not been
                # rendered "raw" to the client.
                #
                aa_false "Unvalidated title '[ns_quotehtml $title]' was NOT used unquoted in the response" \
                    [string match *$title* $response]

                set new_number [$root getElementById F.$f_id.number]
                aa_equals "number stays 'a'" a [$new_number getAttribute value]
            }

        } on error {errorMsg} {
            aa_true "Error msg: $errorMsg" 0
        } finally {
            #
            # In case something has to be cleaned manually, do it here.
            #
            if {$package_id ne "" && $instance ne ""} {
                set node_id [site_node::get_element -url $instance -element node_id]
                site_node::delete -node_id $node_id -delete_package
            }
        }
    }


    aa_register_case -cats {web} -procs {
        "::acs::test::dom_html"
        "::acs::test::http"
        "::acs::test::reply_has_status_code"
        "::acs::test::require_package_instance"
        "::acs::test::user::create"
        "::xowiki::Page instproc save_new"
        "::xowiki::Page instproc pretty_link"
        "::xowiki::Page instproc create_link"
        "::xowiki::Page instproc anchor"
        "::xowiki::Page instproc substitute_markup"
        "::xowiki::File instproc save_new"

        "::ad_returnfile_background"
    } nested_self_references {

        Create a parent page, a child page and then an image stored
        under the child page. The child page references the image
        using .SELF., while the parent includes the child page.

        Make sure that the image is correctly included inside of both
        pages when they are rendered.

    } {
        #
        # Setup of test user_id and login
        #
        set user_info [::acs::test::user::create -email xowiki@acs-testing.test -admin]
        set request_info [::acs::test::login $user_info]

        set instance /xowiki-test
        set package_id [::acs::test::require_package_instance \
                            -package_key xowiki \
                            -empty \
                            -instance_name $instance]
        set testfolder .testfolder

        try {
            ###########################################################
            aa_section "Require test folder"
            ###########################################################

            set folder_info [::xowiki::test::require_test_folder \
                                 -last_request $request_info \
                                 -instance $instance \
                                 -folder_name $testfolder \
                                 -fresh \
                                ]

            set folder_id  [dict get $folder_info folder_id]
            set package_id [dict get $folder_info package_id]
            aa_true "folder_id '$folder_id' is not 0" {$folder_id != 0}

            aa_section "Create father page 'en:father'"
            set parent_page [::xowiki::Page new \
                                 -destroy_on_cleanup \
                                 -title "I am your father, Hello World" \
                                 -name en:father \
                                 -package_id $package_id \
                                 -parent_id $folder_id \
                                 -text {{
                                     {{en:father/hello}}
                                 } "text/plain"}]
            $parent_page save_new

            aa_section "Create child page 'en:hello'"
            set page [::xowiki::Page new \
                          -destroy_on_cleanup \
                          -title "Hello World" \
                          -name en:hello \
                          -package_id $package_id \
                          -parent_id [$parent_page item_id] \
                          -text {{
                              [[.SELF./image:hello_file|Hello File]]
                          } "text/plain"}]
            $page save_new

            aa_section "Create image 'file:hello_file' as child of child page"
            set file_object [::xowiki::File new \
                                 -destroy_on_cleanup \
                                 -title "Hello World File" \
                                 -name file:hello_file \
                                 -parent_id [$page item_id] \
                                 -mime_type image/png \
                                 -package_id $package_id \
                                 -creation_user [dict get $user_info user_id]]
            $file_object set import_file \
                $::acs::rootdir/packages/acs-templating/www/resources/sort-ascending.png
            $file_object save_new
            aa_true "$file_object was saved" [nsf::is integer [$file_object item_id]]

            aa_section "load [$parent_page name] and check links"
            set d [acs::test::http -last_request $request_info [$parent_page pretty_link]]
            acs::test::reply_has_status_code $d 200
            acs::test::dom_html root [dict get $d body] {
                set images [lmap p [$root selectNodes {//img[@class='image']/@src}] {file tail [lindex $p 1]}]
                set file_urls [lmap p [$root selectNodes {//img[@class='image']/@src}] {lindex $p 1}]
            }

            aa_true "File was found on the page" {"hello_file" in $images}
            foreach file_url $file_urls {
                set d [acs::test::http -last_request $request_info $file_url]
                acs::test::reply_has_status_code $d 200
                set content_type [ns_set iget [dict get $d headers] content-type]
                aa_equals "Content type of $file_url is an image" image/png $content_type
            }

            aa_section "load [$page name] and check links"
            set d [acs::test::http -last_request $request_info [$page pretty_link]]
            acs::test::reply_has_status_code $d 200
            acs::test::dom_html root [dict get $d body] {
                set images [lmap p [$root selectNodes {//img[@class='image']/@src}] {file tail [lindex $p 1]}]
                set file_urls [lmap p [$root selectNodes {//img[@class='image']/@src}] {lindex $p 1}]
            }

            aa_true "File was found on the page" [expr {"hello_file" in $images}]
            foreach file_url $file_urls {
                set d [acs::test::http -last_request $request_info $file_url]
                acs::test::reply_has_status_code $d 200
                set content_type [ns_set iget [dict get $d headers] content-type]
                aa_equals "Content type is an image" image/png $content_type
            }

        } on error {errorMsg} {
            aa_true "Error msg: $errorMsg" 0
        } finally {
            #
            # In case something has to be cleaned manually, do it here.
            #
            if {$package_id ne "" && $instance ne ""} {
                set node_id [site_node::get_element -url $instance -element node_id]
                site_node::delete -node_id $node_id -delete_package
            }
        }
    }

    aa_register_case -cats {web} -procs {
        "::xowiki::Page instproc www-create-new"
    } create_folder_and_configure {

        Create an xowiki FormPage and provide the configure query_parameter.

    } {
        #
        # Setup of test user_id and login
        #
        set user_info [::acs::test::user::create -email xowiki@acs-testing.test -admin]
        set request_info [::acs::test::login $user_info]

        set instance /xowiki-test
        set package_id [::acs::test::require_package_instance \
                            -package_key xowiki \
                            -empty \
                            -instance_name $instance]
        set testfolder .testfolder

        try {
            ###########################################################
            aa_section "Require test folder"
            ###########################################################

            set folder_info [::xowiki::test::require_test_folder \
                                 -last_request $request_info \
                                 -instance $instance \
                                 -folder_name $testfolder \
                                 -extra_url_parameter {{p.configure regression_test}} \
                                 -fresh \
                                ]

            set folder_id  [dict get $folder_info folder_id]
            set package_id [dict get $folder_info package_id]
            aa_true "folder_id '$folder_id' is not 0" {$folder_id != 0}

            set folder [::xo::db::CrClass get_instance_from_db -item_id $folder_id]
            set folder_description [$folder description]
            aa_true "folder_description = '$folder_description'" {$folder_description eq "foo"}

        } on error {errorMsg} {
            aa_true "Error msg: $errorMsg" 0
        } finally {
            #
            # In case something has to be cleaned manually, do it here.
            #
            if {$package_id ne "" && $instance ne ""} {
                set node_id [site_node::get_element -url $instance -element node_id]
                site_node::delete -node_id $node_id -delete_package
            }
        }
    }


    aa_register_case -cats {web} -procs {

        "::xo::db::CrClass proc id_belongs_to_package"

    } check_page_template_constraint {

        Document and enforce the expected behavior when Forms are
        deleted: this is forbidden and will return an error as long as
        they have instances.

        @see https://cvs.openacs.org/changelog/OpenACS?cs=oacs-5-10%3Agustafn%3A20220613165033

    } {

        #
        # Create a new admin user and login
        #
        #
        # Setup of test user_id and login
        #
        set user_info [::acs::test::user::create -email xowiki@acs-testing.test -admin]
        set request_info [::acs::test::login $user_info]

        set instance /xowiki-test
        set package_id [::acs::test::require_package_instance \
                            -package_key xowiki \
                            -empty \
                            -instance_name $instance]
        set testfolder .testfolder

        try {
            ###########################################################
            aa_section "Require test folder"
            ###########################################################

            set folder_info [::xowiki::test::require_test_folder \
                                 -last_request $request_info \
                                 -instance $instance \
                                 -folder_name $testfolder \
                                 -fresh \
                                ]

            set folder_id  [dict get $folder_info folder_id]
            set package_id [dict get $folder_info package_id]
            aa_true "folder_id '$folder_id' is not 0" {$folder_id != 0}

            set locale [lang::system::locale]
            set lang [string range $locale 0 1]
            set form_name $lang:the-form.form
            ###########################################################
            aa_section "Create Form $form_name"
            ###########################################################

            set form_info [::xowiki::test::create_form \
                -last_request $request_info \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -name $form_name \
                -update [subst {
                    title "Some Basic Form"
                    nls_language $locale
                    text {<p>I am a form</p>}
                    text.format text/html
                    form {<form></form>}
                    form.format text/html
                    form_constraints {}
                    anon_instances t
                }]]
            aa_log "Form $form_name created"

            set page_name $lang:the-form-instance
            ###########################################################
            aa_section "Create an instance of $form_name named '$page_name'"
            ###########################################################

            set page_info [::xowiki::test::create_form_page \
                -last_request $request_info \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -form_name $form_name \
                -update [subst {
                    _name $page_name
                    _title "fresh $page_name"
                    _nls_language $locale
                }]]

            aa_log "Page $page_name created"

            ###########################################################
            aa_section "Delete form $form_name when we have instances"
            ###########################################################

            set item_id [dict get $page_info item_id]

            set form_id [::xo::dc get_value get_form {
                select page_template from xowiki_form_instance_item_index
                where item_id = :item_id
            }]
            ::xowiki::Package initialize -package_id $package_id
            set form [::xo::db::CrClass get_instance_from_db -item_id $form_id]

            aa_true "Deleting a form with instances fails" [catch {
                aa_silence_log_entries -severities {error notice} {
                    $form delete
                }
            } errmsg]

            ###########################################################
            aa_section "Delete form $form_name after deleting instances"
            ###########################################################

            set page [::xo::db::CrClass get_instance_from_db -item_id $item_id]
            $page delete

            aa_false "Deleting a form without instances is OK" [catch {
                $form delete
            } errmsg]

            ###########################################################
            aa_section "Check that form and instances have been deleted"
            ###########################################################

            aa_false "Form is no more" [::xo::dc 0or1row check_form {
                select 1 from acs_objects where object_id = :form_id
            }]

            aa_false "Form instance is no more" [::xo::dc 0or1row check_form {
                select 1 from acs_objects where object_id = :item_id
            }]

        } on error {errorMsg} {
            aa_true "Error msg: $errorMsg" 0
        } finally {
            #
            # In case something has to be cleaned manually, do it here.
            #
            if {$package_id ne "" && $instance ne ""} {
                set node_id [site_node::get_element -url $instance -element node_id]
                site_node::delete -node_id $node_id -delete_package
            }
        }
    }

    aa_register_case -cats {web} check_html5_formfields {

        Test the behavior of HTML5 date and time fields.

    } {

        #
        # Create a new admin user and login
        #
        #
        # Setup of test user_id and login
        #
        set user_info [::acs::test::user::create -email xowiki@acs-testing.test -admin]
        set request_info [::acs::test::login $user_info]

        set instance /xowiki-test
        set package_id [::acs::test::require_package_instance \
                            -package_key xowiki \
                            -empty \
                            -instance_name $instance]
        set testfolder .testfolder

        try {
            ###########################################################
            aa_section "Require test folder"
            ###########################################################

            set folder_info [::xowiki::test::require_test_folder \
                                 -last_request $request_info \
                                 -instance $instance \
                                 -folder_name $testfolder \
                                 -fresh \
                                ]

            set folder_id  [dict get $folder_info folder_id]
            set package_id [dict get $folder_info package_id]
            aa_true "folder_id '$folder_id' is not 0" {$folder_id != 0}

            set locale [lang::system::locale]
            set lang [string range $locale 0 1]
            set form_name $lang:the-form.form
            ###########################################################
            aa_section "Create Form $form_name"
            ###########################################################

            set form_info [::xowiki::test::create_form \
                -last_request $request_info \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -name $form_name \
                -update [subst {
                    title "Date/time validation form"
                    nls_language $locale
                    text {}
                    text.format text/html
                    form {
                        <form>
                        @date@
                        @time@
                        @datetime@
                        </form>
                    }
                    form.format text/plain
                    form_constraints {
                        date:h5date
                        time:h5time
                        datetime:datetime-local
                    }
                }]]
            aa_log "Form $form_name created"

            set page_name $lang:the-form-instance
            ###########################################################
            aa_section "Create an instance of $form_name named '$page_name' with invalid date"
            ###########################################################

            set expected_error [::lang::message::lookup \
                                    $locale \
                                    xowiki.h5date-validate_valid_format]
            ::xowiki::test::create_form_page \
                -last_request $request_info \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -form_name $form_name \
                -expect_validation_error $expected_error \
                -update [list \
                             _name $page_name \
                             _title "fresh $page_name" \
                             _nls_language $locale \
                             date bogus \
                             time 08:00 \
                             datetime 2024-02-29T09:15 \
                            ]

            ###########################################################
            aa_section "Create an instance of $form_name named '$page_name' with invalid time"
            ###########################################################

            set expected_error [::lang::message::lookup \
                                    $locale \
                                    xowiki.h5time-validate_valid_format]
            ::xowiki::test::create_form_page \
                -last_request $request_info \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -form_name $form_name \
                -expect_validation_error $expected_error \
                -update [list \
                             _name $page_name \
                             _title "fresh $page_name" \
                             _nls_language $locale \
                             date 2024-02-29 \
                             time bogus \
                             datetime 2024-02-29T09:15 \
                            ]

            ###########################################################
            aa_section "Create an instance of $form_name named '$page_name' with invalid datetime"
            ###########################################################

            set expected_error [::lang::message::lookup \
                                    $locale \
                                    xowiki.datetime-local-validate_valid_format]
            ::xowiki::test::create_form_page \
                -last_request $request_info \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -form_name $form_name \
                -expect_validation_error $expected_error \
                -update [list \
                             _name $page_name \
                             _title "fresh $page_name" \
                             _nls_language $locale \
                             date 2024-02-29 \
                             time 08:01 \
                             datetime bogus \
                            ]

            ###########################################################
            aa_section "Create an instance of $form_name named '$page_name' with empty datetime values"
            ###########################################################

            ::xowiki::test::create_form_page \
                -last_request $request_info \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -form_name $form_name \
                -update [list \
                             _name $page_name \
                             _title "fresh $page_name" \
                             _nls_language $locale \
                            ]

            ###########################################################
            aa_section "Edit '$page_name' with proper datetime values"
            ###########################################################

            ::xowiki::test::edit_form_page \
                -last_request $request_info \
                -instance $instance \
                -path $testfolder/$page_name \
                -update [list \
                             date 2024-02-29 \
                             time 08:01 \
                             datetime 2024-02-29T08:01 \
                            ]

        } on error {errorMsg} {
            aa_true "Error msg: $errorMsg" 0
        } finally {
            #
            # In case something has to be cleaned manually, do it here.
            #
            if {$package_id ne "" && $instance ne ""} {
                set node_id [site_node::get_element -url $instance -element node_id]
                site_node::delete -node_id $node_id -delete_package
            }
        }
    }

}

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
