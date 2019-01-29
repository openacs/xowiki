namespace eval ::xowiki::test {

    ad_proc -private ::xowiki::test::get_object_name {node} {

        This proc obtains the "value" attribute of an input field
        named "__object_name". This can be used to obtain the
        object_id behind a form.  This object_id is used as well in
        the construction of HTML ids.

    } {
        return [$node selectNodes {string(//form//input[@name="__object_name"]/@value)}]
    }

    ad_proc -private ::xowiki::test::get_form_CSSclass {node} {

        Obtain the "class" attribute of a form containing in input
        field named "__object_name".

    } {
        return [$node selectNodes {string(//form//input[@name="__object_name"]/../../@class)}]
    }

    ad_proc -private ::xowiki::test::get_named_form_value {node formCSSClass name} {

        Obtain the "value" attribute of an input field with the
        provided "name" from a form identified by the "formCSSClass".

    } {
        set selector [subst {string(//form\[contains(@class,'$formCSSClass')\]//input\[@name='$name'\]/@value)}]
        ns_log notice "get_named_form_value selector = $selector"
        return [$node selectNodes  $selector]
    }

    ad_proc -private ::xowiki::test::get_form_value {node object_id name} {

        Obtain the "value" attribute of an input field identified by
        the object_id and the provided name. This kind of addressing
        is used by xowiki form instances.

    } {
        set q string(//form//input\[@id='F.$object_id.$name'\]/@value)
        return [$node selectNodes $q]
    }

    ad_proc -private ::xowiki::test::get_url_from_location {d} {
        set location [ns_set iget [dict get $d headers] Location ""]
        set url [ns_parseurl $location]
        #aa_log "parse url [ns_parseurl $location]"
        if {[dict get $url tail] ne ""} {
            set url [dict get $url path]/[dict get $url tail]
        } else {
            set url [dict get $url path]
        }
        return $url
    }

    ad_proc -private ::xowiki::test::pretty_form_content {d} {
        set pretty_form_content ""
        foreach {k v} $d {
            append  pretty_form_content "$k: $v\n"
        }
        return $pretty_form_content
    }

    ad_proc -private ::xowiki::test::get_form_values {node className} {
        return [::acs::test::xpath::get_form_values $node \
                    "//form\[contains(@class,'$className')\]" ]
    }

    ad_proc -private ::xowiki::test::get_form_action {node className} {
        return [$node selectNodes string(//form\[contains(@class,'$className')\]/@action)]
    }

    ad_proc ::xowiki::test::require_test_folder {
        -user_id:required
        -instance:required
        -folder_name:required
        {-form_name folder.form}
        {-fresh:boolean false}
        {-update ""}
        {-extra_url_parameter {}}
    } {
        Make sure a testfolder with the specified name exists in the
        top level directory of the specified instance. If this folder
        exists already, it is deleted are recreated empty.

        @param user_id the user, under which the operations should be performed
        @param instance the path leading the instance, e.g. /xowiki
        @param folder_name the name of the folder, e.g. "testfolder"
        @param fresh create a fresh folder, this means, delete a pre-existing folder first
        @return folder_id

    } {
        set must_create 1
        ::xo::Package initialize -url $instance/

        #
        # First check, if test folder exists already.
        #
        set d [acs::test::http -user_id $user_id $instance/$folder_name]
        if {[dict get $d status] == 200} {
            #
            # yes it exists - so delete it
            #
            if {$fresh_p} {
                #
                # since -fresh was specified, we delete the folder and
                # create it later again.
                #
                aa_log "test folder $folder_name exists already, ... delete it (user_id $user_id)"
                set d [acs::test::http -user_id $user_id $instance/$folder_name?m=delete&return_url=$instance/]
                if {[acs::test::reply_has_status_code $d 302]} {
                    set location [::xowiki::test::get_url_from_location $d]
                    set d [acs::test::http -user_id $user_id $location/]
                    acs::test::reply_has_status_code $d 200
                }
            } else {
                set must_create 0
            }
        }

        if {$must_create} {
            aa_log "create a fresh test folder $folder_name"
            #
            # When we try folder creation without being logged in, we
            # expect a permission denied error.
            #
            set d [acs::test::http -user_id 0 $instance/$form_name?m=create-new&return_url=$instance/]
            aa_equals "Status code valid" [dict get $d status] 403

            ::xowiki::test::create_form_page \
                -user_id $user_id \
                -instance $instance \
                -path "" \
                -autonamed \
                -parent_id [::$package_id folder_id] \
                -form_name $form_name \
                -update [subst {
                    _title "Test folder"
                    _name $folder_name
                    $update
                }] \
                -extra_url_parameter $extra_url_parameter
        }

        set new_folder_id [::$package_id lookup -name $folder_name]
        aa_log "set folder_id [::$package_id lookup -name $folder_name] ==> $new_folder_id"

        return [list folder_id $new_folder_id package_id $package_id]
    }


    ad_proc ::xowiki::test::create_form_page {
        -instance:required
        -user_id:required
        -parent_id:required
        -form_name:required
        -path:required
        {-autonamed:boolean false}
        {-update ""}
        {-extra_url_parameter {}}
    } {

        Create a form page via the web interface.
        In essence this calls $instance/$path/$form_name?m=create-new

    } {
        #
        # Create a page under the parent_id
        #
        aa_log "... create a page in test test folder $parent_id"
        set d [acs::test::http \
                   -user_id $user_id \
                   $instance/$path/$form_name?m=create-new&parent_id=$parent_id&[export_vars $extra_url_parameter]]
        acs::test::reply_has_status_code $d 302

        set location [::xowiki::test::get_url_from_location $d]
        aa_true "location '$location' is valid" {$location ne ""}

        #
        # Call "edit" method on the new page
        #
        set d [acs::test::http -user_id $user_id $location]
        acs::test::reply_has_status_code $d 200

        set formCSSClass [::xowiki::utility formCSSclass $form_name]
        set response [dict get $d body]

        acs::test::dom_html root $response {
            ::acs::test::xpath::non_empty $root [subst {
                //form\[contains(@class,'$formCSSClass')\]//button
            }]
            set f_id          [::xowiki::test::get_object_name $root]
            set f_page_name   [::xowiki::test::get_form_value $root $f_id _name]
            set f_creator     [::xowiki::test::get_form_value $root $f_id _creator]
            if {$autonamed_p} {
                aa_true "page_name '$f_page_name' is NOT empty" {$f_page_name ne ""}
            } else {
                aa_true "page_name '$f_page_name' is empty" {$f_page_name eq ""}
            }
            aa_true "creator '$f_creator' is non-empty" {$f_creator ne ""}

            set f_form_action  [::xowiki::test::get_form_action $root $formCSSClass]
            aa_true "form_action '$f_form_action' is non-empty" {$f_form_action ne ""}

            set form_content [::xowiki::test::get_form_values $root $formCSSClass]
            set names [dict keys $form_content]
            aa_log "form names: [lsort $names]"
            aa_true "page has at least 9 fields" { [llength $names] >= 9 }
        }

        set d [::acs::test::form_reply \
                   -user_id $user_id \
                   -url $f_form_action \
                   -update $update \
                   $form_content]
        acs::test::reply_has_status_code $d 302

        #set response [dict get $d body]
        #ns_log notice "FORM POST\n$response"

        foreach {key value} $update {
            dict set form_content $key $value
        }
        aa_log "form_content:\n[::xowiki::test::pretty_form_content $form_content]"

        set location [::xowiki::test::get_url_from_location $d]
        aa_true "location '$location' is valid" {$location ne ""}

        set d [acs::test::http -user_id $user_id $location]
        acs::test::reply_has_status_code $d 200

        ::xo::Package initialize -url $location
        set lang [string range [lang::system::locale] 0 1]
        set page_info [::$package_id item_ref \
                           -default_lang $lang \
                           -parent_id $parent_id \
                           [dict get $form_content _name] \
                          ]
        set item_id [dict get $page_info item_id]
        #aa_log "lookup of $folder_name/page -> $item_id"
        if {$item_id == 0} {error "Page not found"}
        ::xo::db::CrClass get_instance_from_db -item_id $item_id

        set d [acs::test::http -user_id $user_id \
                   $instance/admin/set-publish-state?state=ready&revision_id=[$item_id revision_id]]
        acs::test::reply_has_status_code $d 302
    }

    ad_proc ::xowiki::test::edit_form_page {
        -user_id:required
        -instance:required
        -path:required
        {-update ""}
        {-extra_url_parameter {{m edit}}}
    } {

        Edit a form page via the web interface.
        In essence, this calls $instance/$path?m=edit

    } {
        aa_log "... edit page $path"
        set d [acs::test::http -user_id $user_id [export_vars -base $instance/$path $extra_url_parameter]]
        acs::test::reply_has_status_code $d 200

        #set location [::xowiki::test::get_url_from_location $d]
        #aa_true "location '$location' is valid" {$location ne ""}
        set response [dict get $d body]

        acs::test::dom_html root $response {
            set f_id     [::xowiki::test::get_object_name $root]
            set CSSclass [::xowiki::test::get_form_CSSclass $root]
            aa_true "page_name '$f_id' non empty" {$f_id ne ""}
            aa_true "CSSclass: '$CSSclass' non empty"  {$CSSclass ne ""}
        }

        set form [acs::test::get_form $response "//form\[contains(@class,'$CSSclass') and @method='POST'\]"]

        set f_page_name [dict get $form fields _name]
        set f_creator   [dict get $form fields _creator]

        aa_true "page_name '$f_page_name' non empty" {$f_page_name ne ""}
        aa_true "creator '$f_creator' is non-empty" {$f_creator ne ""}

        set f_form_action  [dict get $form @action]
        aa_true "form_action '$f_form_action' is non-empty" {$f_form_action ne ""}

        set form_content [dict get $form fields]
        set names [dict keys $form_content]
        aa_log "form names: [lsort $names]"
        aa_true "page has at least 9 fields" { [llength $names] >= 9 }

        set d [::acs::test::form_reply \
                   -user_id $user_id \
                   -url $f_form_action \
                   -update $update \
                   $form_content]
        acs::test::reply_has_status_code $d 302

        foreach {key value} $update {
            dict set form_content $key $value
        }
        aa_log "form_content:\n[::xowiki::test::pretty_form_content $form_content]"

        set d [acs::test::http -user_id $user_id $instance/$path]
        acs::test::reply_has_status_code $d 200
        acs::test::reply_contains $d [dict get $form_content _title]
    }

    ad_proc ::xowiki::test::create_form {
        -user_id:required
        -instance:required
        -path:required
        -parent_id:required
        -name:required
        {-autonamed:boolean false}
        {-update ""}
    } {

        Create a form via the web interface.

    } {
        #
        # Create a form under the parent_id
        #
        aa_log "... create a new form in the test folder $parent_id"
        #
        # New form creation happens over the top-level URL
        #
        set d [acs::test::http \
                   -user_id $user_id \
                   $instance/?object_type=::xowiki::Form&edit-new=1&parent_id=$parent_id&return_url=$instance/$path]
        acs::test::reply_has_status_code $d 200

        set response [dict get $d body]
        #ns_log notice response=$response
        set formCSSClass "margin-form"

        acs::test::dom_html root $response {

            set selector [subst {string(//form\[contains(@class,'$formCSSClass')\]//input\[@type='submit'\]/@value)}]
            set f_submit [$root selectNodes $selector]
            aa_true "submit_button '$f_submit' is non empty" {$f_submit ne ""}

            set f_id     [::xowiki::test::get_object_name $root]
            aa_true "page_id '$f_id' is empty" {$f_id eq ""}
        }

        set form [acs::test::get_form $response "//form\[contains(@class,'$formCSSClass')\]"]

        set f_page_name   [dict get $form fields name]
        set f_creator     [dict get $form fields creator]
        set f_form_action [dict get $form @action]

        aa_true "name '$f_page_name' is empty"              {$f_page_name eq ""}
        aa_true "creator '$f_creator' is non-empty"         {$f_creator ne ""}
        aa_true "form_action '$f_form_action' is non-empty" {$f_form_action ne ""}

        set form_content [dict get $form fields]
        set names [dict keys $form_content]
        aa_log "form names: [lsort $names]"
        aa_true "page has at least 9 fields" { [llength $names] >= 9 }

        aa_log "empty form_content:\n$[::xowiki::test::pretty_form_content $form_content]"
        dict set form_content name $name

        set d [::acs::test::form_reply \
                   -user_id $user_id \
                   -url $f_form_action \
                   -update $update \
                   $form_content]
        acs::test::reply_has_status_code $d 302

        foreach {key value} $update {
            dict set form_content $key $value
        }
        aa_log "form_content:\n[::xowiki::test::pretty_form_content $form_content]"

        if {[dict get $d status] eq 200} {
            set response [dict get $d body]
            ns_log notice "Maybe a validation error? response\n$response"
        }

        set location [::xowiki::test::get_url_from_location $d]
        aa_true "location '$location' is valid" {$location ne ""}

        ::xo::Package initialize -url $location
        set page_info [::$package_id item_ref \
                           -default_lang en \
                           -parent_id $parent_id \
                           $name \
                          ]
        set item_id [dict get $page_info item_id]
        aa_log "lookup of form $name -> $item_id"
        ::xo::db::CrClass get_instance_from_db -item_id $item_id

        set d [acs::test::http -user_id $user_id \
                   $instance/admin/set-publish-state?state=ready&revision_id=[$item_id revision_id]]
        acs::test::reply_has_status_code $d 302
    }

}

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
