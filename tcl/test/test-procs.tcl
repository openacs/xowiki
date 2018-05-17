namespace eval ::xowiki::test {

    ad_proc -private ::xowiki::test::get_object_name {node} {
	return [$node selectNodes {string(//form//input[@name="__object_name"]/@value)}]
    }
    ad_proc -private ::xowiki::test::get_form_CSSclass {node} {
	return [$node selectNodes {string(//form//input[@name="__object_name"]/../../@class)}]
    }
    ad_proc -private ::xowiki::test::get_form_value {node id name} {
	set q string(//form//input\[@id='F.$id.$name'\]/@value)
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

    ad_proc -private ::xowiki::test::get_form_values {node className} {
	set values {}
	foreach n [$node selectNodes //form\[contains(@class,'$className')\]//input] {
	    set name  [$n getAttribute name]
	    set value [$n getAttribute value]
	    lappend values $name $value
	}
	return $values
    }
    ad_proc -private ::xowiki::test::get_form_action {node className} {
	return [$node selectNodes string(//form\[contains(@class,'$className')\]/@action)]
    }

    ad_proc -private ::xowiki::test::form_reply {
	-user_id
	-url
	{-update {}}
	form_content
    } {
	foreach {att value} $update {
	    dict set form_content $att $value
	}
	ns_log notice "final form_content $form_content"
	set export {}
	foreach {att value} $form_content {
	    lappend export [list $att $value]
	}
	set body [export_vars $export]
	ns_log notice "body=$body"
	return [aa_http \
		    -user_id $user_id \
		    -method POST -body $body \
		    -headers {Content-Type application/x-www-form-urlencoded} \
		    $url]

    }


    ad_proc ::xowiki::test::require_test_folder {
	-user_id:required
	-instance:required
	-folder_name:required
    } {
	Make sure a testfolder with the specified name exists in the
	top level directory of the specified instance. If this folder
	exists already, it is deleted are recreated empty.

	@param user_id the user, under which the operations should be performed
	@param instance the path leading the the instance, e.g. /xowiki
	@param folder_name the name of the folder, e.g. "testfolder"
	@return folder_id

    } {
	#
	# First check, if test folder exists already.
	#
	set d [aa_http -user_id $user_id $instance/$folder_name]
	if {[dict get $d status] == 200} {
	    #
	    # yes it exists - so delete it
	    #
	    aa_log "test folder $folder_name exists already, ... delete it"
	    set d [aa_http -user_id $user_id $instance/$folder_name?m=delete&return_url=$instance/]
	    aa_equals "Status code valid" [dict get $d status] 302
	    set location [::xowiki::test::get_url_from_location $d]
	    set d [aa_http -user_id $user_id $location/]
	    aa_equals "Status code valid" [dict get $d status] 200
	} else {
	    aa_log "create a frest test folder $folder_name"
	}
	
	#
	# When we try folder creation without being logged in, we
	# expect a permission denied error.
	#
	set d [aa_http -user_id 0 $instance/folder.form?m=create-new&return_url=$instance/]
	aa_equals "Status code valid" [dict get $d status] 403
	
	#
	# Try folder-creation with the current user. We expect
	# this to redirect us to the newly created form page.
	#
	set d [aa_http -user_id $user_id $instance/folder.form?m=create-new&return_url=$instance/]
	aa_equals "Status code valid" [dict get $d status] 302
	
	#
	# aa_http allows just relative URLs, so get it from the location
	#
	set location [::xowiki::test::get_url_from_location $d]
	aa_true "location '$location' is valid" {$location ne ""}
	
	#
	# Call edit method on the newly created form page
	#
	set d [aa_http -user_id $user_id $location]
	aa_equals "Status code valid" [dict get $d status] 200
	
	set response [dict get $d body]
	set formCSSClass [::xowiki::utility formCSSclass folder.form] 
	
	aa_dom_html root $response {
	    aa_xpath::non_empty $root [subst {
		//form\[contains(@class,'$formCSSClass')\]//button
	    }]
	    set f_id          [::xowiki::test::get_object_name $root]
	    set f_folder_name [::xowiki::test::get_form_value $root $f_id _name]
	    set f_creator     [::xowiki::test::get_form_value $root $f_id _creator]
	    aa_true "folder_name '$f_folder_name' is non-empty" {$f_folder_name ne ""}
	    aa_true "creator '$f_creator' is non-empty" {$f_creator ne ""}
	    
	    set f_form_action  [::xowiki::test::get_form_action $root Form-folder]
	    aa_true "form_action '$f_form_action' is non-empty" {$f_form_action ne ""}
	    
	    set form_content [::xowiki::test::get_form_values $root Form-folder]
	    set names [dict keys $form_content]
	    aa_true "form has at least 10 fields" { [llength $names] >= 10 }
	}
	
	set d [::xowiki::test::form_reply -user_id $user_id -url $f_form_action -update [subst {
	    _title "Test folder"
	    _name $folder_name
	}] $form_content]
	aa_equals "Status code valid" [dict get $d status] 302
	
	set location [::xowiki::test::get_url_from_location $d]
	aa_true "location '$location' is valid" {$location ne ""}
	
	set d [aa_http -user_id $user_id $location/]
	aa_equals "Status code valid" [dict get $d status] 200
	
	::xo::Package initialize -url $instance/
	set folder_id [::$package_id lookup -name $folder_name]
	aa_log "set folder_id [::$package_id lookup -name $folder_name] ==> $folder_id"

	return [list folder_id $folder_id package_id $package_id]
    }


    ad_proc ::xowiki::test::create_form_page {
        -instance:required
        -user_id:required
        -parent_id:required
        -form_name:required
        -folder_name:required
        {-update ""}
    } {
    } {
        #
        # Create a page under the parent_id
        #
        aa_log "... create a page in test test folder $parent_id"
        set d [aa_http \
                   -user_id $user_id \
                   $instance/$folder_name/$form_name?m=create-new&parent_id=$parent_id]
        
        aa_equals "Status code valid" [dict get $d status] 302
        set location [::xowiki::test::get_url_from_location $d]
        aa_true "location '$location' is valid" {$location ne ""}

        #
        # call edit on the new page
        #
        set d [aa_http -user_id $user_id $location]
        aa_equals "Status code valid" [dict get $d status] 200

	set formCSSClass [::xowiki::utility formCSSclass $form_name] 
        set response [dict get $d body]

        aa_dom_html root $response {
            aa_xpath::non_empty $root [subst {
                //form\[contains(@class,'$formCSSClass')\]//button
            }]
            set f_id          [::xowiki::test::get_object_name $root]
            set f_page_name   [::xowiki::test::get_form_value $root $f_id _name]
            set f_creator     [::xowiki::test::get_form_value $root $f_id _creator]
            aa_true "page_name '$f_page_name' is empty" {$f_page_name eq ""}
            aa_true "creator '$f_creator' is non-empty" {$f_creator ne ""}
            
            set f_form_action  [::xowiki::test::get_form_action $root $formCSSClass]
            aa_true "form_action '$f_form_action' is non-empty" {$f_form_action ne ""}
            
            set form_content [::xowiki::test::get_form_values $root $formCSSClass]
            set names [dict keys $form_content]
            aa_log "form names: [lsort $names]"
            aa_true "page has at least 9 fields" { [llength $names] >= 9 }
        }
        
        set d [::xowiki::test::form_reply \
                   -user_id $user_id \
                   -url $f_form_action \
                   -update $update \
                   $form_content]
        aa_equals "Status code valid" [dict get $d status] 302

        foreach {key value} $update {
            dict set form_content $key $value
        }
        aa_log "form_content: $form_content"
        set location [::xowiki::test::get_url_from_location $d]
        aa_true "location '$location' is valid" {$location ne ""}
        
        set d [aa_http -user_id $user_id $location]
        aa_equals "Status code valid" [dict get $d status] 200

        ::xo::Package initialize -url $location
        set page_info [::$package_id item_ref \
                           -default_lang en \
                           -parent_id $parent_id \
                           [dict get $form_content _name] \
                          ]
        set item_id [dict get $page_info item_id]
        #aa_log "lookup of $folder_name/page -> $item_id"
        ::xo::db::CrClass get_instance_from_db -item_id $item_id

        set d [aa_http -user_id $user_id \
                   $instance/admin/set-publish-state?state=ready&revision_id=[$item_id revision_id]]
        aa_equals "Status code valid" [dict get $d status] 302
    }

    ad_proc ::xowiki::test::edit_form_page {
        -user_id:required
        -instance:required
        -path:required
        {-update ""}
    } {
    } {
        aa_log "... edit page $path"
        set d [aa_http -user_id $user_id $instance/$path?m=edit]
        
        aa_equals "Status code valid" [dict get $d status] 200
        #set location [::xowiki::test::get_url_from_location $d]
        #aa_true "location '$location' is valid" {$location ne ""}
        set response [dict get $d body]

        aa_dom_html root $response {
            set f_id          [::xowiki::test::get_object_name $root]
            set f_page_name   [::xowiki::test::get_form_value $root $f_id _name]
            set f_creator     [::xowiki::test::get_form_value $root $f_id _creator]
            aa_true "page_name '$f_page_name' non empty" {$f_page_name ne ""}
            aa_true "creator '$f_creator' is non-empty" {$f_creator ne ""}
            set CSSclass      [::xowiki::test::get_form_CSSclass $root]
            aa_log "CSSclass: $CSSclass"

            set f_form_action  [::xowiki::test::get_form_action $root $CSSclass]
            aa_true "form_action '$f_form_action' is non-empty" {$f_form_action ne ""}
            
            set form_content [::xowiki::test::get_form_values $root $CSSclass]
            set names [dict keys $form_content]
            aa_log "form names: [lsort $names]"
            aa_true "page has at least 9 fields" { [llength $names] >= 9 }
        }
        
        set d [::xowiki::test::form_reply \
                   -user_id $user_id \
                   -url $f_form_action \
                   -update $update \
                   $form_content]
        aa_equals "Status code valid" [dict get $d status] 302

        foreach {key value} $update {
            dict set form_content $key $value
        }
        aa_log "form_content: $form_content"

        set d [aa_http -user_id $user_id $instance/$path]
        aa_equals "Status code valid" [dict get $d status] 200

        set response [dict get $d body]
        aa_true "page contains title" {[string match "*[dict get $form_content _title]*" $response]}
    }    

}

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
