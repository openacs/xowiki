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
}

namespace eval ::xowiki::test {

    aa_register_init_class \
        xowiki_require_test_instance {
            Make sure the test instance is there and create it if necessary.
        } {
            aa_export_vars {_xowiki_test_instance_name}
            set _xowiki_test_instance_name /xowiki-test
            ::acs::test::require_package_instance \
                -package_key xowiki \
                -instance_name $_xowiki_test_instance_name
        } {
            # Here one might unmount the package afterwards. Right now
            # we decide to keep it so it is possible to e.g. inspect
            # the results or test further in the mounted instance.
        }

    aa_register_case \
        -init_classes {xowiki_require_test_instance} \
        -cats {smoke production_safe} \
        -procs {
            "::xowiki::Package instproc item_ref"
            "::xowiki::Package instproc resolve_page"
            "::xowiki::Package instproc item_info_from_url"
            "::xowiki::Page instproc create_link"
        } \
        path_resolve {
            Test various forms of path resolving
        } {
        aa_run_with_teardown -rollback -test_code {
            set instance $_xowiki_test_instance_name
            set testfolder .testfolder

            #
            # Force the system locale to en_US. The value is
            # automatially reset to the previous value, since we are
            # running in an transaction.
            #
            lang::system::set_locale en_US

            set locale [lang::system::locale]
            set lang [string range $locale 0 1]

            ::xowiki::Package initialize -url $_xowiki_test_instance_name
            set root_folder_id [::$package_id folder_id]
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

            set testfolder_id [::$package_id lookup -parent_id $root_folder_id -name $testfolder]
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
            aa_section "Ambigous item_refs"

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
        }
    }


    aa_register_case -init_classes {xowiki_require_test_instance} -cats {web} -procs {
        "::xo::Package instproc initialize"
        "::xowiki::Package instproc invoke"
        "::xo::Package instproc reply_to_user"
        "::xowiki::test::create_form"
        "::xowiki::test::create_form_page"
    } create_form_with_form_instance {

        Create an xowiki form and an instance of this form.  Here we
        test primarily checkboxes (plain, repeated and in a compound
        form), which are especially nasty in cases, where e.g. a
        per-default marked checkbox is unmarked. In this case, the
        server has to detect the new value by the fact that no value
        was sent by the browser.

    } {
        #
        # Run the test under the current user_id.
        #
        set user_id [ad_conn user_id]

        set instance $_xowiki_test_instance_name
        set testfolder .testfolder

        try {
            #
            # Run one upfront request to obtain the request_info, used
            # in later cases.
            #
            set request_info [acs::test::http -user_id $user_id $instance/]
            #aa_log "request_info vars: [dict keys $request_info]"
            #aa_log "request_info session [ns_quotehtml <[dict get $request_info session]>]"

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
            # unchecked, this values is NOT returned by the
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
            #    contains a default for the sub-component.

            ::xowiki::test::create_form \
                -last_request $request_info \
                -instance $instance \
                -path $testfolder \
                -parent_id $folder_id \
                -name $form_name \
                -update [subst {
                    title "Checkbox Testing Form"
                    nls_language $locale
                    text {<p>@_text@</p><p>box1 @box1@ box2 @box2@</p>}
                    text.format text/html
                    form {<form>@box1@ @box2@ @mycompound@</form>}
                    form.format text/html
                    form_constraints {
                        _page_order:omit _title:omit _nls_language:omit _description:omit
                        {box1:checkbox,options={1 1} {2 2},horizontal=true,default=1}
                        {box2:checkbox,options={a a} {b b},horizontal=true,repeat=1..3,default=a}
                        mycompound:regression_test_mycompound
                    }
                }]
            aa_log "Form  $form_name created"

            ###########################################################
            aa_section "Create an instance of $form_name named '$lang:cb1'"
            ###########################################################
            set page_name $lang:cb1

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
                set id_part [string map {: _} $page_name]
                set input_box1 [$root getElementById F.$id_part.box1:1]
                set input_box2 [$root getElementById F.$id_part.box1:2]
                set input_box3 [$root getElementById F.$id_part.box2.1:a]
                set input_box4 [$root getElementById F.$id_part.box2.1:b]
                set input_box5 [$root getElementById F.$id_part.mycompound.start_on_publish:t]
                aa_equals "input_box1 box checked (box1: simple box)"   [$input_box1 hasAttribute checked] 0
                aa_equals "input_box2 box checked (box1: simple box)"   [$input_box2 hasAttribute checked] 1
                aa_equals "input_box3 box checked (box2: repeated box)" [$input_box3 hasAttribute checked] 0
                aa_equals "input_box4 box checked (box2: repeated box)" [$input_box4 hasAttribute checked] 1
                aa_equals "input_box5 box checked (mycompound)"         [$input_box5 hasAttribute checked] 1
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
            set d [acs::test::http -user_id $user_id [export_vars -base $instance/$testfolder/$page_name $extra_url_parameter]]
            acs::test::reply_has_status_code $d 200

            set response [dict get $d body]
            acs::test::dom_html root $response {
                set id_part [string map {: _} $page_name]
                set input_box1 [$root getElementById F.$id_part.box1:1]
                set input_box2 [$root getElementById F.$id_part.box1:2]
                set input_box3 [$root getElementById F.$id_part.box2.1:a]
                set input_box4 [$root getElementById F.$id_part.box2.1:b]
                set input_box5 [$root getElementById F.$id_part.mycompound.start_on_publish:t]
                aa_equals "input_box1 box checked (box1: simple box)"   [$input_box1 hasAttribute checked] 0
                aa_equals "input_box2 box checked (box1: simple box)"   [$input_box2 hasAttribute checked] 0
                aa_equals "input_box3 box checked (box2: repeated box)" [$input_box3 hasAttribute checked] 0
                aa_equals "input_box4 box checked (box2: repeated box)" [$input_box4 hasAttribute checked] 0
                aa_equals "input_box5 box checked (mycompound)"         [$input_box5 hasAttribute checked] 0
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
                    title "Checkbox Testing Form"
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
            aa_log "Form  $form_name created"

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
                set id_part [string map {: _} $page_name]
                set input1 [$root getElementById F.$id_part.txt.1]
                set input2 [$root getElementById F.$id_part.txt.2]
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
            set d [acs::test::http -user_id $user_id \
                       [export_vars -base $instance/$testfolder/$page_name $extra_url_parameter]]
            acs::test::reply_has_status_code $d 200

            set response [dict get $d body]
            acs::test::dom_html root $response {
                set id_part [string map {: _} $page_name]
                set input1 [$root getElementById F.$id_part.txt.1]
                set input2 [$root getElementById F.$id_part.txt.2]
                aa_equals "input1 (1st element of repeated field)" [$input1 getAttribute value] t1
                aa_equals "input2 (2nd element of repeated field)" [$input2 getAttribute value] t2
            }



        } on error {errorMsg} {
            aa_true "Error msg: $errorMsg" 0
        } finally {
            #
            # In case something has to be cleaned manually, do it here.
            #
        }
    }
}
#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
