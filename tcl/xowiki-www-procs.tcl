::xo::library doc {
    XoWiki - www procs. These procs are the methods called on xowiki pages via 
    the web interface.

    @creation-date 2006-04-10
    @author Gustaf Neumann
    @cvs-id $Id$
}

::xo::library require xowiki-procs

namespace eval ::xowiki {
  #
  # This block contains the externally callable methods. We use as
  # naming convention dashes as separators.
  #

  #
  # externally callable method: clipboard-add
  # 
  Page instproc clipboard-add {} {
    my instvar package_id
    if {![my exists_form_parameter "objects"]} {
      my msg "nothing to copy"
    }
    set ids [list]
    foreach page_name [my form_parameter objects] {
      # the page_name is the name exactly as stored in the content repository
      set item_id [::xo::db::CrClass lookup -name $page_name -parent_id [my item_id]]
      #my msg "want to copy $page_name // $item_id"
      if {$item_id ne 0} {lappend ids $item_id}
    }
    ::xowiki::clipboard add $ids
    ::$package_id returnredirect [my query_parameter "return_url" [::xo::cc url]]
  }

  #
  # externally callable method: clipboard-clear
  # 
  Page instproc clipboard-clear {} {
    my instvar package_id
    ::xowiki::clipboard clear
    ::$package_id returnredirect [my query_parameter "return_url" [::xo::cc url]]
  }

  #
  # externally callable method: clipboard-content
  # 
  Page instproc clipboard-content {} {
    my instvar package_id
    set clipboard [::xowiki::clipboard get]
    if {$clipboard eq ""} {
      util_user_message -message "Clipboard empty"
    } else {
      foreach item_id $clipboard {
	if {[::xo::db::CrClass get_instance_from_db -item_id $item_id] ne ""} {
	  util_user_message -message [$item_id pretty_link]
	} else {
	  util_user_message -message "item $item_id deleted"
	}
      }
    }
    ::$package_id returnredirect [my query_parameter "return_url" [::xo::cc url]]
  }

  #
  # externally callable method: clipboard-copy
  # 
  Page instproc clipboard-copy {} {
    my instvar package_id
    set clipboard [::xowiki::clipboard get]
    set item_ids [::xowiki::exporter include_needed_objects $clipboard]
    set content [::xowiki::exporter marshall_all $item_ids]
    if {[catch {namespace eval ::xo::import $content} error]} {
      my msg "Error: $error\n$::errorInfo"
      return
    }
    set msg [$package_id import -replace 0 -create_user_ids 1 \
		 -parent_id [my item_id] -objects $item_ids]
    util_user_message -html -message $msg
    ::xowiki::clipboard clear
    ::$package_id returnredirect [my query_parameter "return_url" [::xo::cc url]]
  }

  #
  # externally callable method: clipboard-export
  # 
  Page instproc clipboard-export {} {
    my instvar package_id
    set clipboard [::xowiki::clipboard get]
    ::xowiki::exporter export $clipboard
    ::xowiki::clipboard clear
    #::$package_id returnredirect [my query_parameter "return_url" [::xo::cc url]]
  }

  
  #
  # externally callable method: create-new
  # 

  Page instproc create-new {
    {-parent_id 0} 
    {-view_method edit} 
    {-name ""} 
    {-nls_language ""}
  } {
    my instvar package_id
    set original_package_id $package_id

    if {[my exists_query_parameter "package_instance"]} {
      set package_instance [my query_parameter "package_instance"]
      #
      # Initialize the target package and set the variable package_id.
      #
      if {[catch {
        ::xowiki::Package initialize \
            -url $package_instance -user_id [::xo::cc user_id] \
            -actual_query ""
      } errorMsg]} {
        ns_log error "$errorMsg\n$::errorInfo"
        return [$original_package_id error_msg \
                    "Page <b>'[my name]'</b> invalid provided package instance=$package_instance<p>$errorMsg</p>"]
      }
    }

    #
    # collect some default values from query parameters
    #
    set default_variables [list]
    foreach key {name title page_order last_page_id nls_language} {
      if {[my exists_query_parameter $key]} {
        lappend default_variables $key [my query_parameter $key]
      }
    }

    # TODO: the following calls are here temporarily for posting
    # content from manually added forms (e.g. linear forum). The
    # following should be done:
    #  - create an includelet to create the form markup automatically
    #  - validate and transform input as usual
    # We should probably allow as well controlling autonaming and
    # setting of publish_status, and probhibit empty postings.

    set text_to_html [my form_parameter "__text_to_html" ""]
    foreach key {_text _name} {
      if {[my exists_form_parameter $key]} {
        set __value [my form_parameter $key]
        if {[lsearch $text_to_html $key] > -1} {
          set __value [ad_text_to_html $__value]
        }
        lappend default_variables [string range $key 1 end] $__value
        switch $key {
          _name {set name $__value}
        }
      }
    }
    set instance_attributes [list]
    foreach {_att _value} [::xo::cc get_all_form_parameter] {
      if {[string match _* $_att]} continue
      lappend instance_attributes $_att $_value
    }

    #
    # To create form_pages in different places than the form, one can
    # provide provide parent_id and package_id.
    #
    # The following construct is more complex than necessary to
    # provide backward compatibility. Note that the passed-in
    # parent_id has priority over the other measures to obtain it.
    #
    if {$parent_id == 0} {
      if {![my exists parent_id]} {my parent_id [$package_id folder_id]}
      set fp_parent_id [my form_parameter "parent_id" [my query_parameter "parent_id" [my parent_id]]]
    } else {
      set fp_parent_id $parent_id
    }
    # In case the Form is inherited and package_id was not specified, we
    # use the actual package_id.
    set fp_package_id [my form_parameter "package_id" [my query_parameter "package_id" [my package_id]]]

    ::xo::Package require $fp_package_id
    set f [my create_form_page_instance \
               -name $name \
               -nls_language $nls_language \
               -parent_id $fp_parent_id \
               -package_id $fp_package_id \
               -default_variables $default_variables \
               -instance_attributes $instance_attributes \
               -source_item_id [my query_parameter source_item_id ""]]

    if {$name eq ""} {
      $f save_new
    } else {
      set id [$fp_package_id lookup -parent_id $fp_parent_id -name $name]
      if {$id == 0} {
        $f save_new
      } else {
        ::xowiki::FormPage get_instance_from_db -item_id $id
        $f copy_content_vars -from_object $id
        $f item_id $id
        $f save
      }
    }

    foreach var {return_url template_file title detail_link text} {
      if {[my exists_query_parameter $var]} {
        set $var [my query_parameter $var]
      }
    }

    set form_redirect [my form_parameter "__form_redirect" ""]
    if {$form_redirect eq ""} {
      set form_redirect [export_vars -base [$f pretty_link] \
                             [list [list m $view_method] return_url template_file title detail_link text]]
    }
    $package_id returnredirect $form_redirect
    set package_id $original_package_id
  }

  #
  # externally callable method: create-or-use
  # 

  Page instproc create-or-use {
    {-parent_id 0} 
    {-view_method edit} 
    {-name ""} 
    {-nls_language ""}
  } {
    # can be overloaded
    my create-new \
        -parent_id $parent_id -view_method $view_method \
        -name $name -nls_language $nls_language
  }

  #
  # externally callable method: csv-dump
  # 

  Page instproc csv-dump {} {
    if {![my is_form]} {
      error "not called on a form"
    }
    set form_item_id [my item_id]
    set items [::xowiki::FormPage get_form_entries \
                   -base_item_ids $form_item_id -form_fields "" -initialize false \
                   -publish_status all -package_id [my package_id]]
    # collect all instances attributes of all items
    foreach i [$items children] {array set vars [$i set instance_attributes]}
    array set vars [list _name 1 _last_modified 1 _creation_user 1]
    set attributes [lsort -dictionary [array names vars]]
    # make sure, we the includelet honors the cvs generation
    set includelet_key name:form-usages,form_item_ids:$form_item_id,field_names:[join $attributes " "],
    ::xo::cc set queryparm(includelet_key) $includelet_key
    # call the includelet
    my view [my include [list form-usages -field_names $attributes \
			     -extra_form_constraints _creation_user:numeric,format=%d \
			     -form_item_id [my item_id] -generate csv]]
  }

  #
  # externally callable method: delete
  # 

  Page instproc delete {} {
    my instvar package_id item_id name
    # delete always via package
    $package_id delete -item_id $item_id -name $name
  }

