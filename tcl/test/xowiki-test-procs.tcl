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

namespace eval ::xowf::test {

    aa_register_case -cats {web} -procs {
        "::xowiki::Package instproc initialize"
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

        set instance /xowiki
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
            aa_section "Create an instance of $form_name"
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
                }]

            aa_log "Page $page_name created"

            set extra_url_parameter {{m edit}}
            aa_log "Check content of the fresh instance"
            set d [acs::test::http -last_request $request_info [export_vars -base $instance/$testfolder/$page_name $extra_url_parameter]]
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
                }]

            aa_log "Page $page_name created"

            set extra_url_parameter {{m edit}}
            aa_log "Check content of the fresh instance"
            set d [acs::test::http -last_request $request_info [export_vars -base $instance/$testfolder/$page_name $extra_url_parameter]]
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
            set d [acs::test::http -user_id $user_id [export_vars -base $instance/$testfolder/$page_name $extra_url_parameter]]
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
            #calendar::delete -calendar_id $temp_calendar_id

        }
    }
}
#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