  PageTemplate instproc delete {} {
    my instvar package_id item_id name
    set count [my count_usages -publish_status all]
    #my msg count=$count
    if {$count > 0} {
      append error_msg \
          [_ xowiki.error-delete_entries_first [list count $count]] \
          <p> \
          [my include [list form-usages -publish_status all -parent_id * -form_item_id [my item_id]]] \
          </p>
      $package_id error_msg $error_msg
    } else {
      next
    }
  }
  
  #
  # externally callable method: delete-revision
  # 

  Page instproc delete-revision {} {
    my instvar revision_id package_id item_id 
    db_1row [my qn get_revision] "select latest_revision,live_revision from cr_items where item_id = $item_id"
    # do real deletion via package
    $package_id delete_revision -revision_id $revision_id -item_id $item_id
    # Take care about UI specific stuff....
    set redirect [my query_parameter "return_url" \
                      [export_vars -base [$package_id url] {{m revisions}}]]
    if {$live_revision == $revision_id} {
      # latest revision might have changed by delete_revision, so we have to fetch here
      db_1row [my qn get_revision] "select latest_revision from cr_items where item_id = $item_id"
      if {$latest_revision eq ""} {
        # we are out of luck, this was the final revision, delete the item
        my instvar package_id name
        $package_id delete -name $name -item_id $item_id
      } else {
        ::xo::db::sql::content_item set_live_revision -revision_id $latest_revision
      }
    }
    if {$latest_revision ne ""} {
      # otherwise, "delete" did already the redirect
      ::$package_id returnredirect [my query_parameter "return_url" \
                                      [export_vars -base [$package_id url] {{m revisions}}]]
    }
  }

  #
  # externally callable method: diff
  # 

  Page instproc diff {} {
    my instvar package_id

    set compare_id [my query_parameter "compare_revision_id" 0]
    if {$compare_id == 0} {
      return ""
    }
    ::xo::Page requireCSS /resources/xowiki/xowiki.css
    set my_page [::xowiki::Package instantiate_page_from_id -revision_id [my revision_id]]
    $my_page volatile

    if {[catch {set html1 [$my_page render]} errorMsg]} {
      set html2 "Error rendering [my revision_id]: $errorMsg"
    }
    set text1 [ad_html_text_convert -from text/html -to text/plain -- $html1]
    set user1 [::xo::get_user_name [$my_page set creation_user]]
    set time1 [$my_page set creation_date]
    set revision_id1 [$my_page set revision_id]
    regexp {^([^.]+)[.]} $time1 _ time1

    set other_page [::xowiki::Package instantiate_page_from_id -revision_id $compare_id]
    $other_page volatile
    #$other_page absolute_links 1

    if {[catch {set html2 [$other_page render]} errorMsg]} {
      set html2 "Error rendering $compare_id: $errorMsg"
    }
    set text2 [ad_html_text_convert -from text/html -to text/plain -- $html2]
    set user2 [::xo::get_user_name [$other_page set creation_user]]
    set time2 [$other_page set creation_date]
    set revision_id2 [$other_page set revision_id]
    regexp {^([^.]+)[.]} $time2 _ time2

    set title "Differences for [my set name]"
    set context [list $title]
    
    # try util::html diff if it is available and works
    if {[catch {set content [::util::html_diff -old $html2 -new $html1 -show_old_p t]}]} {
      # otherwise, fall back to proven text based diff
      set content [::xowiki::html_diff $text2 $text1]
    }

    ::xo::Page set_property doc title $title
    array set property_doc [::xo::Page get_property doc]
    set header_stuff [::xo::Page header_stuff]

    $package_id return_page -adp /packages/xowiki/www/diff -variables {
      content title context header_stuff
      time1 time2 user1 user2 revision_id1 revision_id2 property_doc
    }
  }

  proc html_diff {doc1 doc2} {
    set out ""
    set i 0
    set j 0
    
    #set lines1 [split $doc1 "\n"]
    #set lines2 [split $doc2 "\n"]
    
    regsub -all \n $doc1 " <br />" doc1
    regsub -all \n $doc2 " <br />" doc2
    set lines1 [split $doc1 " "]
    set lines2 [split $doc2 " "]
    
    foreach { x1 x2 } [list::longestCommonSubsequence $lines1 $lines2] {
      foreach p $x1 q $x2 {
        while { $i < $p } {
          set l [lindex $lines1 $i]
          incr i
          #puts "R\t$i\t\t$l"
          append out "<span class='removed'>$l</span>\n"
        }
        while { $j < $q } {
          set m [lindex $lines2 $j]
          incr j
          #puts "A\t\t$j\t$m"
          append out "<span class='added'>$m</span>\n"
        }
        set l [lindex $lines1 $i]
        incr i; incr j
        #puts "B\t$i\t$j\t$l"
      append out "$l\n"
      }
    }
    while { $i < [llength $lines1] } {
      set l [lindex $lines1 $i]
      incr i
      #puts "$i\t\t$l"
      append out "<span class='removed'>$l</span>\n"
    }
    while { $j < [llength $lines2] } {
      set m [lindex $lines2 $j]
      incr j
      #puts "\t$j\t$m"
      append out "<span class='added'>$m</span>\n"
    }
    return $out
  }

  #
  # externally callable method: download
  #
  File instproc download {} {
    my instvar mime_type package_id
    $package_id set mime_type $mime_type
    set use_bg_delivery [expr {![catch {ns_conn contentsentlength}] && 
                               [info command ::bgdelivery] ne ""}]
    $package_id set delivery \
        [expr {$use_bg_delivery ? "ad_returnfile_background" : "ns_returnfile"}]
    if {[my exists_query_parameter filename]} {
      set filename [my query_parameter filename]
      ns_set put [ns_conn outputheaders] Content-Disposition "attachment;filename=$filename"
    }
    #my log "--F FILE=[my full_file_name] // $mime_type"
    set geometry [::xo::cc query_parameter geometry ""]
    if {[string match image/* $mime_type] && $geometry ne ""} {
      if {![file isdirectory /tmp/$geometry]} {
	file mkdir /tmp/$geometry
      }
      set scaled_image /tmp/$geometry/[my revision_id]
      if {![file readable $scaled_image]} {
	set cmd [::util::which convert]
	if {$cmd ne ""} {
	  if {![catch {exec $cmd -geometry $geometry -interlace None -sharpen 1x2 \
			   [my full_file_name] $scaled_image}]} {
	    return $scaled_image
	  }
	}
      } else {
	  return $scaled_image
      }
    }
    return [my full_file_name]
  }

  #
  # We handle delegation to target for most methods in
  # Package->invoke.  Otherwise, we would have to implement several
  # forwarder methods like the following:
  #

#   FormPage instproc download {} {
#     # If there is a link to a file, it can be downloaded as well
#     set target [my get_target_from_link_page]
#     if {$target ne "" && [$target istype ::xowiki::File]} {
#       $target download
#     } else {
#       [my package_id] error_msg "Method 'download' not implemented for this kind of object"
#     }
#   }

  #
  # helper methods for externally callable method: edit
  # 

  Page instproc edit_set_default_values {} {
    my instvar package_id
    # set some default values if they are provided
    foreach key {name title page_order last_page_id nls_language} {
      if {[$package_id exists_query_parameter $key]} {
        #my log "setting [self] set $key [$package_id query_parameter $key]"
        my set $key [$package_id query_parameter $key]
      }
    }    
  }

  Page instproc edit_set_file_selector_folder {} {
    #
    # setting up folder id for file selector (use community folder if available)
    #
    if {[info commands ::dotlrn_fs::get_community_shared_folder] ne ""} {
      # ... we have dotlrn installed
      set cid [::dotlrn_community::get_community_id]
      if {$cid ne ""} {
        # ... we are inside of a community, use the community folder
        return [::dotlrn_fs::get_community_shared_folder -community_id $cid]
      }
    }
    return ""
  }

  #
  # externally callable method: edit
  # 

  Page instproc edit {
    {-new:boolean false} 
    {-autoname:boolean false}
    {-validation_errors ""}
  } {
    my instvar package_id item_id revision_id parent_id
    #my msg "--edit new=$new autoname=$autoname, valudation_errors=$validation_errors, parent=[my parent_id]"
    my edit_set_default_values
    set fs_folder_id [my edit_set_file_selector_folder]

    if {[$package_id exists_query_parameter "return_url"]} {
      set submit_link [my query_parameter "return_url" "."]
      set return_url $submit_link
    } else {
      # before we used "." as default submit link (resulting in a "ad_returnredirect ."). 
      # However, this does not seem to work in case we have folders in use....
      #set submit_link "."
      set submit_link [my pretty_link]
    }
    #my log "--u submit_link=$submit_link qp=[my query_parameter return_url]"
    set object_type [my info class]

    # We have to do template mangling here; ad_form_template writes
    # form variables into the actual parselevel, so we have to be in
    # our own level in order to access an pass these.
    variable ::template::parse_level
    lappend parse_level [info level]    
    set action_vars [expr {$new ? "{edit-new 1} object_type return_url" : "{m edit} return_url"}]
    #my log "--formclass=[$object_type getFormClass -data [self]] ot=$object_type"

    #
    # Determine the package_id of some mounted xowiki instance to find
    # the directory + URL, from where the scripts called from xinha
    # can be used.
    if {[$package_id info class] eq "::xowiki::Package"} {
      # The actual instance is a plain xowiki instance, we can use it
      set folder_spec [list script_dir [$package_id package_url]]
    } else {
      # The actual instance is not a plain xowiki instance, so, we try
      # to find one, where the current user has at least read
      # permissions.  This act is required for sub-packages, which
      # might not have the script dir.
      set first_instance_id [::xowiki::Package first_instance -party_id [::xo::cc user_id] -privilege read]
      if {$first_instance_id ne ""} {
        ::xowiki::Package require $first_instance_id
        set folder_spec [list script_dir [$first_instance_id package_url]]
      }
    }

    if {$fs_folder_id ne ""} {lappend folder_spec folder_id $fs_folder_id}
    
    [$object_type getFormClass -data [self]] create ::xowiki::f1 -volatile \
        -action  [export_vars -base [$package_id url] $action_vars] \
        -data [self] \
        -folderspec $folder_spec \
        -submit_link $submit_link \
        -autoname $autoname

    if {[info exists return_url]} {
      ::xowiki::f1 generate -export [list [list return_url $return_url]]
    } else {
      ::xowiki::f1 generate
    }

    ::xowiki::f1 instvar edit_form_page_title context formTemplate
    
    if {[info exists item_id]} {
      set rev_link    [$package_id make_link [self] revisions]
      set view_link   [$package_id make_link [self] view]
    }
    if {[info exists last_page_id]} {
      set back_link [$package_id url]
    }

    set index_link  [$package_id make_link -privilege public -link "" $package_id {} {}]
    ::xo::Page set_property doc title "[$package_id instance_name] - $edit_form_page_title"

    array set property_doc [::xo::Page get_property doc]
    set tmpl [acs_root_dir]/packages/[[my package_id] package_key]/www/edit
    set edit_tmpl [expr {[file readable $tmpl] ? $tmpl : "/packages/xowiki/www/edit" }]
    set html [$package_id return_page -adp $edit_tmpl \
                  -form f1 \
                  -variables {item_id parent_id edit_form_page_title context formTemplate
                    view_link back_link rev_link index_link property_doc}]
    template::util::lpop parse_level
    #my log "--edit html length [string length $html]"
    return $html
  }
  
  FormPage instproc edit {
    {-validation_errors ""}
    {-disable_input_fields 0}
    {-view true}
  } {
    my instvar page_template doc root package_id
    ::xowiki::Form requireFormCSS
    #my log "edit [self args]"

    set form [my get_form]
    set anon_instances [my get_from_template anon_instances f]
    #my msg form=$form
    #my msg anon_instances=$anon_instances
    
    set field_names [my field_names -form $form]
    #my log field_names=$field_names
    set form_fields [my create_form_fields $field_names]

    if {$form eq ""} {
      #
      # Since we have no form, we create it on the fly
      # from the template variables and the form field specifications.
      #
      set form "<form></form>"
      set formgiven 0
    } else {
      set formgiven 1
    }

    # check name field: 
    #  - if it is for anon instances, hide it,
    #  - if it is required but hidden, show it anyway 
    #    (might happen, when e.g. set via @cr_fields ... hidden)
    set name_field [my lookup_form_field -name _name $form_fields]
    if {$anon_instances} {
      #$name_field config_from_spec hidden
    } else {
      if {[$name_field istype ::xowiki::formfield::hidden] && [$name_field required] == true} {
        $name_field config_from_spec text,required
        $name_field type text
      }
    }

    # include _text only, if explicitly needed (in form needed(_text)]"

    if {![my exists __field_needed(_text)]} {
      #my msg "setting text hidden"
      set f [my lookup_form_field -name _text $form_fields]
      $f config_from_spec hidden
    }

    if {[my exists_form_parameter __disabled_fields]} {
      # Disable some form-fields since these are disabled in the form
      # as well.
      foreach name [my form_parameter __disabled_fields] {
        set f [my lookup_form_field -name $name $form_fields]
        $f disabled disabled
      }
    }

    #my show_fields $form_fields
    #my msg "__form_action [my form_parameter __form_action {}]"
    if {[my form_parameter __form_action ""] eq "save-form-data"} {
      #my msg "we have to validate"
      #
      # we have to valiate and save the form data
      #
      foreach {validation_errors category_ids} [my get_form_data $form_fields] break

      if {$validation_errors != 0} {
        #my msg "$validation_errors errors in $form_fields"
        #foreach f $form_fields { my log "$f: [$f name] '[$f set value]' err: [$f error_msg] " }
        #
        # In case we are triggered internally, we might not have a 
        # a connection, so we don't present the form with the 
        # error messages again, but we return simply the validation
        # problems.
        #
        if {[$package_id exists __batch_mode]} {
          set errors [list]
          foreach f $form_fields { 
            if {[$f error_msg] ne ""} {
              lappend errors [list field [$f name] value [$f set value] error [$f error_msg]]
            }
          }
	  set evaluation_errors ""
	  if {[$package_id exists __evaluation_error]} {
	    set evaluation_errors "\nEvaluation error: [$package_id set __evaluation_error]"
	    $package_id unset __evaluation_error
	  }
          error "[llength $errors] validation error(s): $errors $evaluation_errors"
        }
        # reset the name in error cases to the original one
        my set name [my form_parameter __object_name]
      } else {
        #
        # we have no validation errors, so we can save the content
        #
        my save_data \
            -use_given_publish_date [expr {[lsearch $field_names _publish_date] > -1}] \
            [::xo::cc form_parameter __object_name ""] $category_ids
	#
        # The data might have references. Perform the rendering here to compute
	# the references instead on every view (which would be safer, but slower). This is
        # roughly the counterpart to edit_data and save_data in ad_forms.
	#
        set content [my render -update_references true]
        #my msg "after save refs=[expr {[my exists references]?[my set references] : {NONE}}]"

	set redirect_method [my form_parameter __form_redirect_method "view"]
	if {$redirect_method eq "__none"} {
	  return
	} else {
          if {$redirect_method ne "view"} {set qp "?m=$redirect_method"} {set qp ""}
	  set url [my pretty_link]$qp
	  set return_url [$package_id get_parameter return_url $url]
	  # We had query_parameter here. however, to be able to
	  # process the output of ::xo::cc set_parameter ...., we
	  # changed it to "parameter".
	  #my msg "[my name]: url=$url, return_url=$return_url"
	  $package_id returnredirect $return_url
          return
	}
      }
    } elseif {[my form_parameter __form_action ""] eq "view-form-data" && ![my exists __feedback_mode]} {
      # We have nothing to save (maybe everything is read.only). Check
      # __feedback_mode to prevent recursive loops.
      set redirect_method [my form_parameter __form_redirect_method "view"]
      #my log "__redirect_method=$redirect_method"
      return [my view]
    } else {
      # 
      # display the current values
      #
      if {[my is_new_entry [my name]]} {
	my set creator [::xo::get_user_name [::xo::cc user_id]]
	my set nls_language [ad_conn locale]
	#my set name [$package_id query_parameter name ""]
	# TODO: maybe use __object_name to for POST url to make code 
	# more straightworward
        #set n [$package_id query_parameter name \
	#	   [::xo::cc form_parameter __object_name ""]]
        #if {$n ne ""} { 
        #  my name $n 
        #}
      }

      array set __ia [my set instance_attributes]
      my load_values_into_form_fields $form_fields
      foreach f $form_fields {set ff([$f name]) $f }

      # For named entries, just set the entry fields to empty,
      # without changing the instance variables

      #my msg "my is_new_entry [my name] = [my is_new_entry [my name]]"
      if {[my is_new_entry [my name]]} {
        #my msg "anon_instances=$anon_instances"
        if {$anon_instances} {
          set basename [::xowiki::autoname basename [$page_template name]]
          set name [::xowiki::autoname new -name $basename -parent_id [my parent_id]]
          #my msg "generated name=$name, page_template-name=[$page_template name]"
          $ff(_name) value $name
        } else {
          $ff(_name) value [$ff(_name) default]
        }
        if {![$ff(_title) istype ::xowiki::formfield::hidden]} {
	  $ff(_title) value [$ff(_title) default]
	}
        foreach var [list title detail_link text description] {
          if {[my exists_query_parameter $var]} {
            set value [my query_parameter $var]
            switch -- $var {
              detail_link {
                set f [my lookup_form_field -name $var $form_fields]
                $f value [$f convert_to_external $value]
              }
              title - text - description {
                set f [my lookup_form_field -name _$var $form_fields]
              }
            }
            $f value [$f convert_to_external $value]
          }
        }
      }

      $ff(_name) set transmit_field_always 1
      $ff(_nls_language) set transmit_field_always 1
    }

    # some final sanity checks
    my form_fields_sanity_check $form_fields
    my post_process_form_fields $form_fields

    # The following command would be correct, but does not work due to a bug in 
    # tdom.
    # set form [my regsub_eval  \
    #              [template::adp_variable_regexp] $form \
    #              {my form_field_as_html -mode edit "\\\1" "\2" $form_fields}]
    # Due to this bug, we program around and replace the at-character 
    # by \x003 to avoid conflict withe the input and we replace these
    # magic chars finally with the fields resulting from tdom.

    set form [my substitute_markup $form]
    set form [string map [list @ \x003] $form]
    #my msg form=$form

    dom parse -simple -html $form doc
    $doc documentElement root

    ::require_html_procs
    $root firstChild fcn
    #
    # prepend some fields above the HTML contents of the form
    #
    $root insertBeforeFromScript {
      ::html::input -type hidden -name __object_name -value [my name]
      ::html::input -type hidden -name __form_action -value save-form-data

      # insert automatic form fields on top 
      foreach att $field_names {
        #if {$formgiven && ![string match _* $att]} continue
        if {[my exists __field_in_form($att)]} continue
        set f [my lookup_form_field -name $att $form_fields]
	#my msg "insert auto_field $att"
        $f render_item
      }
    } $fcn
    #
    # append some fields after the HTML contents of the form 
    #
    set button_class(wym) ""
    set button_class(xinha) ""
    set has_file 0
    $root appendFromScript {
      # append category fields
      foreach f $form_fields {
        #my msg "[$f name]: is wym? [$f has_instance_variable editor wym]"
        if {[string match "__category_*" [$f name]]} {
          $f render_item
        } elseif {[$f has_instance_variable editor wym]} {
          set button_class(wym) "wymupdate"
	} elseif {[$f has_instance_variable editor xinha]} {
          set button_class(xinha) "xinhaupdate"
	}
        if {[$f has_instance_variable type file]} {
          set has_file 1
        }
      }

      # insert unreported errors 
      foreach f $form_fields {
        if {[$f set error_msg] ne "" && ![$f exists error_reported]} {
          $f render_error_msg
        }
      }
      # add a submit field(s) at bottom
      my render_form_action_buttons -CSSclass [string trim "$button_class(wym) $button_class(xinha)"]
    }

    set form [lindex [$root selectNodes //form] 0]
    if {$form eq ""} {
      my msg "no form found in page [$page_template name]"
    } else {
      if {[my exists_query_parameter "return_url"]} {
	set return_url [my query_parameter "return_url"]
      }
      set url [export_vars -base [my pretty_link] {{m "edit"} return_url}] 
      $form setAttribute action $url method POST
      if {$has_file} {$form setAttribute enctype multipart/form-data}
      Form add_dom_attribute_value $form class [$page_template css_class_name]
    }

    my set_form_data $form_fields
    if {$disable_input_fields} {
      # (a) disable explicit input fields
      foreach f $form_fields {$f disabled disabled}
      # (b) disable input in HTML-specified fields
      set disabled [Form dom_disable_input_fields $root]
      #
      # Collect these variables in a hiddden field to be able to
      # distinguish later between e.g. un unchecked checkmark and an
      # disabled field. Maybe, we have to add the fields from case (a)
      # as well.
      #
      $root appendFromScript {
        ::html::input -type hidden -name "__disabled_fields" -value $disabled
      }
    }
    my post_process_dom_tree $doc $root $form_fields
    set html [$root asHTML]
    set html [my regsub_eval  \
                  {(^|[^\\])\x003([a-zA-Z0-9_:]+)\x003} $html \
                  {my form_field_as_html -mode edit "\\\1" "\2" $form_fields}]
    # replace unbalanced @ characters
    set html [string map [list \x003 @] $html]

    #my log "calling VIEW with HTML [string length $html]"
    if {$view} {
      my view $html
    } else {
      return $html
    }
  }

  #
  # externally callable method: list
  # 
  Page instproc list {} {
    if {[my is_form]} {
      # The following line is here to provide a short description for
      # larger form-usages (a few MB) where otherwise
      # "ad_html_text_convert" in Page.get_description tend to use forever
      # (at least in Tcl 8.5)
      my set description "form-usages for [my name] [my title]"
      
      return [my view [my include [list form-usages -form_item_id [my item_id]]]]
    }
    if {[my is_folder_page]} {
      return [my view [my include [list child-resources]]]
    }
    #my msg "method list undefined for this kind of object"
    [my package_id] returnredirect [::xo::cc url]
  }

  #
  # externally callable method: make-live-revision
  # 

  Page instproc make-live-revision {} {
    my instvar revision_id item_id package_id
    #my log "--M set_live_revision($revision_id)"
    ::xo::db::sql::content_item set_live_revision -revision_id $revision_id
    set page_id [my query_parameter "page_id"]
    ::xo::clusterwide ns_cache flush xotcl_object_cache ::$item_id
    ::$package_id returnredirect [my query_parameter "return_url" \
              [export_vars -base [$package_id url] {{m revisions}}]]
  }

  #
  # externally callable method: popular-tags
  # 

  Page instproc popular-tags {} {
    my instvar package_id item_id parent_id
    set limit       [my query_parameter "limit" 20]
    set weblog_page [$package_id get_parameter weblog_page weblog]
    set href        [$package_id pretty_link $weblog_page]?summary=1

    set entries [list]
    db_foreach [my qn get_popular_tags] \
        [::xo::db::sql select \
	     -vars "count(*) as nr, tag" \
	     -from "xowiki_tags" \
	     -where "item_id=$item_id" \
	     -groupby "tag" \
	     -orderby "nr" \
	     -limit $limit] {
           lappend entries "<a href='$href&ptag=[ad_urlencode $tag]'>$tag ($nr)</a>"
         }
    ns_return 200 text/html "[_ xowiki.popular_tags_label]: [join $entries {, }]"
  }

  #
  # externally callable method: save-attributes
  # 

  Page ad_instproc save-attributes {} {
    The method save-attributes is typically callable over the 
    REST interface. It allows to  save attributes of a 
    page without adding a new revision.
  } {
    my instvar package_id
    set field_names [my field_names]
    set form_fields [list]
    set query_field_names [list]

    set validation_errors 0
    foreach field_name $field_names {
      if {[::xo::cc exists_form_parameter $field_name]} {
        lappend form_fields [my create_form_field $field_name]
        lappend query_field_names $field_name
      }
    }
    #my show_fields $form_fields
    foreach {validation_errors category_ids} \
        [my get_form_data -field_names $query_field_names $form_fields] break
    if {$validation_errors == 0} {
      #
      # we have no validation errors, so we can save the content
      #
      set update_without_revision [$package_id query_parameter replace 0]

      foreach form_field $form_fields {
        # fix richtext content in accordance with oacs conventions
        if {[$form_field istype ::xowiki::formfield::richtext]} {
          $form_field value [list [$form_field value] text/html]
        }
      }
      if {$update_without_revision} {
        # field-wise update without revision
        set update_instance_attributes 0
        foreach form_field $form_fields {
          set s [$form_field slot]
          if {$s eq ""} {
            # empty slot means that we have an instance_attribute; 
            # we save all in one statement below
            set update_instance_attributes 1
          } else {
            error "Not implemented yet"
            my update_attribute_from_slot $s [$form_field value]
          }
        }
        if {$update_instance_attributes} {
          set s [my find_slot instance_attributes]
          my update_attribute_from_slot $s [my instance_attributes]
        }
      } else {
        #
        # perform standard update (with revision)
        # 
        my save_data \
            -use_given_publish_date [expr {[lsearch $field_names _publish_date] > -1}] \
            [::xo::cc form_parameter __object_name ""] $category_ids
      }
      $package_id returnredirect \
          [my query_parameter "return_url" [my pretty_link]]
      return
    } else {
      # todo: handle errors in a user friendly way
      my log "we have $validation_errors validation_errors"
    }
    $package_id returnredirect \
        [my query_parameter "return_url" [my pretty_link]]
  }

  #
  # externally callable method: revisions
  # 

  Page instproc revisions {} {
    my instvar package_id name item_id
    set context [list [list [$package_id url] $name ] [_ xotcl-core.revisions]]
    set title "[_ xotcl-core.revision_title] '$name'"
    ::xo::Page set_property doc title $title
    set content [next]
    array set property_doc [::xo::Page get_property doc]
    $package_id return_page -adp /packages/xowiki/www/revisions -variables {
      content context {page_id $item_id} title property_doc
    }
  }

  #
  # externally callable method: save-tags
  # 

  Page instproc save-tags {} {
    my instvar package_id item_id revision_id
    ::xowiki::Page save_tags \
	-user_id [::xo::cc user_id] \
	-item_id $item_id \
	-revision_id $revision_id \
        -package_id $package_id \
	[my form_parameter new_tags]

    ::$package_id returnredirect \
        [my query_parameter "return_url" [$package_id url]]
  }

  #
  # externally callable method: validate-attribute
  # 

  Page instproc validate-attribute {} {
    set field_names [my field_names]
    set validation_errors 0

    # get the first transmitted form field
    foreach field_name $field_names {
      if {[::xo::cc exists_form_parameter $field_name]} {
        set form_fields [my create_form_field $field_name]
        set query_field_names $field_name
        break
      }
    }
    foreach {validation_errors category_ids} \
        [my get_form_data -field_names $query_field_names $form_fields] break
    set error ""
    if {$validation_errors == 0} {
      set status_code 200
    } else {
      set status_code 406
      foreach f $form_fields { 
        if {[$f error_msg] ne ""} {set error [::xo::localize [$f error_msg] 1]}
      }
    }
    ns_return $status_code text/html $error
  }

  #
  # externally callable method: view
  # 

  Page instproc view {{content ""}} {
    # The method "view" is used primarily for the toplevel call, when
    # the xowiki page is viewed.  It is not intended for e.g. embedded
    # wiki pages (see include), since it contains full framing, etc.
    my instvar item_id 
    ::xowiki::Page set recursion_count 0
    set page_package_id    [my package_id]
    set context_package_id [::xo::cc package_id]

    #my msg "page_package_id=$page_package_id, context_package_id=$context_package_id"

    set template_file [my query_parameter "template_file" \
                           [::$context_package_id get_parameter template_file view-default]]

    if {[my isobject ::xowiki::$template_file]} {
      $template_file before_render [self]
    }

    #
    # set up template variables
    #
    set object_type [$page_package_id get_parameter object_type [my info class]]
    set rev_link    [$page_package_id make_link -with_entities 0 [self] revisions]
    
    if {[$context_package_id query_parameter m ""] eq "edit"} {
      set view_link [$page_package_id make_link -with_entities 0 [self] view return_url]
      set edit_link ""
    } else {
      set edit_link [$page_package_id make_link -with_entities 0 [self] edit return_url]
      set view_link ""
    }
    set delete_link [$page_package_id make_link -with_entities 0 [self] delete return_url]
    if {[my exists __link(new)]} {
      set new_link [my set __link(new)]
    } else {
      set new_link [my new_link $page_package_id]
    }
    
    set admin_link  [$context_package_id make_link -privilege admin -link admin/ $context_package_id {} {}] 
    set index_link  [$context_package_id make_link -privilege public -link "" $context_package_id {} {}]
    set import_link  [$context_package_id make_link -privilege admin -link "" $context_package_id {} {}]

    set notification_subscribe_link ""
    if {[$context_package_id get_parameter "with_notifications" 1]} {
      if {[::xo::cc user_id] != 0} { ;# notifications require login
        set notifications_return_url [expr {[info exists return_url] ? $return_url : [ad_return_url]}]
        set notification_type [notification::type::get_type_id -short_name xowiki_notif]
        set notification_text "Subscribe the XoWiki instance"
        set notification_subscribe_link \
            [export_vars -base /notifications/request-new \
                 {{return_url $notifications_return_url}
                   {pretty_name $notification_text} 
                   {type_id $notification_type} 
                   {object_id $context_package_id}}]
        set notification_image \
           "<img style='border: 0px;' src='/resources/xowiki/email.png' \
	    alt='$notification_text' title='$notification_text'>"
      }
    }

    # the menubar is work in progress
    set mb [$context_package_id get_parameter "MenuBar" 0]
    if {$mb ne "0" && [info command ::xowiki::MenuBar] ne ""} {

      set clipboard_size [::xowiki::clipboard size]
      set clipboard_label [expr {$clipboard_size ? "Clipboard ($clipboard_size)" : "Clipboard"}]
      #
      # Define standard xowiki menubar
      #
      
      set mb [::xowiki::MenuBar create ::__xowiki__MenuBar -id menubar]
      $mb add_menu -name Package -label [$context_package_id instance_name]
      $mb add_menu -name New
      $mb add_menu -name Clipboard -label $clipboard_label
      $mb add_menu -name Page
      $mb add_menu_item -name Package.Startpage \
          -item [list text #xowiki.index# url $index_link]
      $mb add_menu_item -name Package.Subscribe \
          -item [list text #xowiki.subscribe# url $notification_subscribe_link]
      $mb add_menu_item -name Package.Notifications \
          -item [list text #xowiki.notifications# url /notifications/manage]
      $mb add_menu_item -name Package.Admin \
          -item [list text #xowiki.admin# url $admin_link]
      $mb add_menu_item -name Package.ImportDump \
          -item [list url $import_link]
      $mb add_menu_item -name New.Page \
          -item [list text #xowiki.new# url $new_link]
      $mb add_menu_item -name Page.Edit \
          -item [list text #xowiki.edit# url $edit_link]
      $mb add_menu_item -name Page.Revisions \
          -item [list text #xowiki.revisions# url $rev_link]
      $mb add_menu_item -name Page.Delete \
          -item [list text #xowiki.delete# url $delete_link]

    }
    
    # the content may be passed by other methods (e.g. edit) to 
    # make use of the same templating machinery below.
    if {$content eq ""} {
      set content [my render]
      #my msg "--after render"
    }

    #
    # these variables can be influenced via set-parameter
    #
    set autoname [$page_package_id get_parameter autoname 0]

    #
    # setup top includeletes and footers
    #

    set footer [my htmlFooter -content $content]
    set top_includelets ""
    set vp [string trim [$context_package_id get_parameter "top_includelet" ""]]
    if {$vp ne "" && $vp ne "none"} {
      set top_includelets [my include $vp]
    }
    
    if {$mb ne "0"} {
      #
      # The following block should not be here, but in the templates
      #
      set left_side "<div class='folders' style=''>\n
	[my include {folders -style folders}]\n
        </div>"
       
      #
      # At this place, the menu should be complete, we can render it
      #

      #set content [$mb render-yui]$content
      append top_includelets \n "<div class='visual-clear'><!-- --></div>" [$mb render-yui]

      set content "$left_side\n<div class='content-with-folders'>$content</div>"
    }

    if {[$context_package_id get_parameter "with_user_tracking" 1]} {
      my record_last_visited
    }

    # Deal with the views package (many thanks to Malte for this snippet!)
    if {[$context_package_id get_parameter with_views_package_if_available 1] 
	&& [apm_package_installed_p "views"]} {
      views::record_view -object_id $item_id -viewer_id [::xo::cc user_id]
      array set views_data [views::get -object_id $item_id]
    }

    # import title, name and text into current scope
    my instvar title name text

    if {[my exists_query_parameter return_url]} {
      set return_url [my query_parameter return_url]
    }
    
    #my log "--after notifications [info exists notification_image]"

    set master [$context_package_id get_parameter "master" 1]
    #if {[my exists_query_parameter "edit_return_url"]} {
    #  set return_url [my query_parameter "edit_return_url"]
    #}
    #my log "--after options master=$master"

    if {$master} {
      set context [list $title]
      #my msg "$context_package_id title=[$context_package_id instance_name] - $title"
      #my msg "::xo::cc package_id = [::xo::cc package_id]  ::xo::cc url= [::xo::cc url] "
      ::xo::Page set_property doc title "[$context_package_id instance_name] - $title"
      # We could offer a user to translate the current page to his preferred language
      #
      # set create_in_req_locale_link ""
      # if {[$context_package_id get_parameter use_connection_locale 0]} {
      #  $context_package_id get_lang_and_name -path [$context_package_id set object] req_lang req_local_name
      #  set default_lang [$page_package_id default_language]
      #  if {$req_lang ne $default_lang} {
      #	  set l [Link create new -destroy_on_cleanup \
      #		     -page [self] -type language -stripped_name $req_local_name \
      #		     -name ${default_lang}:$req_local_name -lang $default_lang \
      #		     -label $req_local_name -parent_id [my parent_id] -item_id 0 \
      #	             -package_id $context_package_id -init \
      #		     -return_only undefined]
      #	  $l render
      #   }
      # }

      #my log "--after context delete_link=$delete_link "
      #$context_package_id instvar folder_id  ;# this is the root folder
      #set template [$folder_id get_payload template]
      set template [$context_package_id get_parameter "template" ""]
      set page [self]

      foreach css [$context_package_id get_parameter extra_css ""] {::xo::Page requireCSS -order 10 $css}
      # refetch template_file, since it might have been changed via set-parameter
      # the cache flush (next line) is not pretty here and should be supported from xotcl-core
      catch {::xo::cc unset cache([list $context_package_id get_parameter template_file])}
      set template_file [my query_parameter "template_file" \
			     [::$context_package_id get_parameter template_file view-default]]
      # if the template_file does not have a path, assume it in xowiki/www
      if {![regexp {^[./]} $template_file]} {
	set template_file /packages/xowiki/www/$template_file
      }

      #
      # initialize and set the template variables, to be used by
      # a. adp_compile/ adp_eval
      # b. return_page/ adp_include
      #
	
      set header_stuff [::xo::Page header_stuff]
      if {[info command ::template::head::add_meta] ne ""} {
	set meta(language) [my lang]
	set meta(description) [my description]
	set meta(keywords) ""
	if {[my istype ::xowiki::FormPage]} {
	  set meta(keywords) [string trim [my property keywords]]
	}
	if {$meta(keywords) eq ""} {
	  set meta(keywords) [$context_package_id get_parameter keywords ""]
	}
	foreach i [array names meta] {
	  # don't set empty meta tags
	  if {$meta($i) eq ""} continue
	  template::head::add_meta -name $i -content $meta($i)
	}
      }
      
      #
      # pass variables for properties doc and body
      # example: ::xo::Page set_property body class "yui-skin-sam"
      #
      array set property_body [::xo::Page get_property body]
      array set property_doc  [::xo::Page get_property doc]
      
      if {$page_package_id != $context_package_id} {
	set page_context [$page_package_id instance_name]
      }

      if {$template ne ""} {
        set __including_page $page
        set __adp_stub [acs_root_dir]/packages/xowiki/www/view-default
        set template_code [template::adp_compile -string $template]
	#
	# make sure that <master/> and <slave/> tags are processed
	#
	append template_code {
	  if { [info exists __adp_master] } {
	    set __adp_output [template::adp_parse $__adp_master  \
				  [concat [list __adp_slave $__adp_output] \
				       [array get __adp_properties]]]
	  }
	}
        if {[catch {set content [template::adp_eval template_code]} errmsg]} {
          ns_return 200 text/html "Error in Page $name: $errmsg<br />$template"
        } else {
          ns_return 200 text/html $content
        }
      } else {
        # use adp file
        #my log "use adp"
	set package_id $context_package_id
        $context_package_id return_page -adp $template_file -variables {
          name title item_id context header_stuff return_url
          content footer package_id page_package_id page_context
          rev_link edit_link delete_link new_link admin_link index_link view_link
          notification_subscribe_link notification_image 
          top_includelets page views_data property_body property_doc
        }
      }
    } else {
      ns_return 200 [::xo::cc get_parameter content-type text/html] $content
    }
  }
}

##################################################################################

namespace eval ::xowiki {

  #
  # This block implements the interfacing between form-fields and Pages
  #

  FormPage proc get_table_form_fields {
     -base_item 
     -field_names 
     -form_constraints
   } {

    array set __att [list publish_status 1]
    foreach att [::xowiki::FormPage array names db_slot] {set __att($att) 1}
    foreach att [list last_modified creation_user] {
      set __att($att) 1
    }
    
    # set cr_field_spec [::xowiki::PageInstance get_short_spec_from_form_constraints \
    #                            -name @cr_fields \
    #                            -form_constraints $form_constraints]
    # if some fields are hidden in the form, there might still be values (creation_user, etc)
    # maybe filter hidden? ignore for the time being.

    set cr_field_spec ""
    set field_spec [::xowiki::PageInstance get_short_spec_from_form_constraints \
			-name @fields \
			-form_constraints $form_constraints]

    foreach field_name $field_names {
      set short_spec [::xowiki::PageInstance get_short_spec_from_form_constraints \
                          -name $field_name \
                          -form_constraints $form_constraints]

      switch -glob -- $field_name {
        __* {error not_allowed}
        _* {
          set varname [string range $field_name 1 end]
          if {![info exists __att($varname)]} {
            error "unknown attribute $field_name"
          }
          set f [$base_item create_raw_form_field \
                     -name $field_name \
                     -slot [$base_item find_slot $varname] \
                     -spec $cr_field_spec,$short_spec]
          $f set __base_field $varname
        }
        default {
          set f [$base_item create_raw_form_field \
                     -name $field_name \
                     -slot "" \
                     -spec $field_spec,$short_spec]
        }
      }
      lappend form_fields $f
    }
    return $form_fields
  }

  Page proc find_slot {-start_class:required name} {
    foreach cl [concat $start_class [$start_class info heritage]] {
      set slotobj ${cl}::slot::$name
      if {[my isobject $slotobj]} {
        #my msg $slotobj
        return $slotobj
      }
    }
    return ""
  }

  Page instproc find_slot {-start_class name} {
    if {![info exists start_class]} {
      set start_class [my info class]
    }
    return [::xowiki::Page find_slot -start_class $start_class $name]
  }
  
  Page instproc create_raw_form_field {
    -name 
    {-slot ""} 
    {-spec ""} 
    {-configuration ""}
  } {
    set save_slot $slot
    if {$slot eq ""} {
      # We have no slot, so create a minimal slot. This should only happen for instance attributes
      set slot [::xo::Attribute new -pretty_name $name -datatype text -noinit]
      $slot destroy_on_cleanup
    }

    set spec_list [list]
    if {[$slot exists spec]} {lappend spec_list [$slot set spec]}
    if {$spec ne ""}         {lappend spec_list $spec}
    #my msg "[self args] spec_list $spec_list"
    #my msg "$name, spec_list = '[join $spec_list ,]'"

    if {[$slot exists pretty_name]} {
      set label [$slot set pretty_name]
    } else {
      set label $name
      my log "no pretty_name for variable $name in slot $slot"
    }

    if {[$slot exists default]} {
      #my msg "setting ff $name default = [$slot default]"
      set default [$slot default] 
    } else {
      set default ""
    }
    set f [::xowiki::formfield::FormField new -name $name \
               -id        [::xowiki::Includelet html_id F.[my name].$name] \
               -locale    [my nls_language] \
               -label     $label \
               -type      [expr {[$slot exists datatype]  ? [$slot set datatype]  : "text"}] \
               -help_text [expr {[$slot exists help_text] ? [$slot set help_text] : ""}] \
               -validator [expr {[$slot exists validator] ? [$slot set validator] : ""}] \
               -required  [expr {[$slot exists required]  ? [$slot set required]  : "false"}] \
               -default   $default \
               -spec      [join $spec_list ,] \
               -object    [self] \
               -slot      $save_slot \
              ]

    $f destroy_on_cleanup
    eval $f configure $configuration
    return $f
  }

  PageInstance instproc create_raw_form_field {
    -name 
    {-slot ""}
    {-spec ""} 
    {-configuration ""}
  } {
    set short_spec [my get_short_spec $name]
    #my msg "create form-field '$name', short_spec = '$short_spec', slot=$slot"
    set spec_list [list]
    if {$spec ne ""}       {lappend spec_list $spec}
    if {$short_spec ne ""} {lappend spec_list $short_spec}
    #my msg "$name: short_spec '$short_spec', spec_list 1 = '[join $spec_list ,]'"
    set f [next -name $name -slot $slot -spec [join $spec_list ,] -configuration $configuration]
    #my msg "created form-field '$name' $f [$f info class] validator=[$f validator]" ;#p=[$f info precedence] 
    return $f
  }


 FormPage instproc create_category_fields {} {
    set category_spec [my get_short_spec @categories]
    # Per default, no category fields in FormPages, since the can be 
    # handled in more detail via form-fields.
    if {$category_spec eq ""} {return [list]}

    # a value of "off" turns the off as well
    foreach f [split $category_spec ,] {
      if {$f eq "off"} {return [list]}
    }
    
    set category_fields [list]
    set container_object_id [my package_id]
    set category_trees [category_tree::get_mapped_trees $container_object_id]
    set category_ids [category::get_mapped_categories [my item_id]]
    #my msg "mapped category ids=$category_ids"

    foreach category_tree $category_trees {
      foreach {tree_id tree_name subtree_id assign_single_p require_category_p} $category_tree break

      set options [list] 
      #if {!$require_category_p} {lappend options [list "--" ""]}
      set value [list]
      foreach category [::xowiki::Category get_category_infos \
                            -subtree_id $subtree_id -tree_id $tree_id] {
        foreach {category_id category_name deprecated_p level} $category break
        if {[lsearch $category_ids $category_id] > -1} {lappend value $category_id}
        set category_name [ad_quotehtml [lang::util::localize $category_name]]
        if { $level>1 } {
          set category_name "[string repeat {&nbsp;} [expr {2*$level-4}]]..$category_name"
        }
        lappend options [list $category_name $category_id]
      }
      set f [::xowiki::formfield::FormField new \
                 -name "__category_${tree_name}_$tree_id" \
                 -locale [my nls_language] \
                 -label $tree_name \
                 -type select \
                 -value $value \
                 -required $require_category_p]
      #my msg "category field [my name] created, value '$value'"
      $f destroy_on_cleanup
      $f options $options
      $f multiple [expr {!$assign_single_p}]
      lappend category_fields $f
    }
    return $category_fields
  }

  FormPage instproc get_form_value {att} {
    #
    # Return the value contained in an HTML input field of the FORM
    # provided via the instance variable root.
    #
    my instvar root item_id
    set fields [$root selectNodes "//form//*\[@name='$att'\]"] 
    if {$fields eq ""} {return ""}
    foreach field $fields {
      #
      # Handling first TEXTARA 
      #
      if {[$field nodeName] eq "textarea"} {
	return [$field nodeValue]
      }
      if {[$field nodeName] ne "input"} continue
      #
      # Handling now just INPUT types (only one needed so far)
      #
      set type [expr {[$field hasAttribute type] ? [$field getAttribute type] : "text"}]
      switch $type {
	checkbox {
	  #my msg "get_form_value not implemented for $type"
	}
	radio {
	  #my msg "get_form_value not implemented for $type"
	}
	hidden -
	password -
	text { 
	  if {[$field hasAttribute value]} {
	    return [$field getAttribute value]
	  }
	}
	default {
          #my log "can't handle $type so far $att=$value"
        }
      }
    }
    return ""
  }

  FormPage instproc set_form_value {att value} {
    #my msg "set_form_value '$att' to '$value'"
    #
    # Feed the provided value into an HTML form provided via the
    # instance variable root.
    #
    my instvar root item_id
    set fields [$root selectNodes "//form//*\[@name='$att'\]"]
    #my msg "found field = $fields xp=//*\[@name='$att'\]"

    foreach field $fields {
      #
      # We handle textarea and input fields
      #
      if {[$field nodeName] eq "textarea"} {
	#
	# For TEXTAREA, delete the existing content and insert the new
	# content as text
	#
	foreach node [$field childNodes] {$node delete}
	$field appendFromScript {::html::t $value}
      }
      if {[$field nodeName] ne "input"} continue
      #
      # We handle now only INPUT types, but we have to differntiate
      # between different kinds of inputs.
      #
      set type [expr {[$field hasAttribute type] ? [$field getAttribute type] : "text"}]
      # the switch should be really different objects ad classes...., but thats HTML, anyhow.
      switch $type {
        checkbox {
          #my msg "$att: CHECKBOX value='$value', [$field hasAttribute checked], [$field hasAttribute value]"
          if {[$field hasAttribute value]} {
            set form_value [$field getAttribute value]
            #my msg "$att: form_value=$form_value, my value=$value"
            if {[lsearch -exact $value $form_value] > -1} {
              $field setAttribute checked true
            } elseif {[$field hasAttribute checked]} {
              $field removeAttribute checked
            }
          } else {
            #my msg "$att: CHECKBOX entry has no value"
            if {[catch {set f [expr {$value ? 1 : 0}]}]} {set f 1}
            if {$value eq "" || $f == 0} {
              if {[$field hasAttribute checked]} {
                $field removeAttribute checked
              }
            } else {
              $field setAttribute checked true
            }
          }
        }
        radio {
          set inputvalue [$field getAttribute value]
          #my msg "radio: compare input '$inputvalue' with '$value'"
          if {$inputvalue eq $value} {
            $field setAttribute checked true
          }
        }
        hidden -
        password -
        text {  $field setAttribute value $value}
        default {my log "can't handle $type so far $att=$value"}
      }
    }
  }

  FormPage ad_instproc set_form_data {form_fields} {
    Store the instance attributes or default values in the form.
  } {
    ::require_html_procs
    #my msg "set_form_value instance attributes = [my instance_attributes]"
    array set __ia [my instance_attributes]
    foreach f $form_fields {
      set att [$f name]
      # just handle fields of the form entry 
      if {![my exists __field_in_form($att)]} continue
      #my msg "set form_value to form-field $att __ia($att) [info exists  __ia($att)]"
      if {[info exists __ia($att)]} {
        #my msg "my set_form_value from ia $att '$__ia($att)', external='[$f convert_to_external $__ia($att)]' f.value=[$f value]"
        my set_form_value $att [$f convert_to_external $__ia($att)]
      } else {
        # do we have a value in the form? If yes, keep it.
        set form_value [my get_form_value $att]
        #my msg "no instance attribute, set form_value $att '[$f value]' form_value=$form_value"
        if {$att eq ""} {
          # we have no instance attributes, use the default value from the form field
          my set_form_value $att [$f convert_to_external [$f value]]
        }
      }
    }
  }

  Page ad_instproc get_form_data {-field_names form_fields} {

    Get the values from the form and store it in the form fields and
    finally as instance attributes. If the field names are not
    specified, all form parameters are used.

  } {
    set validation_errors 0
    set category_ids [list]
    array set containers [list]
    my instvar __ia package_id
    set cc [$package_id context]
    if {[my exists instance_attributes]} {
      array unset __ia
      array set __ia [my set instance_attributes]
    }

    if {![info exists field_names]} {
      set field_names [$cc array names form_parameter]
      my log "form-params=[$cc array get form_parameter]"
    }
    #my msg "fields $field_names, "

    # we have a form and get all form variables
    
    foreach att $field_names {
      #my msg "getting att=$att"
      set processed($att) 1
      switch -glob -- $att {
        __category_* {
          set f [my lookup_form_field -name $att $form_fields]
          set value [$f value [$cc form_parameter $att]]
          foreach v $value {lappend category_ids $v}
        }
        __* {
          # other internal variables (like __object_name) are ignored
        }
         _* {
           # instance attribute fields
           set f     [my lookup_form_field -name $att $form_fields]
           set value [$f value [string trim [$cc form_parameter $att]]]
           set varname [string range $att 1 end]
           # get rid of strange utf-8 characters hex C2AD (firefox bug?)
           # ns_log notice "FORM_DATA var=$varname, value='$value' s=$s"
           if {$varname eq "text"} {regsub -all "­" $value "" value}
           # ns_log notice "FORM_DATA var=$varname, value='$value' s=$s"
           if {![string match *.* $att]} {my set $varname $value}
         }
        default {
           # user form content fields
          if {[regexp {^(.+)[.](tmpfile|content-type)} $att _ file field]} {
            set f [my lookup_form_field -name $file $form_fields]
            $f $field [string trim [$cc form_parameter $att]]
          } else {
            set f     [my lookup_form_field -name $att $form_fields]
            set value [$f value [string trim [$cc form_parameter $att]]]
            #my msg "value of $att ($f) = '$value' exists=[$cc exists_form_parameter $att]" 
            if {![string match *.* $att]} {set __ia($att) $value}
            if {[$f exists is_category_field]} {foreach v $value {lappend category_ids $v}}
          }
        }
      }
      if {[string match *.* $att]} {
        foreach {container component} [split $att .] break
        lappend containers($container) $component
      }
    }
    
    #my msg "containers = [array names containers]"
    #my msg "ia=[array get __ia]"
    #
    # In a second iteration, combine the values from the components 
    # of a container to the value of the container.
    #
    foreach c [array names containers] {
      switch -glob -- $c {
        __* {}
        _* {
          set f  [my lookup_form_field -name $c $form_fields]
          set processed($c) 1
          my set [string range $c 1 end] [$f value]
        }
        default {
          set f  [my lookup_form_field -name $c $form_fields]
          set processed($c) 1
          #my msg "compute value of $c"
          set __ia($c) [$f value]
          #my msg "__ia($c) is set to '$__ia($c)'"
        }
      }
    }
    
    #
    # The first round was a processing based on the transmitted input
    # fields of the forms. Now we use the formfields to complete the
    # data and to validate it.
    #
    foreach f $form_fields {
      #my msg "validate $f [$f name] [info exists processed([$f name])]"
      set att [$f name]
 
      # Certain form field types (e.g. checkboxes) are not transmitted, if not
      # checked. Therefore, we have not processed these fields above and
      # have to do it now.
      
      if {![info exists processed($att)]} {
	#my msg "form field $att not yet processed"
	switch -glob -- $att {
	  __* {
	    # other internal variables (like __object_name) are ignored
	  }
	  _* {
	    # instance attribute fields
	    set varname [string range $att 1 end]
            set default ""
            if {[my exists $varname]} {set default [my set $varname]}
            set v [$f value_if_nothing_is_returned_from_form $default]
            set value [$f value $v]
            if {$v ne $default} {
              if {![string match *.* $att]} {my set $varname $value}
            }
	  }
	  default {
	    # user form content fields
            set default ""
            # The reason, why we set in the next line the default to
            # the old value is due to "show-solution" in the qti
            # use-case. Maybe one should alter this use-case to
            # simplify the semantics here.
            if {[info exists __ia($att)]} {set default $__ia($att)}
            set v [$f value_if_nothing_is_returned_from_form $default]
            #my msg "value_if_nothing_is_returned_from_form '$default' => '$v' (type=[$f info class])"
            set value [$f value $v]
            if {![string match *.* $att]} {set __ia($att) $value}
	  }
        }
      }
      
      #
      # Run validators
      #
      set validation_error [$f validate [self]]
      #my msg "validation of [$f name] with value '[$f value]' returns '$validation_error'"
      if {$validation_error ne ""} {
        $f error_msg $validation_error
        incr validation_errors
      }
    }
    my log validation_errors=$validation_errors
    if {$validation_errors == 0} {
      #
      # Postprocess based on form fields based on form-fields methods.
      #
      foreach f $form_fields {
        $f convert_to_internal
      }        
    }

    my instance_attributes [array get __ia]
    #my msg category_ids=$category_ids
    return [list $validation_errors [lsort -unique $category_ids]]
  }

  FormPage instproc form_field_as_html {{-mode edit} before name form_fields} {
    set found 0
    foreach f $form_fields {
      if {[$f name] eq $name} {set found 1; break}
    } 
    if {!$found} {
      set f [my create_raw_form_field -name $name -slot [my find_slot $name]]
    }

    #my msg "$found $name mode=$mode type=[$f set type] value=[$f value] disa=[$f exists disabled]"
    if {$mode eq "edit" || [$f display_field]} {
      set html [$f asHTML]
    } else {
      set html @$name@
    }
    #my msg "$name $html"
    return ${before}$html
  }

  Page instproc create_form_field {{-cr_field_spec ""} {-field_spec ""} field_name} {
    switch -glob -- $field_name {
      __* {}
      _* {
        set varname [string range $field_name 1 end]
        return [my create_raw_form_field -name $field_name \
                    -spec $cr_field_spec \
                    -slot [my find_slot $varname]]
      }
      default {
        return [my create_raw_form_field -name $field_name \
                    -spec $field_spec \
                    -slot [my find_slot $field_name]]
      }
    }
  }

  Page instproc create_form_fields {field_names} {
    set form_fields [my create_category_fields]
    foreach att $field_names {
      if {[string match "__*" $att]} continue
      lappend form_fields [my create_form_field $att]
    }
    return $form_fields
  }

  FormPage instproc create_form_field {{-cr_field_spec ""} {-field_spec ""} field_name} {
    if {$cr_field_spec eq ""} {set cr_field_spec [my get_short_spec @cr_fields]}
    if {$field_spec eq ""} {set field_spec [my get_short_spec @fields]}
    return [next -cr_field_spec $cr_field_spec -field_spec $field_spec $field_name]
  }

  FormPage instproc create_form_fields {field_names} {
    set form_fields   [my create_category_fields]
    foreach att $field_names {
      if {[string match "__*" $att]} continue
      lappend form_fields [my create_form_field \
                               -cr_field_spec [my get_short_spec @cr_fields] \
                               -field_spec [my get_short_spec @fields] $att]
    }
    return $form_fields
  }

  FormPage instproc field_names {{-form ""}} {
    my instvar package_id
    foreach {form_vars needed_attributes} [my field_names_from_form -form $form] break
    #my log "form=$form, form_vars=$form_vars needed_attributes=$needed_attributes"
    my array unset __field_in_form
    my array unset __field_needed
    if {$form_vars} {foreach v $needed_attributes {my set __field_in_form($v) 1}}
    foreach v $needed_attributes {my set __field_needed($v) 1}
    
    # 
    # Remove the fields already included in auto_fields form the needed_attributes.
    # The final list field_names determines the order of the fields in the form.
    #
    set auto_fields [list _name _page_order _creator _title _text _description _nls_language]
    set reduced_attributes $needed_attributes

    foreach f $auto_fields {
      set p [lsearch $reduced_attributes $f]
      if {$p > -1} {
	#if {$form_vars} {
	  #set auto_field_in_form($f) 1
	#}
        set reduced_attributes [lreplace $reduced_attributes $p $p]
      } 
    }
    #my msg reduced_attributes=$reduced_attributes 
    #my msg fields_from_form=[my array names __field_in_form]

    set field_names [list _name]
    if {[$package_id show_page_order]}  { lappend field_names _page_order }
    lappend field_names _title _creator _assignee
    foreach fn $reduced_attributes                     { lappend field_names $fn }
    foreach fn [list _text _description _nls_language] { lappend field_names $fn }
    #my msg field_names=$field_names
    return $field_names
  }

  Page instproc field_names {{-form ""}} {
    array set dont_modify [list item_id 1 revision_id 1 object_id 1 object_title 1 page_id 1 name 1]
    set field_names [list]
    foreach field_name [[my info class] array names db_slot] {
      if {[info exists dont_modify($field_name)]} continue
      lappend field_names _$field_name
    }
    #my msg field_names=$field_names
    return $field_names
  }

  FormPage instproc post_process_form_fields {form_fields} {
    # We offer here the possibility to iterate over the form fields before it
    # before they are rendered
  }

  FormPage instproc post_process_dom_tree {dom_doc dom_root form_fields} {
    # Part of the input fields comes from HTML, part comes via $form_fields
    # We offer here the possibility to iterate over the dom tree before it
    # is presented; can be overloaded
  }

  FormPage instproc load_values_into_form_fields {form_fields} {
    array set __ia [my set instance_attributes]
    foreach f $form_fields {
      set att [$f name]
      switch -glob $att {
        __* {}
        _* {
          set varname [string range $att 1 end]
          $f value [$f convert_to_external [my set $varname]]
        }
        default {
          if {[info exists __ia($att)]} {
            #my msg "setting $f ([$f info class]) value $__ia($att)"
            $f value [$f convert_to_external $__ia($att)]
          }
        }
      }
    }
  }

  FormPage instproc render_form_action_buttons {{-CSSclass ""}} {
    ::html::div -class form-button {
      set f [::xowiki::formfield::submit_button new -destroy_on_cleanup \
                 -name __form_button_ok \
                 -CSSclass $CSSclass]
      $f render_input
    }
  }

  FormPage instproc form_fields_sanity_check {form_fields} {
    foreach f $form_fields {
      if {[$f exists disabled]} {
        # don't mark disabled fields as required
        if {[$f required]} {
          $f required false
        }
        #don't show the help-text, if you cannot input
        if {[$f help_text] ne ""} {
          $f help_text ""
        }
      }
      if {[$f exists transmit_field_always] 
          && [lsearch [$f info mixin] ::xowiki::formfield::omit] > -1} {
        # Never omit these fields, this would cause problems with
        # autonames and empty languages. Set these fields to hidden
        # instead.
        $f remove_omit
        $f class ::xowiki::formfield::hidden
        $f initialize
        #my msg "$f [$f name] [$f info class] [$f info mixin]"
      }
    }
  }

  if {[apm_version_names_compare [ad_acs_version] 5.3.0] == 1} {
    ns_log notice "Zen-state: 5.3.2 or newer"
    Form set extraCSS ""
  } else {
    ns_log notice "Zen-state: pre 5.3.1, use backward compatible form css file"
    Form set extraCSS "zen-forms-backward-compatibility.css"
  }
  Form proc requireFormCSS {} {
    #my msg requireFormCSS
    set css [my set extraCSS]
    if {$css ne ""} {
      ::xo::Page requireCSS $css
    }
  }

}
::xo::library source_dependent 

