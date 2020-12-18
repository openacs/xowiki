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
  # Externally callable method: bulk-delete
  #
  Page ad_instproc www-bulk-delete {} {

    This web-callable method performs a bulk delete based on the
    object names provided by the form-variable "objects" and refresh
    then the caller page.  This method is e.g. called by the
    folder-procs.

  } {
    ::security::csrf::validate

    if {![:exists_form_parameter "objects"]} {
      :msg "nothing to delete"
    }

    set item_ids [:get_ids_for_bulk_actions [:form_parameter objects]]
    foreach item_id $item_ids {
      :log "bulk-delete: DELETE item_id $item_id"
      ${:package_id} www-delete -item_id $item_id
    }

    ${:package_id} returnredirect [:query_parameter "return_url" [:pretty_link]]
  }

  #
  # Externally callable method: clipboard-add
  #
  Page ad_instproc www-clipboard-add {} {

    This web-callable method adds elements to the clipboard based on
    the names provided by the form variable "objects". The objects are
    resolved below the current object, which is treated as containing
    folder.

    After adding elements to the clipboard, redirect either to the
    return_url of the calling page.

  } {
    if {![:exists_form_parameter "objects"] && [ns_conn method] eq "POST"} {
      :msg "nothing to copy"
    }

    ::xowiki::clipboard add [:get_ids_for_bulk_actions [:form_parameter objects]]
    #
    # When called via AJAX, we have reason to make a redirect.
    #
    if {[ns_set iget [ns_conn headers] "X-Requested-With"] eq "XMLHttpRequest"} {
      ns_log notice "HEADERS: got X-Requested-With"
      return OK
    } else {
      ns_log notice "HEADERS: no X-Requested-With"
      ${:package_id} returnredirect [:query_parameter "return_url" [::xo::cc url]]
    }
  }

  #
  # Externally callable method: clipboard-clear
  #
  Page ad_instproc www-clipboard-clear {} {

    This web-callable method clears the clibpboard contents.  Finally
    redirect either to the return_url of the calling page.

  } {
    ::xowiki::clipboard clear
    ${:package_id} returnredirect [:query_parameter "return_url" [::xo::cc url]]
  }

  #
  # Externally callable method: clipboard-content
  #
  Page ad_instproc www-clipboard-content {} {

    This web-callable method displays the content of the clipboard.
    Finally redirect either to the return_url of the calling page.

  } {
    set clipboard [::xowiki::clipboard get]
    if {$clipboard eq ""} {
      util_user_message -message "Clipboard empty"
    } else {
      foreach item_id $clipboard {
        if {[::xo::db::CrClass get_instance_from_db -item_id $item_id] ne ""} {
          util_user_message -message [::$item_id pretty_link]
        } else {
          util_user_message -message "item $item_id deleted"
        }
      }
    }
    ${:package_id} returnredirect [:query_parameter "return_url" [::xo::cc url]]
  }

  #
  # Externally callable method: clipboard-copy
  #
  Page ad_instproc www-clipboard-copy {} {

    This web-callable method copies the content of the clipboard to
    the current folder.

    After copying the elements from the clipboard, redirect either
    to the return_url of the calling page.

  } {
    set clipboard [::xowiki::clipboard get]
    set item_ids [::xowiki::exporter include_needed_objects $clipboard]
    set content [::xowiki::exporter marshall_all -mode copy $item_ids]

    ad_try {
      namespace eval ::xo::import $content
    } on error {errMsg} {
      :msg "Error: $errMsg\n$::errorInfo"
      return
    }
    set folder_id [expr {[:is_folder_page] ? ${:item_id} : ${:parent_id}}]
    set msg [::${:package_id} import -replace 0 -create_user_ids 1 \
                 -parent_id $folder_id -objects $item_ids]
    util_user_message -html -message $msg
    ::xowiki::clipboard clear
    ::${:package_id} returnredirect [:query_parameter "return_url" [::xo::cc url]]
  }

  #
  # Externally callable method: clipboard-export
  #
  Page ad_instproc www-clipboard-export {} {

    This web-callable method exports the content of the clipboard in
    form of an xowiki dump.  Then clear the clipboard and stop the
    script.

  } {
    set clipboard [::xowiki::clipboard get]
    ::xowiki::exporter export $clipboard
    ns_conn close
    ::xowiki::clipboard clear
    ad_script_abort
  }

  #
  # Externally callable method: duplicate
  #
  Page ad_instproc www-duplicate {} {

    This web-callable method duplicated the current object. It uses the
    same mechanisms as the clipboard-copy operation.

    After adding elements to the clipboard, redirect either to the
    return_url of the calling page (as handled by www-clipboard-copy)

  } {
    ::xowiki::clipboard clear
    ::xowiki::clipboard add [list ${:item_id}]

    if {![regexp {^(.*[-]copy-)\d+} ${:name} . stem]} {
      set stem ${:name}-copy-
    }
    set new_name [::xowiki::autoname new -name $stem -parent_id ${:package_id}]
    set old_name ${:name}

    ad_try {
      set :name $new_name
      #
      # Call whatever clipboard-copy is doing....
      #
      :www-clipboard-copy

    } finally {
      #
      # Restore the actual object
      #
      set :name $old_name
      #
      # To be on the save side, flush the cache
      #
      ::xo::xotcl_object_cache flush ${:item_id}
    }
  }

  #
  # Externally callable method: create-new
  #

  Page ad_instproc www-create-new {
    {-parent_id 0}
    {-view_method edit}
    {-name ""}
    {-nls_language ""}
    {-publish_status ""}
  } {

    This web-callable method creates a new page, typically an instance
    of a form page. The method accesses several form variables such as
    "__form_redirect", "__text_to_html", "last_page_id", "name",
    "nls_language", "package_id", "package_instance", "page_order",
    "parent_id", "publish_status", "source_item_id", "title"

    The call redirects either to the "__form_redirect" or to the
    created page.

  } {
    set original_package_id ${:package_id}

    if {[:exists_query_parameter "package_instance"]} {
      set package_instance [:query_parameter "package_instance:localurl"]
      #
      # Initialize the target package and set the variable package_id.
      #
      ad_try {
        ::xowiki::Package initialize \
            -url $package_instance -user_id [::xo::cc user_id] \
            -actual_query ""
      } on error {errorMsg} {
        ns_log error "Package initialize: $errorMsg\n$::errorInfo"
        return [::$original_package_id error_msg \
                    "Page <b>'${:name}'</b> invalid provided package instance=$package_instance<p>$errorMsg</p>"]
      }
    }

    #
    # Collect some default values from query parameters.
    #
    set default_variables [list]
    foreach param {name title page_order:graph last_page_id:integer nls_language:wordchar} {
      regexp {^([^:]+):?} $param . key
      if {[:exists_query_parameter $key]} {
        lappend default_variables $key [:query_parameter $param]
      }
    }

    # TODO: the following calls are here temporarily for posting
    # content from manually added forms (e.g. linear forum). The
    # following should be done:
    #  - create an includelet to create the form markup automatically
    #  - validate and transform input as usual
    # We should probably allow as well controlling auto-naming and
    # and prohibit empty postings.

    set text_to_html [:form_parameter "__text_to_html" ""]
    foreach key {_text _name} {
      if {[:exists_form_parameter $key]} {
        set __value [:form_parameter $key]
        if {$key in $text_to_html} {
          set __value [ad_text_to_html -- $__value]
        }
        lappend default_variables [string range $key 1 end] $__value
        switch -- $key {
          _name {set name $__value}
        }
      }
    }

    # Load the instance attributes from the form parameters
    set instance_attributes [list]
    foreach {_att _value} [::xo::cc get_all_form_parameter] {
      if {[string match _* $_att]} continue
      lappend instance_attributes $_att $_value
    }

    #
    # To create form_pages in different places than the form, one can
    # provide parent_id and package_id.
    #
    # The following construct is more complex than necessary to
    # provide backward compatibility. Note that the passed-in
    # parent_id has priority over the other measures to obtain it.
    #
    if {$parent_id == 0} {
      if {![info exists :parent_id]} {:parent_id [::${:package_id} folder_id]}
      set fp_parent_id [:form_parameter "parent_id" [:query_parameter "parent_id:integer" ${:parent_id}]]
    } else {
      set fp_parent_id $parent_id
    }
    # In case the Form is inherited and package_id was not specified, we
    # use the actual package_id.
    set fp_package_id [:form_parameter "package_id" [:query_parameter "package_id:integer" ${:package_id}]]

    #
    # Handling publish_status. When the publish_status is provided via
    # query parameter, this has the highest priority. Otherwise use
    # the publish_status according to the production_mode. We control
    # this here explicitly, since when "name" is provided via query
    # variable, the default production/ready selection fails, and we
    # have to set the publish_status manually (see issue #3380).
    #
    if {$publish_status eq ""} {
      set publish_status [:query_parameter "publish_status:wordchar" ""]
    }
    if {$publish_status eq "" && [:exists_query_parameter name]} {
      if {[::${:package_id} get_parameter production_mode:boolean 0]} {
        set publish_status "production"
      } else {
        set publish_status "ready"
      }
      :log "FINAL publish_status $publish_status"
    }

    #
    # Provide "p.configure" hook to programmatically configure pages
    #
    if {[:exists_query_parameter p.configure]} {
      set configure_method [:query_parameter p.configure:wordchar]
      if {[$f procsearch configure_page=$configure_method] ne ""} {
        #ns_log notice "call [$f procsearch configure_page=$configure_method] // [$f info class]"
        $f configure_page=$configure_method $name
      } else {
        ns_log notice "cannot find configure_page=$configure_method on [$f info precedence]"
      }
    }

    #
    # Provide "p.source" hook to configure pages by copying variables
    # from other pages (e.g. sitewide pages)
    #
    set source_item_id 0
    if {[:exists_query_parameter p.source]} {
      set source_page [:query_parameter p.source:token]
      set source_item_id [::${:package_id} lookup -use_site_wide_pages true -name $source_page]
    }
    if {$source_item_id == 0} {
      set source_item_id [:query_parameter source_item_id:integer ""]
    }

    ::xo::Package require $fp_package_id
    set f [:create_form_page_instance \
               -name $name \
               -nls_language $nls_language \
               -parent_id $fp_parent_id \
               -package_id $fp_package_id \
               -default_variables $default_variables \
               -instance_attributes $instance_attributes \
               -source_item_id $source_item_id]

    if {$publish_status ne ""
        && $publish_status in {"production" "ready" "live" "expired"}
      } {
      $f publish_status $publish_status
    }

    if {$name eq ""} {
      $f save_new
    } else {
      set id [::$fp_package_id lookup -parent_id $fp_parent_id -name $name]
      if {$id == 0} {
        $f save_new
      } else {
        ::xowiki::FormPage get_instance_from_db -item_id $id
        $f copy_content_vars -from_object $id
        $f item_id $id
        $f save
      }
    }

    $f notification_notify

    foreach var {return_url:localurl template_file title detail_link:localurl text} {
      regexp {^([^:]+):?} $var . key
      if {[:exists_query_parameter $key]} {
        set $key [:query_parameter $var]
        :log "set instance var from query param '$key' -> '[set $key]'"
      }
    }

    if {[info exists template_file]} {
      #
      # strip the leading "/" added by ns_normalizepath.
      #
      # TODO: check use-cases, with the restricted case actually still
      # makes sense.
      #
      set template_file [$fp_package_id normalizepath $template_file]
    }
    set form_redirect [:form_parameter "__form_redirect" ""]
    if {$form_redirect eq ""} {
      set form_redirect [$f pretty_link -query [export_vars {
        {m $view_method} return_url template_file title detail_link text
      }]]
    }
    ${:package_id} returnredirect $form_redirect
    set :package_id $original_package_id
  }

  #
  # Externally callable method: create-or-use
  #

  Page ad_instproc www-create-or-use {
    {-parent_id 0}
    {-view_method edit}
    {-name ""}
    {-nls_language ""}
  } {

    This web-callable method calls www-create-new, unless overloaded
    from some other package, as done e.g. by xowf.

  } {
    # can be overloaded
    :www-create-new \
        -parent_id $parent_id -view_method $view_method \
        -name $name -nls_language $nls_language
  }

  #
  # Externally callable method: csv-dump
  #

  Page ad_instproc www-csv-dump {} {

    This web-callable method produces a CSV dump based on the
    includelet "form-usages".

  } {
    if {![:is_form]} {
      error "not called on a form"
    }
    set form_item_id ${:item_id}
    set items [::xowiki::FormPage get_form_entries \
                   -base_item_ids $form_item_id -form_fields "" -initialize false \
                   -publish_status all -package_id ${:package_id}]
    # collect all instances attributes of all items
    foreach i [$items children] {array set vars [$i set instance_attributes]}
    array set vars [list _name 1 _last_modified 1 _creation_user 1]
    set attributes [lsort -dictionary [array names vars]]
    #
    # Make sure, we the includelet honors the CSV generation
    #
    set includelet_key name:form-usages,form_item_ids:$form_item_id,field_names:[join $attributes " "],
    ::xo::cc set queryparm(includelet_key) [ns_base64urlencode $includelet_key]
    # call the includelet
    :www-view [:include [list form-usages -field_names $attributes \
                             -extra_form_constraints _creation_user:numeric,format=%d \
                             -form_item_id ${:item_id} -generate csv]]
  }

  #
  # Externally callable method: use-template
  #
  PageInstance ad_instproc www-use-template {} {

    This web-callable method can be used to change the "template" of a
    PageInstance.  The caller provides the "form" as query parameter
    which should be used in future for handling the instance
    parameters of the PageInstance.

    This method can be as well be used for changing the associated
    workflow of a workflow instance.

  } {
    set formName [:query_parameter "form" ""]
    if {$formName eq ""} {
      error "no form specified"
    }
    ::${:package_id} get_lang_and_name -default_lang [::xo::cc lang] -path $formName lang stripped_url
    set d [::${:package_id} item_ref -default_lang $lang -parent_id [::${:package_id} folder_id] $formName]
    set item_id [dict get $d item_id]
    if {$item_id == 0} {
      error "cannot lookup page $formName"
    }
    ::xo::db::CrClass get_instance_from_db -item_id $item_id
    if {![nsf::is object ::$item_id]
        || "::xowiki::PageTemplate" ni [::$item_id info precedence]} {
      error "OK $formName is not suited to be used as template. Should be a Form!"
    }
    if {${:page_template} == $item_id} {
      :msg "old page_template $item_id is already the same as the new one"
    } else {
      set msg "change template_id ${:page_template} to $item_id"
      :page_template $item_id
      :save
      #:msg "ok $msg"
    }
    ::${:package_id} returnredirect [::xo::cc url]
  }


  #
  # Externally callable method: delete
  #

  Page ad_instproc www-delete {} {

    This web-callable method deletes a page via the delete
    method of the package.

  } {
    # delete always via package
    ${:package_id} www-delete -item_id ${:item_id} -name ${:name}
  }

  PageTemplate ad_instproc www-delete {} {

    This web-callable method deletes a page via the delete method
    of the package.  This method checks first, if there exists still
    instances of this page (depending on it).

  } {
    set count [:count_usages -publish_status all]
    #:msg count=$count
    if {$count > 0} {
      append error_msg \
          [_ xowiki.error-delete_entries_first [list count $count]] \
          <p> \
          [:include [list form-usages -publish_status all -parent_id * -form_item_id ${:item_id}]] \
          </p>
      ${:package_id} error_msg $error_msg
    } else {
      next
    }
  }

  #
  # Externally callable method: delete-revision
  #

  Page ad_instproc www-delete-revision {} {

    This web-callable method deletes a single revision of a Page,
    which is actually performed by the "delete_revision" method of the
    package, which is responsible for caching.

    Since we instantiate the Page based on the "revision_id" query
    parameter, it is sufficient to delete here just based on the
    current instance variable of the revision_id.

  } {
    set item_id ${:item_id}
    ::xo::dc 1row -prepare integer get_revision {
      select latest_revision,live_revision from cr_items where item_id = :item_id
    }

    # do real deletion via package
    ${:package_id} delete_revision -revision_id ${:revision_id} -item_id $item_id

    if {$live_revision == ${:revision_id}} {
      # latest revision might have changed by delete_revision, so we have to fetch here
      xo::dc 1row -prepare integer get_revision {select latest_revision from cr_items where item_id = :item_id}
      if {$latest_revision eq ""} {
        # we are out of luck, this was the final revision, delete the item
        ${:package_id} delete -name ${:name} -item_id $item_id
      } else {
        # Fetch fresh instance from db so that we have actual values
        # from the latest revision for e.g. the update of the
        # item_index.
        set page [::xo::db::CrClass get_instance_from_db -item_id $item_id -revision_id $latest_revision]
        $page set_live_revision -revision_id $latest_revision
      }
    }
    if {$latest_revision ne ""} {
      # otherwise, "delete" did already the redirect
      ${:package_id} returnredirect [:query_parameter "return_url" \
                                         [export_vars -base [${:package_id} url] {{m revisions}}]]
    }
  }

  #
  # Externally callable method: diff
  #

  Page ad_instproc www-diff {} {

    This web-callable method produces a "diff" of two pages based on
    the current page and the revision_id provided as query parameter
    by "compare_revision_id".  We can choose here between the more
    fancy "::util::html_diff" and a plain text diff.  The latter is
    used, when the query variable "plain_text_diff" is provided, or
    when the fancy diff raises an exception.

  } {

    set compare_id [:query_parameter "compare_revision_id:integer" 0]
    if {$compare_id == 0} {
      return ""
    }
    ::xo::Page requireCSS urn:ad:css:xowiki-[::xowiki::Package preferredCSSToolkit]

    set my_page [::xowiki::Package instantiate_page_from_id -revision_id ${:revision_id}]

    ad_try {
      set html1 [$my_page render]
    } on error {errorMsg} {
      set html1 "Error rendering ${:revision_id}: $errorMsg"
    }
    set user1 [::xo::get_user_name [$my_page set creation_user]]
    set time1 [$my_page set creation_date]
    set revision_id1 [$my_page set revision_id]
    regexp {^([^.]+)[.]} $time1 _ time1

    set other_page [::xowiki::Package instantiate_page_from_id -revision_id $compare_id]
    $other_page volatile
    #$other_page absolute_links 1

    ad_try {
      set html2 [$other_page render]
    } on error {errorMsg} {
      set html2 "Error rendering $compare_id: $errorMsg"
    }
    set user2 [::xo::get_user_name [$other_page set creation_user]]
    set time2 [$other_page set creation_date]
    set revision_id2 [$other_page set revision_id]
    regexp {^([^.]+)[.]} $time2 _ time2

    set title "Differences for ${:name}"
    set context [list $title]

    if {![:exists_query_parameter plain_text_diff]} {
      #
      # try util::html diff if it is available and works
      #
      ad_try {
        set content [::util::html_diff -old $html2 -new $html1 -show_old_p t]
      } on error {errMsg} {
        ns_log notice "::util::html_diff failed on comparing page ${:name}, revisions_id ${:revision_id} and $compare_id"
      }
    }

    if {![info exists content]} {
      #
      # If the fist attempt failed, or the plain text based diff was
      # desired, fall back to proven plain text based diff
      #
      set text1 [ad_html_text_convert -from text/html -to text/plain -- $html1]
      set text2 [ad_html_text_convert -from text/html -to text/plain -- $html2]
      set content [::xowiki::text_diff_in_html $text2 $text1]
    }

    ::xo::Page set_property doc title $title
    array set property_doc [::xo::Page get_property doc]
    ::xo::Page header_stuff

    ${:package_id} return_page -adp /packages/xowiki/www/diff -variables {
      content title context
      time1 time2 user1 user2 revision_id1 revision_id2 property_doc
    }
  }

  ad_proc -private text_diff_in_html {doc1 doc2} {

    Simple plain text based diff, used as fallback.

  } {
    set out ""
    set i 0
    set j 0

    regsub -all \n $doc1 " <br>" doc1
    regsub -all \n $doc2 " <br>" doc2
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
  # Externally callable method: download
  #
  File ad_instproc www-download {} {

    This web-callable method downloads the file content of the current
    File object.  The following query parameter can be used to
    influence the behavior

    @param "filename"  use this query parameter as filename in the content-disposition.
    @param "geometry"  when used on images, the images are scaled before delivery

  } {
    #
    # The package where the object is coming from might be different
    # from the package on which it is delivered. Use the latter one
    # with the proper delivery information.
    #
    set package_id [::xo::cc package_id]
    ::$package_id set mime_type ${:mime_type}
    #
    # Use always ad_returnfile_background, it is clever enough to use
    # the right delivery mode in case of doubt.
    #
    ::$package_id set delivery ad_returnfile_background

    if {[:exists_query_parameter filename]} {
      set fn [::xo::backslash_escape \" [:query_parameter filename]]
      ns_set put [ns_conn outputheaders] Content-Disposition "attachment;filename=\"$fn\""
    }

    set full_file_name [:full_file_name]
    #:log "--F FILE=$full_file_name // ${:mime_type}"

    set geometry [::xo::cc query_parameter geometry ""]
    if {[string match "image/*" ${:mime_type}]
        && $geometry ne ""
      } {
      if {![regexp {^\d*x?\d*$} $geometry]} {
        error "invalid geometry $geometry"
      }
      set tmpdir [ad_tmpdir]
      if {![ad_file isdirectory $tmpdir/$geometry]} {
        file mkdir $tmpdir/$geometry
      }
      set scaled_image $tmpdir/$geometry/${:revision_id}
      if {![ad_file readable $scaled_image]} {
        set cmd [::util::which convert]
        if {$cmd ne ""} {
          if {![catch {exec $cmd -geometry $geometry -interlace None -sharpen 1x2 \
                           $full_file_name $scaled_image}]} {
            return $scaled_image
          }
        }
      } else {
        return $scaled_image
      }
    }
    set modtime [ad_file mtime $full_file_name]
    set cmptime [ns_set iget [ns_conn headers] If-Modified-Since]
    if {$cmptime ne ""} {
      if {[clock scan $cmptime] >= $modtime} {
        #
        # TODO: we should set the status_code and delivery the same
        # way, ... but keep things compatible for now.
        #
        ::xo::cc set status_code 304
        ::$package_id set delivery ns_return
        return ""
      }
    }
    ns_set put [ns_conn outputheaders] Last-Modified [ns_httptime $modtime]

    return $full_file_name
  }

  #
  # We handle delegation to target for most methods in
  # Package->invoke.  Otherwise, we would have to implement several
  # forwarder methods like the following:
  #

  #   FormPage instproc www-download {} {
  #     # If there is a link to a file, it can be downloaded as well
  #     set target [:get_target_from_link_page]
  #     if {$target ne "" && [$target istype ::xowiki::File]} {
  #       $target download
  #     } else {
  #       ${:package_id} error_msg "Method 'download' not implemented for this kind of object"
  #     }
  #   }

  #
  # Helper methods for externally callable method: edit
  #

  Page instproc edit_set_default_values {} {
    # set some default values if they are provided
    foreach param {name title page_order:graph last_page_id:integer nls_language:wordchar} {
      regexp {^([^:]+):?} $param . key
      if {[::${:package_id} exists_query_parameter $key]} {
        #:log "setting [self] set $key [::${:package_id} query_parameter $key]"
        set :$key [::${:package_id} query_parameter $param]
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
  # The method "changed_redirect_url" is a helper method for old-style
  # wiki pages, still using ad_form. Form.edit_data calls this method
  # after a rename operation to optionally redirect the browser after
  # the edit operation to the new url, unless an explicit return_url
  # was specified.
  #
  Page instproc changed_redirect_url {} {
    if {[::${:package_id} exists_query_parameter "return_url"]} {
      return ""
    }
    return [:pretty_link]
  }

  #
  # Externally callable method: edit
  #

  Page ad_instproc www-edit {
    {-new:boolean false}
    {-autoname:boolean false}
    {-validation_errors ""}
  } {

    This web-callable method renders a page in "edit" mode
    (i.e. provide input fields).  This is the old-style edit based on
    the old-style xowiki-form-procs.  FormPages should be used when
    possible for better user experience.

    @param new is this an edit-new operation?
    @param autoname value to be passed to getFormClass
    @param validation_errors ignored in this class, but used for
           compatibility with FormPage.www-edit
  } {
    #
    # We have to keep the instvar for "item_id" for the time being.
    #
    :instvar item_id

    #:log "--edit new=$new autoname=$autoname, valudation_errors=$validation_errors, parent=${:parent_id}"
    :edit_set_default_values
    set fs_folder_id [:edit_set_file_selector_folder]

    if {[::${:package_id} exists_query_parameter "return_url"]} {
      set submit_link [:query_parameter return_url:localurl]
      set return_url $submit_link
    } else {
      #
      # Before we used "." as default submit link (resulting in a
      # "ad_returnredirect .").  However, this does not seem to work
      # in case we have folders in use....
      #
      #set submit_link "."
      set submit_link [:pretty_link]
    }
    #:log "--u submit_link=$submit_link qp=[:query_parameter return_url]"
    set object_type [:info class]

    # We have to do template mangling here; ad_form_template writes
    # form variables into the actual parse-level, so we have to be in
    # our own level in order to access and pass these.
    #
    lappend ::template::parse_level [info level]

    set action_vars [expr {$new ? "{edit-new 1} object_type return_url" : "{m edit} return_url"}]
    #:log "--formclass=[$object_type getFormClass -data [self]] object_type=$object_type"

    #
    # Determine the package_id of some mounted xowiki instance to find
    # the directory + URL, from where the scripts called from Xinha
    # can be used.
    #
    if {[::${:package_id} info class] eq "::xowiki::Package"} {
      #
      # The actual instance is a plain xowiki instance, we can use it.
      #
      set folder_spec [list script_dir [::${:package_id} package_url]]
    } else {
      #
      # The actual instance is not a plain xowiki instance, so, we try
      # to find one, where the current user has at least read
      # permissions.  This act is required for sub-packages, which
      # might not have the script dir.
      #
      set first_instance_id [::xowiki::Package first_instance \
                                 -party_id [::xo::cc user_id] \
                                 -privilege read]
      if {$first_instance_id ne ""} {
        ::xowiki::Package require $first_instance_id
        set folder_spec [list script_dir [::$first_instance_id package_url]]
      }
    }

    if {$fs_folder_id ne ""} {
      lappend folder_spec folder_id $fs_folder_id
    }

    [$object_type getFormClass -data [self]] create ::xowiki::f1 -volatile \
        -action  [export_vars -base [::${:package_id} url] $action_vars] \
        -data [self] \
        -folderspec $folder_spec \
        -submit_link $submit_link \
        -autoname $autoname
    #:log "form created"

    #
    # The variable "item_id" is hard-wired in the old-style "generate"
    # method.
    #
    if {[info exists return_url]} {
      ::xowiki::f1 generate -export [list [list return_url $return_url]]
    } else {
      ::xowiki::f1 generate
    }
    #:log "form rendered"
    ::xowiki::f1 instvar edit_form_page_title context formTemplate

    if {[info exists item_id]} {
      set rev_link  [::${:package_id} make_link [self] revisions]
      set view_link [::${:package_id} make_link [self] view]
    }
    if {[info exists last_page_id]} {
      set back_link [::${:package_id} url]
    }

    set index_link  [::${:package_id} make_link -privilege public ${:package_id}]
    ::xo::Page set_property doc title "[::${:package_id} instance_name] - $edit_form_page_title"

    array set property_doc [::xo::Page get_property doc]
    set edit_tmpl [::${:package_id} get_adp_template "edit"]

    set html [::${:package_id} return_page -adp $edit_tmpl \
                  -form f1 \
                  -variables {
                    item_id {parent_id ${:parent_id}}
                    edit_form_page_title context formTemplate
                    view_link back_link rev_link index_link property_doc
                  }]
    template::util::lpop ::template::parse_level
    #:log "--edit html length [string length $html]"
    return $html
  }

  FormPage instproc setCSSDefaults {} {
    #:log setCSSDefaults
    # check empty
    if {[::xowiki::Package preferredCSSToolkit] eq "bootstrap"} {
      ::xowiki::formfield::FormField parameter {
        {CSSclass form-control}
        {form_item_wrapper_CSSclass form-group}
        {form_widget_CSSclass ""}
        {form_button_CSSclass "btn btn-default"}
        {form_button_wrapper_CSSclass ""}
        {form_help_text_CSSclass help-block}
      }
    } else {
      ::xowiki::formfield::FormField parameter {
        {CSSclass}
        {form_widget_CSSclass form-widget}
        {form_item_wrapper_CSSclass form-item-wrapper}
        {form_button_CSSclass ""}
        {form_button_wrapper_CSSclass form-button}
        {form_help_text_CSSclass form-help-text}
      }
      ::xowiki::Form requireFormCSS
    }
  }

  FormPage instproc action_url {} {
    #
    # Can be overloaded.
    #
    return [:pretty_link]
  }

  FormPage ad_instproc www-edit {
    {-validation_errors ""}
    {-disable_input_fields 0}
    {-view true}
  } {

    This web-callable method renders a form page in "edit" mode
    (i.e. provide input fields).

    The following query parameters can be used to influene the results
    "return_url", "title", "detail_link", "text", and "description".

  } {
    #:log "edit [self args]"

    :setCSSDefaults
    :include_header_info -prefix form_edit
    if {[::xo::cc mobile]} {
      :include_header_info -prefix mobile
    }

    set form [:get_form]
    set anon_instances [:get_anon_instances]
    #:log form=$form
    #:log anon_instances=$anon_instances

    set field_names [:field_names -form $form]
    #:msg field_names=$field_names
    set form_fields [:create_form_fields $field_names]

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
    #:log formgiven=$formgiven

    # check name field:
    #  - if it is for anon instances, hide it,
    #  - if it is required but hidden, show it anyway
    #    (might happen, when e.g. set via @cr_fields ... hidden)
    set name_field [:lookup_form_field -name _name $form_fields]
    if {$anon_instances} {
      #$name_field config_from_spec hidden
    } else {
      if {[$name_field istype ::xowiki::formfield::hidden]
          && [$name_field required] == true
        } {
        $name_field config_from_spec text,required
        $name_field type text
      }
    }

    #
    # Include _text only, if explicitly needed (in form
    # needed(_text))".
    #
    if {![info exists :__field_needed(_text)]} {
      #:msg "setting text hidden"
      set f [:lookup_form_field -name _text $form_fields]
      $f config_from_spec hidden
    }

    if {[:exists_form_parameter __disabled_fields]} {
      #
      # Disable some form-fields since these are disabled in the form
      # as well.
      #
      foreach name [:form_parameter __disabled_fields] {
        set f [:lookup_form_field -name $name $form_fields]
        $f disabled disabled
      }
    }

    #:show_fields $form_fields
    #:log "__form_action [:form_parameter __form_action {}]"

    if {[:form_parameter __form_action ""] eq "save-form-data"} {
      #
      # We want to save the form data, so we have to validate.
      #
      #:log "we have to validate"
      #
      # In case we are triggered internally, we might not have a
      # a connection and therefore do not valide the csrf token.
      #
      if {![::${:package_id} exists __batch_mode]} {
        security::csrf::validate
      }

      lassign [:get_form_data $form_fields] validation_errors category_ids
      if {$validation_errors != 0} {
        #
        # We have validation errors.
        #
        #:log "$validation_errors validation errors in $form_fields"
        #foreach f $form_fields { :log "$f: [$f name] '[$f set value]' err: [$f error_msg] " }
        #
        # In case we are triggered internally, we might not have a
        # a connection, so we don't present the form with the
        # error messages again, but we return simply the validation
        # problems.
        #
        if {[::${:package_id} exists __batch_mode]} {
          set errors [list]
          foreach f $form_fields {
            if {[$f error_msg] ne ""} {
              lappend errors [list field [$f name] value [$f set value] error [$f error_msg]]
            }
          }
          set evaluation_errors ""
          if {[::${:package_id} exists __evaluation_error]} {
            set evaluation_errors "\nEvaluation error: [::${:package_id} set __evaluation_error]"
            ::${:package_id} unset __evaluation_error
          }
          error "[llength $errors] validation error(s): $errors $evaluation_errors"
        }
        #
        # Reset the name in error cases to the original one.
        #
        set :name [:form_parameter __object_name]
      } else {
        #
        # We have no validation errors, so we can save the content.
        #
        :save_data \
            -use_given_publish_date [expr {"_publish_date" in $field_names}] \
            [::xo::cc form_parameter __object_name ""] $category_ids
        #
        # The data might have references. Perform the rendering here to compute
        # the references instead on every view (which would be safer, but slower). This is
        # roughly the counterpart to edit_data and save_data in ad_forms.
        #
        set content [:render -update_references all]
        #:log "after save refs=[expr {[info exists :references]?${:references} : {NONE}}]"

        set redirect_method [:form_parameter __form_redirect_method "view"]
        #:log "redirect_method $redirect_method"

        if {$redirect_method eq "__none"} {
          return
        } else {
          if {$redirect_method ne "view"} {
            set qp "?m=$redirect_method"
          } else {
            set qp ""
          }
          set url [:pretty_link]$qp
          #
          # The method query_parameter uses now "::xo::cc set_parameter ...."
          # with highest precedence
          #
          set return_url [::${:package_id} query_parameter return_url $url]
          #:log "${:name}: url=$url, return_url=$return_url"
          ::${:package_id} returnredirect $return_url

          return
        }
      }
    } elseif {[:form_parameter __form_action ""] eq "view-form-data"
              && ![info exists :__feedback_mode]
            } {
      #
      # We have nothing to save (maybe everything is read-only). Check
      # __feedback_mode to prevent recursive loops.
      #
      set redirect_method [:form_parameter __form_redirect_method "view"]
      #:log "__redirect_method=$redirect_method"
      return [:www-view]
    } else {
      #
      # Build the input form and display the current values.
      #
      #:log "form_action is something different: <[:form_parameter __form_action {}]>"
      if {[:is_new_entry ${:name}]} {
        set :creator [::xo::get_user_name [::xo::cc user_id]]
        set :nls_language [::${:package_id} default_locale]
      }

      #array set __ia ${:instance_attributes}
      :load_values_into_form_fields $form_fields

      foreach f $form_fields {set ff([$f name]) $f }

      #
      # For named entries, just set the entry fields to empty,
      # without changing the instance variables
      #
      #:log "my is_new_entry ${:name} = [:is_new_entry ${:name}]"
      if {[:is_new_entry ${:name}]} {

        if {$anon_instances} {
          set basename [::xowiki::autoname basename [${:page_template} name]]
          set name [::xowiki::autoname new -name $basename -parent_id ${:parent_id}]
          #:log "generated name=$name, page_template-name=[${:page_template} name]"
          $ff(_name) value $name
        } else {
          $ff(_name) value [$ff(_name) default]
        }
        if {![$ff(_title) istype ::xowiki::formfield::hidden]} {
          $ff(_title) value [$ff(_title) default]
        }
        foreach param [list title detail_link:localurl text description] {
          regexp {^([^:]+):?} $param . var
          if {[:exists_query_parameter $var]} {
            set value [:query_parameter $param]
            switch -- $var {
              detail_link {
                set f [:lookup_form_field -name $var $form_fields]
                $f value [$f convert_to_external $value]
              }
              title - text - description {
                set f [:lookup_form_field -name _$var $form_fields]
              }
            }
            $f value [$f convert_to_external $value]
          }
        }
      }

      $ff(_name) set transmit_field_always 1
      $ff(_nls_language) set transmit_field_always 1
    }

    #
    # Some final sanity checks.
    #
    :form_fields_sanity_check $form_fields
    :post_process_form_fields $form_fields

    #
    # The following command would be correct, but does not work due to a bug in
    # tdom.
    # set form [:regsub_eval  \
        #              [template::adp_variable_regexp] $form \
        #              {:form_field_as_html -mode edit "\\\1" "\2" $form_fields}]
    # Due to this bug, we program around and replace the at-character
    # by \x03 to avoid conflict with the input and we replace these
    # magic chars finally with the fields resulting from tdom.

    set form [:substitute_markup $form]
    set form [string map [list @ \x03] $form]
    #:msg form=$form

    dom parse -simple -html $form :doc
    ${:doc} documentElement :root

    if {${:root} eq ""} {
      error "form '$form' is not valid"
    }

    ::xo::require_html_procs
    ${:root} firstChild fcn
    #:msg "orig fcn $fcn, root ${:root} [${:root} nodeType] [${:root} nodeName]"

    set formNode [lindex [${:root} selectNodes //form] 0]
    if {$formNode eq ""} {
      :msg "no form found in page [${:page_template} name]"
      set rootNode ${:root}
      $rootNode firstChild fcn
    } else {
      set rootNode $formNode
      $rootNode firstChild fcn
      # Normally, the root node is the formNode, fcn is the first
      # child (often a TEXT_NODE), but ic can be even empty.
    }


    #
    # Prepend some fields above the HTML contents of the form.
    #
    $rootNode insertBeforeFromScript {
      ::html::div {
        ::html::input -type hidden -name __object_name -value ${:name}
        ::html::input -type hidden -name __form_action -value save-form-data
        ::html::input -type hidden -name __current_revision_id -value ${:revision_id}
        ::html::CSRFToken
      }
      #
      # Insert automatic form fields on top.
      #
      foreach att $field_names {
        #if {$formgiven && ![string match _* $att]} continue
        if {[info exists :__field_in_form($att)]} continue
        set f [:lookup_form_field -name $att $form_fields]
        #:log "insert auto_field $att $f ([$f info class])"
        $f render_item
      }
    } $fcn
    #
    # Append some fields after the HTML contents of the form.
    #
    set button_class(wym) ""
    set button_class(xinha) ""
    set has_file 0
    $rootNode appendFromScript {
      # append category fields
      foreach f $form_fields {
        #:msg "[$f name]: is wym? [$f has_instance_variable editor wym]"
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

      #
      # Insert unreported errors.
      #
      foreach f $form_fields {
        if {[$f set error_msg] ne ""
            && ![$f exists error_reported]
          } {
          $f render_error_msg
        }
      }
      #
      # Add a submit field(s) at bottom.
      #
      :render_form_action_buttons -CSSclass [string trim "$button_class(wym) $button_class(xinha)"]
    }


    if {$formNode ne ""} {

      if {[:exists_query_parameter "return_url"]} {
        set return_url [:query_parameter return_url:localurl]
      } else {
        #
        # When no return_url is specified and we edit a page different
        # from the invoked page, we use the calling page for default
        # redirection.  We do not want to redirect to some "embedded"
        # object after the edit. This happens if one edits e.g. a page
        # through a link.
        #
        if {[::xo::cc exists invoke_object]
            && [::xo::cc invoke_object] ne [self]
          } {
          #:log "=== no return_url specified, using [::xo::cc url] or [[::${:package_id} context] url]"
          set return_url [::xo::cc url]
        }
      }
      set m [:form_parameter __form_redirect_method "edit"]
      set url [export_vars -no_base_encode -base [:action_url] {m return_url}]
      #:log "=== setting action <$url> for form-action my-name ${:name}"
      $formNode setAttribute action $url method POST role form
      if {$has_file} {$formNode setAttribute enctype multipart/form-data}
      Form add_dom_attribute_value $formNode class [${:page_template} css_class_name]
    }

    :set_form_data $form_fields
    if {$disable_input_fields} {
      #
      # (a) Disable explicit input fields.
      #
      foreach f $form_fields {$f disabled 1}
      #
      # (b) Disable input in HTML-specified fields.
      #
      set disabled [Form dom_disable_input_fields $rootNode]
      #
      # Collect these variables in a hidden field to be able to
      # distinguish later between e.g. un unchecked checkmark and an
      # disabled field. Maybe, we have to add the fields from case (a)
      # as well.
      #
      $rootNode appendFromScript {
        ::html::input -type hidden -name "__disabled_fields" -value $disabled
      }
    }
    :post_process_dom_tree ${:doc} ${:root} $form_fields

    set html [${:root} asHTML]
    set html [:regsub_eval  \
                  {(^|[^\\])\x03([[:alnum:]_:]+)\x03} $html \
                  {:form_field_as_html -mode edit "\\\1" "\2" $form_fields}]
    #
    # Replace unbalanced @ characters.
    #
    set html [string map [list \x03 @] $html]

    #:log "calling VIEW with HTML [string length $html]"
    if {$view} {
      :www-view $html
    } else {
      return $html
    }
  }


  #
  # Externally callable method: file-upload
  #

  FormPage ad_instproc www-file-upload {} {

    This web-callable method can be used for uploading files using the
    current object as parent object for the new content. This method
    is typically called via drop-zone in a POST request, where the
    FormPage is a folder (which is treated as parent object)

  } {

    if {[ns_conn method] ne "POST"} {
      error "method should be called via POST"
    }
    set form [ns_getform]

    #
    # Get the uploader via query parameter.  We have currently the
    # following uploader classes defined (see
    # xowiki-uploader-procs.tcl)
    #
    #   - ::xowiki::UploadFile
    #   - ::xowiki::UploadPhotoForm
    #
    ::security::csrf::validate
    set uploader [ns_set get $form uploader File]
    set uploaderClass ::xowiki::UploadFile
    if {[info commands ::xowiki::Upload$uploader] ne ""} {
      set uploaderClass ::xowiki::Upload$uploader
    }
    set uploaderObject [$uploaderClass new \
                            -file_name [ns_set get $form upload] \
                            -content_type [ns_set get $form upload.content-type] \
                            -tmpfile [ns_set get $form upload.tmpfile] \
                            -parent_object [self]]
    set result [$uploaderObject store_file]
    $uploaderObject destroy
    ns_return [dict get $result status_code] text/plain [dict get $result message]
  }

  #
  # Externally callable method: toggle-modebutton
  #
  FormPage ad_instproc www-toggle-modebutton {} {

    AJAX called function, called via POST. The function toggles the
    state of a button in the backend. The client provides the name of
    the button as form field named "button". If none is provided, the
    button is named as default "admin"

  } {
    #
    # Check, if this function was called via POST
    #
    if {[ns_conn method] ne "POST"} {
      error "method should be called via POST"
    }

    #
    # Get the toggle name. Modebuttons are named like:
    #
    #    ::xowiki::mode::admin
    #
    set form [ns_getform]
    set button [ns_set get $form button admin]
    ::xowiki::mode::$button toggle
    ns_return 200 text/plain ok
  }

  #
  # Externally callable method: list
  #
  Page ad_instproc www-list {} {

    This web-callable method provides a listing of pages.

    When the query parameter "children" is used,  it returns
    the children of this item via the "child-resources" includelet.

    Otherwise, when this method is called on any kind of Form, it
    returns the form instances via the "form-usages" includelet.

    Otherwise, when this method is called on any kind of folder pages,
    it returns the elements of this folder via the "child-resources"
    includelet.

    If the above fails, it redirects to the starting page.

  } {
    if {[:is_form] && ![:exists_query_parameter children]} {
      #
      # The following line is here to provide a short description for
      # larger form-usages (a few MB) where otherwise
      # "ad_html_text_convert" in Page.get_description tend to use
      # forever (at least in Tcl 8.5)
      #
      set :description "form-usages for ${:name} ${:title}"

      return [:www-view [:include [list form-usages -form_item_id ${:item_id}]]]
    }
    if {[:is_folder_page] || [:exists_query_parameter children]} {
      return [:www-view [:include [list child-resources -publish_status all]]]
    }
    #:msg "method list undefined for this kind of object"
    ${:package_id} returnredirect [::xo::cc url]
  }

  #
  # Externally callable method: make-live-revision
  #

  Page ad_instproc www-make-live-revision {} {

    This web-callable method makes the revision specified by parameter
    "revision_id" the live revision, or when this is not available,
    the parameter "local_return_url".

  } {
    set page_id [:query_parameter "revision_id"]
    if {[string is integer -strict $page_id]} {
      set revision_id $page_id
    } else {
      set revision_id ${:revision_id}
    }
    #:log "--M set_live_revision $revision_id"
    :set_live_revision -revision_id $revision_id
    ${:package_id} returnredirect [:query_parameter "return_url" \
                                       [:query_parameter "local_return_url" \
                                            [export_vars -base [::${:package_id} url] {{m revisions}}]]]
  }

  #
  # Externally callable method: toggle-publish-status
  #
  Page ad_instproc www-toggle-publish-status {} {

    This web-callable method toggles from arbitrary states to "ready"
    and from "ready" to "production".

  } {
    if {${:publish_status} ne "ready"} {
      set new_publish_status "ready"
    } else {
      set new_publish_status "production"
    }
    :update_publish_status $new_publish_status
    ${:package_id} returnredirect [:query_parameter "return_url" [ad_return_url]]
  }

  #
  # Externally callable method: popular-tags
  #
  Page ad_instproc www-popular-tags {} {

    AJAX called function, returns an HTML snippet with the popular
    tags.

  } {
    set package     ::${:package_id}
    set limit       [:query_parameter "limit:integer" 20]
    set weblog_page [$package get_parameter weblog_page weblog]
    set href        [$package pretty_link -parent_id [$package folder_id] $weblog_page]?summary=1

    set entries [list]
    xo::dc foreach get_popular_tags \
        [::xo::dc select \
             -vars "count(*) as nr, tag" \
             -from "xowiki_tags" \
             -where "item_id = [ns_dbquotevalue ${:item_id}]" \
             -groupby "tag" \
             -orderby "nr" \
             -limit $limit] {
               set label [ns_quotehtml "$tag ($nr)"]
               lappend entries "<a href='[ns_quotehtml $href&ptag=[ad_urlencode $tag]]'>$label</a>"
             }
    ns_return 200 text/html "<span class='popular-tags'>[_ xowiki.popular_tags_label]: [join $entries {, }]</span>"
    ad_script_abort
  }

  #
  # Externally callable method: save-attributes
  #

  Page ad_instproc www-save-attributes {} {

    The web-callable method save-attributes is typically callable over
    the REST interface. It allows one to save attributes of a page
    without adding a new revision.

  } {
    set field_names [:field_names]
    set form_fields [list]
    set query_field_names [list]

    set validation_errors 0
    foreach field_name $field_names {
      if {[::xo::cc exists_form_parameter $field_name]} {
        lappend form_fields [:create_form_field $field_name]
        lappend query_field_names $field_name
      }
    }
    #:show_fields $form_fields
    lassign [:get_form_data -field_names $query_field_names $form_fields] validation_errors category_ids

    if {$validation_errors == 0} {
      #
      # We have no validation errors, so we can save the content.
      #
      set update_without_revision [::${:package_id} query_parameter replace:boolean 0]

      foreach form_field $form_fields {
        #
        # Fix richtext content in accordance with oacs conventions.
        #
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
            #
            # Empty slot means that we have an instance_attribute; we
            # save all in one statement below.
            #
            set update_instance_attributes 1
          } else {
            error "Not implemented yet"
            :update_attribute_from_slot $s [$form_field value]
          }
        }
        if {$update_instance_attributes} {
          set s [:find_slot instance_attributes]
          :update_attribute_from_slot $s [:instance_attributes]
        }
      } else {
        #
        # Perform standard update (with revision).
        #
        :save_data \
            -use_given_publish_date [expr {"_publish_date" in $field_names}] \
            [::xo::cc form_parameter __object_name ""] $category_ids
      }
      ${:package_id} returnredirect \
          [:query_parameter "return_url" [:pretty_link]]
      return
    } else {
      # TODO: handle errors in a user friendly way
      ns_log warning "www-save-attributes: we have $validation_errors validation_errors"
    }
    ${:package_id} returnredirect \
        [:query_parameter "return_url" [:pretty_link]]
  }

  #
  # Externally callable method: autosave-attribute
  #
  Page ad_instproc www-autosave-attribute {} {

    The web-callable method which is a simplified version of
    save-attributes, but which does NOT perform input validation,
    which might be a problem in case of partial input.

  } {

    set field_names [:field_names]
    #ns_log notice "[self] autosave-attribute called field-names: $field_names"
    set provided_form_parameters [xo::cc get_all_form_parameter]
    set keys [dict keys $provided_form_parameters]

    if {[llength $keys] == 1} {
      set key   [lindex $keys 0]
      set value [::xo::cc form_parameter $key]
      ns_log notice "[self] autosave-attribute save '$key' <$value>"
      set prefix ""
      regexp {^([^.]+)[.]} $key . prefix

      if {$prefix ne "" && $prefix in $field_names} {
        #
        # We are inside a compound field, which is saved in the instance
        # attributes.
        #
        #ns_log notice "SAVE old ia <${:instance_attributes}>"
        if {[dict exists ${:instance_attributes} $prefix]} {
          set innerDict [dict get ${:instance_attributes} $prefix]
        } else {
          set innerDict ""
        }
        dict set innerDict $key $value
        dict set :instance_attributes $prefix $innerDict

        #ns_log notice "SAVE new ia <${:instance_attributes}>"
        set s [:find_slot instance_attributes]
        :update_attribute_from_slot $s ${:instance_attributes}

      } elseif {$prefix eq "" && $key in $field_names} {
        #
        # It is a plain attribute, either from the cr-attributes
        # (starting with an "_") or from the instance attributes.
        #
        if {[string match _* $key]} {
          set s [:find_slot [string range $key 1 end]]
          :update_attribute_from_slot $s $value
        } else {
          set s [:find_slot instance_attributes]
          dict set :instance_attributes $key $value
          :update_attribute_from_slot $s ${:instance_attributes}
        }
      } else {
        error "unexpected condition key <$key> value <$value>"
      }
      ns_return 200 text/plain ok

    } else {
      ns_log warning "LAST expecting a single form parameter with a prefix keys <$keys>"
      ns_return 404 text/plain "not ok"
    }
    ns_log notice "SAVE-att DONE"
    ad_script_abort
  }


  #
  # Externally callable method: revisions
  #

  Page ad_instproc www-revisions {} {

    This web-callable method lists the revisions based. The rendering
    is actually performed in the cr-procs, but can overloaded per
    package.

  } {
    #set context [list [list [::${:package_id} url] ${:name} ] [_ xotcl-core.revisions]]
    #set title "[_ xotcl-core.revision_title] '${:name}'"
    return [:www-view [next]]
  }

  #
  # Externally callable method: save-tags
  #

  Page ad_instproc www-save-tags {} {

    This web-callable method saves tags (provided via form parameter "new_tags").

  } {
    ::xowiki::Page save_tags \
        -user_id [::xo::cc user_id] \
        -item_id ${:item_id} \
        -revision_id ${:revision_id} \
        -package_id ${:package_id} \
        [:form_parameter new_tags]

    ::${:package_id} returnredirect \
        [:query_parameter "return_url" [::${:package_id} url]]
  }

  #
  # Externally callable method: validate-attribute
  #

  Page ad_instproc www-validate-attribute {} {

    This web-callable method can be used to validate form attributes,
    typically called via AJAX.

  } {
    set field_names [:field_names]
    set validation_errors 0

    #
    # Get the first transmitted form field.
    #
    foreach field_name $field_names {
      if {[::xo::cc exists_form_parameter $field_name]} {
        set form_fields [:create_form_field $field_name]
        set query_field_names $field_name
        break
      }
    }
    lassign [:get_form_data -field_names $query_field_names $form_fields] \
        validation_errors category_ids
    set error ""
    if {$validation_errors == 0} {
      set status_code 200
    } else {
      set status_code 406
      foreach f $form_fields {
        if {[$f error_msg] ne ""} {
          set error [::xo::localize [$f error_msg] 1]
        }
      }
    }
    ns_return $status_code text/html $error
  }

  #
  # Externally callable method: view
  #

  Page ad_instproc www-view {{content ""}} {

    This web-callable method is called when viewing wiki content.
    The method "view" is used primarily for the toplevel call, when
    the xowiki page is viewed.  It is not intended for e.g. embedded
    wiki pages (see include), since it contains full framing, etc.

    When "content" is not provided via the method parameter - the
    common case - the rendered content is the result of the "render"
    method of the current object.

  } {
    #
    #
    ::xowiki::Page set recursion_count 0
    set page_package_id    ${:package_id}
    set context_package_id [::xo::cc package_id]
    set folder_id [::$page_package_id folder_id]

    #:msg "page_package_id=$page_package_id, context_package_id=$context_package_id"

    set template_file [ns_normalizepath [:query_parameter "template_file" \
                                             [::$context_package_id get_parameter template_file view-default]]]
    if {[nsf::is object ::xowiki::$template_file]} {
      $template_file before_render [self]
    }

    #
    # Set up template variables.
    #
    set object_type [::$page_package_id get_parameter object_type [:info class]]
    set rev_link    [::$page_package_id make_link [self] revisions]

    if {[::$context_package_id query_parameter m ""] eq "edit"} {
      set view_link [::$page_package_id make_link [self] view return_url]
      set edit_link ""
    } else {
      set edit_link [::$page_package_id make_link [self] edit return_url]
      set view_link ""
    }

    set delete_link [::$page_package_id make_link [self] delete return_url]
    if {[info exists :__link(new)]} {
      set new_link [set :__link(new)]
    } else {
      set new_link [:new_link $page_package_id]
    }

    set admin_link  [::$context_package_id make_link -privilege admin -link admin/ ::$context_package_id]
    set index_link  [::$context_package_id make_link -privilege public ::$context_package_id]
    set view_link   [::$page_package_id make_link [self] view return_url]

    set notification_subscribe_link ""
    if {[::$context_package_id get_parameter "with_notifications" 1]} {
      if {[::xo::cc user_id] != 0} {
        #
        # notifications require login
        #
        set notifications_return_url [expr {[info exists return_url] ? $return_url : [ad_return_url]}]
        set notification_type [notification::type::get_type_id -short_name xowiki_notif]
        set notification_text "Subscribe to [::$context_package_id instance_name]"
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

    #
    # The content may be passed by other methods (e.g. edit) to
    # make use of the same templating machinery below.
    #
    if {$content eq ""} {
      set content [:render]
      #:msg "--after render"
    }

    #
    # These variables can be influenced via set-parameter.
    #
    set autoname [::$page_package_id get_parameter autoname 0]

    #
    # Setup top includeletes and footers.
    #

    set footer [:htmlFooter -content $content]
    set top_includelets ""
    set vp [string trim [::$context_package_id get_parameter "top_includelet" ""]]
    if {$vp ne "" && $vp ne "none"} {
      set top_includelets [:include $vp]
    }

    if {[::$context_package_id get_parameter "MenuBar" 0]} {
      #
      # The following block should not be here, but in the templates.
      #
      #set showFolders [::$context_package_id get_parameter "MenuBarWithFolder" 1]
      #if {$showFolders} {
      #  set folderhtml [:include {folders -style folders}]
      #} else {
      #  set folderhtml ""
      #}

      set folderhtml [:include {folders -style folders}]
      ::xo::Page set_property body folderHTML $folderhtml
      # TODO: there should be no need to pass manually folderhtml,
      # use the property instead

      #
      # At this place, the menu should be complete, we can render it.
      #
      set mb [::xowiki::MenuBar info instances -closure]
      if {$mb ne ""} {
        set mbHTML [$mb render-preferred]
        ::xo::Page set_property body menubarHTML $mbHTML
      }
    }

    if {[::$context_package_id get_parameter "with_user_tracking" 1]} {
      :record_last_visited
    }

    #
    # Deal with the views package (many thanks to Malte for this
    # snippet!)
    #
    if {[::$context_package_id get_parameter with_views_package_if_available 1]
        && [info commands ::views::record_view] ne ""} {
      views::record_view -object_id ${:item_id} -viewer_id [::xo::cc user_id]
      array set views_data [views::get -object_id ${:item_id}]
    }

    if {[:exists_query_parameter return_url]} {
      set return_url [:query_parameter return_url]
    }

    #:log "--after notifications [info exists notification_image]"

    set master [::$context_package_id get_parameter "master" 1]
    if {![string is boolean -strict $master]} {
      ad_return_complaint 1 "value of master is not boolean"
      ad_script_abort
    }

    if {$master} {
      set context [list ${:title}]
      #:msg "$context_package_id title=[::$context_package_id instance_name] - ${:title}"
      #:msg "::xo::cc package_id = [::xo::cc package_id]  ::xo::cc url= [::xo::cc url] "
      ::xo::Page set_property doc title "[::$context_package_id instance_name] - ${:title}"
      ::xo::Page set_property body title ${:title}

      # We could offer a user to translate the current page to his preferred language
      #
      # set create_in_req_locale_link ""
      # if {[::$context_package_id get_parameter use_connection_locale 0]} {
      #  $context_package_id get_lang_and_name -path [::$context_package_id set object] req_lang req_local_name
      #  set default_lang [::$page_package_id default_language]
      #  if {$req_lang ne $default_lang} {
      #      set l [Link create new -destroy_on_cleanup \
          #             -page [self] -type language -stripped_name $req_local_name \
          #             -name ${default_lang}:$req_local_name -lang $default_lang \
          #             -label $req_local_name -parent_id ${:parent_id} -item_id 0 \
          #                 -package_id $context_package_id -init \
          #             -return_only undefined]
      #      $l render
      #   }
      # }

      #:log "--after context delete_link=$delete_link "
      #set template [::$context_package_id get_parameter "template" ""]
      set template ""
      set page [self]

      foreach css [::$context_package_id get_parameter extra_css ""] {
        ::xo::Page requireCSS -order 10 $css
      }

      #
      # Refetch "template_file", since it might have been changed via
      # set-parameter the cache flush (next line) is not pretty here
      # and should be supported from xotcl-core.
      #
      ::xo::cc unset -nocomplain cache([list $context_package_id get_parameter template_file])
      set template_file [:query_parameter "template_file" \
                             [::$context_package_id get_parameter template_file view-default]]
      #
      # If the template_file does not have a path, assume it in the
      # standard location.
      #
      if {[string range $template_file 0 0] eq "/"} {
        ns_log warning "ignore template file on non-standard location: $template_file"
        set template_file [::$context_package_id get_parameter \
                               -check_query_parameter false \
                               -nocache \
                               template_file view-default]
      }
      set template_file [::${:package_id} get_adp_template $template_file]

      # Force xowiki css to be loaded first(ish), so we can override
      # its styling via the theme (e.g. different buttons...). This
      # uses the "template::head" API directly, since resources from
      # requireCSS are typically loaded later than those from the theme.

      template::head::add_css \
          -href urn:ad:css:xowiki-[::xowiki::Package preferredCSSToolkit] \
          -order 0

      #
      # Popular tags handling (should probably go to includelets)
      #
      if {$footer ne ""} {
        template::add_body_script -script {
          function get_popular_tags(popular_tags_link, prefix) {
            var http = new XMLHttpRequest();
            http.open('GET', popular_tags_link, true);
            http.onreadystatechange = function() {
              if (http.readyState == 4) {
                if (http.status != 200) {
                  alert('Something wrong in HTTP request, status code = ' + http.status);
                } else {
                  var e = document.getElementById(prefix + '-popular_tags');
                  e.innerHTML = http.responseText;
                  e.style.display = 'block';
                }
              }
            };
            http.send(null);
          }
        }
      }

      #
      # The method header_stuff performs the required
      # template::head::add_script and template::head::add_css
      # etc. operations
      #
      ::xo::Page header_stuff

      if {![info exists :description]} {
        set :description [:get_description $content]
      }

      if {[info commands ::template::head::add_meta] ne ""} {
        #set meta(language) [:lang]
        ::xo::Page set_property doc title_lang [:lang]
        set meta(description) [:description]
        set meta(keywords) ""
        if {[:istype ::xowiki::FormPage]} {
          set meta(keywords) [string trim [:property keywords]]
          if {[:property html_title] ne ""} {
            ::xo::Page set_property doc title [:property html_title]
          }
        }
        if {$meta(keywords) eq ""} {
          set meta(keywords) [::$context_package_id get_parameter keywords ""]
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
      array set body [::xo::Page get_property body]
      array set doc  [::xo::Page get_property doc]

      if {$page_package_id != $context_package_id} {
        set page_context [::$page_package_id instance_name]
      }

      if {$template ne ""} {

        #
        # Initialize and set the template variables, to be used by
        # a. "adp_compile" / "adp_eval"
        # b. "return_page" / "adp_include"
        #

        set __including_page $page
        #set __adp_stub [acs_root_dir]/packages/xowiki/www/view-default
        set __adp_stub [::$context_package_id get_adp_template view-default]

        set template_code [template::adp_compile -string $template]
        #
        # Make sure that <master/> and <slave/> tags are processed
        #
        append template_code {
          if { [info exists __adp_master] } {
            set __adp_output [template::adp_parse $__adp_master  \
                                  [concat [list __adp_slave $__adp_output] \
                                       [array get __adp_properties]]]
          }
        }
        ad_try {
          set content [template::adp_eval template_code]
          ns_return 200 text/html $content
        } on error {errMsg} {
          ns_return 200 text/html "Error in Page ${:name}: $errMsg<br>$template"
        }
        ad_script_abort
      } else {
        # use adp file
        #:log "use adp"
        set package_id $context_package_id
        set title      ${:title}
        set name       ${:name}
        set item_id    ${:item_id}
        ::$context_package_id return_page -adp $template_file -variables {
          name title item_id context return_url
          content footer package_id page_package_id page_context
          rev_link edit_link delete_link new_link admin_link index_link view_link
          notification_subscribe_link notification_image
          top_includelets page views_data body doc
        }
      }
    } else {
      set :mime_type [::xo::cc get_parameter content-type text/html]
      return $content
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
                                       {-nls_language ""}
                                     } {

    array set __att [list publish_status 1]
    foreach att [list last_modified creation_user {*}[::xowiki::FormPage array names db_slot]] {
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
      #:log "short_spec of $field_name <$short_spec> field_spec <$field_spec> cr_field_spec <$cr_field_spec>"

      switch -glob -- $field_name {
        __* {error not_allowed}
        _* {
          set varname [string range $field_name 1 end]
          if {![info exists __att($varname)]} {
            error "unknown attribute $field_name"
          }
          #:log "create_raw_form_field of $field_name <$cr_field_spec,$short_spec>"
          set f [$base_item create_raw_form_field \
                     -name $field_name \
                     -slot [$base_item find_slot $varname] \
                     -spec $cr_field_spec,$short_spec \
                     -nls_language $nls_language \
                    ]
          #:log "---> $f <[$f label]>"
          $f set __base_field $varname
        }
        default {
          set f [$base_item create_raw_form_field \
                     -name $field_name \
                     -slot "" \
                     -spec $field_spec,$short_spec \
                     -nls_language $nls_language \
                    ]
        }
      }
      lappend form_fields $f
    }
    return $form_fields
  }

  Page proc find_slot {-start_class:required name} {
    foreach cl [list $start_class {*}[$start_class info heritage]] {
      set slotobj ${cl}::slot::$name
      if {[nsf::is object $slotobj]} {
        #:msg $slotobj
        return $slotobj
      }
    }
    return ""
  }

  Page instproc find_slot {-start_class name} {
    if {![info exists start_class]} {
      set start_class [:info class]
    }
    return [::xowiki::Page find_slot -start_class $start_class $name]
  }

  Page instproc create_raw_form_field {
    -name
    {-slot ""}
    {-spec ""}
    {-configuration ""}
    {-omit_field_name_spec:boolean false}
    {-nls_language ""}
  } {
    set save_slot $slot
    if {$slot eq ""} {
      # We have no slot, so create a minimal slot. This should only happen for instance attributes
      set slot [::xo::Attribute new -pretty_name $name -datatype text -noinit]
      $slot destroy_on_cleanup
    }
    if {$nls_language eq ""} {
      set nls_language [:nls_language]
    }

    set spec_list [list]
    if {[$slot exists spec]} {lappend spec_list [$slot set spec]}
    if {$spec ne ""}         {lappend spec_list $spec}
    #:msg "[self args] spec_list $spec_list"
    #:msg "$name, spec_list = '[join $spec_list ,]'"

    if {[$slot exists pretty_name]} {
      set label [$slot set pretty_name]
    } else {
      set label $name
      :log "no pretty_name for variable $name in slot $slot"
    }

    if {[$slot exists default]} {
      #:msg "setting ff $name default = [$slot default]"
      set default [$slot default]
    } else {
      set default ""
    }
    set f [::xowiki::formfield::FormField new -name $name \
               -id        [::xowiki::Includelet html_id F.${:name}.$name] \
               -locale    $nls_language \
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
    $f configure {*}$configuration
    return $f
  }

  PageInstance instproc create_raw_form_field {
    -name
    {-slot ""}
    {-spec ""}
    {-configuration ""}
    {-omit_field_name_spec:boolean false}
    {-nls_language ""}
  } {
    # For workflows, we do not want to get the form constraints of the
    # page itself (i.e. the property of the generic workflow form) but
    # just the configured properties. Otherwise, we get for a
    # wrong results for e.g. "{{form-usages -form de:Thread.wf ...}}"
    # which picks up the label for the _title from the generic Workflow.
    # So, when we have configured properties, we use it, use the
    # primitive one just on despair.  Not sure, what the best solution
    # is,... maybe an additional flag.
    if { $omit_field_name_spec} {
      set short_spec ""
    } else {
      set short_spec [:get_short_spec $name]
      # :msg "[self] get_short_spec $name returns <$short_spec>"
    }

    #:log "create form-field '$name', short_spec '$short_spec' spec '$spec', slot=$slot"
    set spec_list [list]
    if {$spec ne ""}       {lappend spec_list $spec}
    if {$short_spec ne ""} {lappend spec_list $short_spec}
    #:log "$name: short_spec '$short_spec', spec_list 1 = '[join $spec_list ,]'"
    set f [next \
               -name $name \
               -slot $slot \
               -spec [join $spec_list ,] \
               -configuration $configuration \
               -nls_language $nls_language \
              ]
    #:log "created form-field '$name' $f [$f info class] validator=[$f validator] p=[$f info precedence]"
    return $f
  }


  FormPage instproc create_category_fields {} {
    set category_spec [:get_short_spec @categories]
    # Per default, no category fields in FormPages, since the can be
    # handled in more detail via form-fields.
    if {$category_spec eq ""} {return ""}

    # a value of "off" turns the off as well
    foreach f [split $category_spec ,] {
      if {$f eq "off"} {return ""}
    }

    set category_fields [list]
    set container_object_id ${:package_id}
    set category_trees [category_tree::get_mapped_trees $container_object_id]
    set category_ids [category::get_mapped_categories ${:item_id}]
    #:msg "mapped category ids=$category_ids"

    foreach category_tree $category_trees {
      lassign $category_tree tree_id tree_name subtree_id assign_single_p require_category_p

      set options [list]
      #if {!$require_category_p} {lappend options [list "--" ""]}
      set value [list]
      foreach category [::xowiki::Category get_category_infos \
                            -subtree_id $subtree_id -tree_id $tree_id] {
        lassign $category category_id category_name deprecated_p level
        if {$category_id in $category_ids} {lappend value $category_id}
        set category_name [ns_quotehtml [lang::util::localize $category_name]]
        if { $level>1 } {
          set category_name "[string repeat {&nbsp;} [expr {2*$level-4}]]..$category_name"
        }
        lappend options [list $category_name $category_id]
      }
      set f [::xowiki::formfield::FormField new \
                 -name "__category_${tree_name}_$tree_id" \
                 -locale [:nls_language] \
                 -label $tree_name \
                 -type select \
                 -value $value \
                 -required $require_category_p]
      #:msg "category field ${:name} created, value '$value'"
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
    set fields [${:root} selectNodes "//form//*\[@name='$att'\]"]
    if {$fields eq ""} {return ""}
    foreach field $fields {
      #
      # Handling first TEXTAREA
      #
      if {[$field nodeName] eq "textarea"} {
        return [$field nodeValue]
      }
      if {[$field nodeName] ne "input"} continue
      #
      # Handling now just INPUT types (only one needed so far)
      #
      set type [expr {[$field hasAttribute type] ? [$field getAttribute type] : "text"}]
      switch -- $type {
        checkbox {
          #:msg "get_form_value not implemented for $type"
        }
        radio {
          #:msg "get_form_value not implemented for $type"
        }
        hidden -
        password -
        text {
          if {[$field hasAttribute value]} {
            return [$field getAttribute value]
          }
        }
        default {
          #:log "can't handle $type so far $att=$value"
        }
      }
    }
    return ""
  }

  FormPage instproc set_form_value {att value} {
    #:msg "set_form_value '$att' to '$value'"
    #
    # Feed the provided value into an HTML form provided via the
    # instance variable root.
    #
    set fields [${:root} selectNodes "//form//*\[@name='$att'\]"]
    #:msg "found field = $fields xp=//*\[@name='$att'\]"

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
      # We handle now only INPUT types, but we have to differentiate
      # between different kinds of inputs.
      #
      set type [expr {[$field hasAttribute type] ? [$field getAttribute type] : "text"}]
      # the switch should be really different objects ad classes...., but that's HTML, anyhow.
      switch -- $type {
        checkbox {
          #:msg "$att: CHECKBOX value='$value', [$field hasAttribute checked], [$field hasAttribute value]"
          if {[$field hasAttribute value]} {
            set form_value [$field getAttribute value]
            #:msg "$att: form_value=$form_value, my value=$value"
            if {$form_value in $value} {
              $field setAttribute checked true
            } elseif {[$field hasAttribute checked]} {
              $field removeAttribute checked
            }
          } else {
            #:msg "$att: CHECKBOX entry has no value"
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
          #:msg "radio: compare input '$inputvalue' with '$value'"
          if {$inputvalue eq $value} {
            $field setAttribute checked true
          }
        }
        hidden -
        password -
        text {
          if { ![$field getAttribute rep "0"] } {
            $field setAttribute value $value
          }
        }
        default {:log "can't handle $type so far $att=$value"}
      }
    }
  }

  FormPage ad_instproc set_form_data {form_fields} {
    Store the instance attributes or default values in the form.
  } {
    ::xo::require_html_procs

    #array set __ia ${:instance_attributes}
    foreach f $form_fields {
      set att [$f name]
      # just handle fields of the form entry
      if {![info exists :__field_in_form($att)]} continue
      #:msg "set form_value to form-field $att [dict exists ${:instance_attributes} $att]"
      if {[dict exists ${:instance_attributes} $att]} {
        #:msg "my set_form_value from ia $att '[dict get ${:instance_attributes} $att]', external='[$f convert_to_external [dict get ${:instance_attributes} $att]]' f.value=[$f value]"
        :set_form_value $att [$f convert_to_external [dict get ${:instance_attributes} $att]]
      } else {
        # do we have a value in the form? If yes, keep it.
        set form_value [:get_form_value $att]
        #:msg "no instance attribute, set form_value $att '[$f value]' form_value=$form_value"
        if {$att eq ""} {
          # we have no instance attributes, use the default value from the form field
          :set_form_value $att [$f convert_to_external [$f value]]
        }
      }
    }
  }

  Page instproc mutual_overwrite_occurred {} {
    util_user_message -html \
        -message "[_ xowiki.User] <em>[::xo::get_user_name ${:modifying_user}]</em> [_ xowiki.has_modified_this_page]. \
   [_ xowiki.Please_open] <a href='[ns_quotehtml [::xo::cc url]]' target='_blank'>[_ xowiki.modified_page]</a> [_ xowiki.new_window_or_OK]."
    # return 1 to flag validation error, 0 to ignore this fact
    return 1
  }

  Page instproc validate=form_input_fields {form_fields} {
    #
    # This is the form-level validator, which might be used to perform
    # validation based on e.g. multiple depending formfields.  The
    # validator can be used to test inter-dependencies between
    # form-fields and should set the error fields of the reporting
    # form field(s) via
    #
    #   $f error_msg "some error...."
    #
    # This method can be refined by e.g. a workflow.
    #
    return 1
  }

  Page ad_instproc get_form_data {-field_names form_fields} {

    Get the values from the form and store it in the form fields and
    finally as instance attributes. If the field names are not
    specified, all form parameters are used.

  } {
    set validation_errors 0
    set category_ids [list]
    array set containers [list]
    set cc [::${:package_id} context]

    if {![info exists field_names]} {
      set field_names [$cc array names form_parameter]
      #:log "form-params=[$cc array get form_parameter]"
    }
    #:msg "fields $field_names // $form_fields"
    #foreach f $form_fields { :msg "... $f [$f name]" }
    #
    # We have a form and get all form input from the fields of the
    # from into form field objects.
    #
    foreach att $field_names {
      #:msg "getting att=$att"
      set processed($att) 1
      switch -glob -- $att {
        __category_* {
          set f [:lookup_form_field -name $att $form_fields]
          set value [$f value [$cc form_parameter $att]]
          foreach v $value {lappend category_ids $v}
        }
        __* {
          #
          # Other internal variables (like __object_name) are ignored
          #
        }
        _* {
          # instance attribute fields
          set f     [:lookup_form_field -name $att $form_fields]
          set value [$f value [string trim [$cc form_parameter $att]]]
          set varname [string range $att 1 end]
          #
          # Get rid of strange utf-8 characters hex C2AD (Firefox bug?)
          #
          #ns_log notice "FORM_DATA var=$varname, value='$value' s=$s"
          #if {$varname eq "text"} {regsub -all "­" $value "" value}
          #ns_log notice "FORM_DATA var=$varname, value='$value'"

          if {![string match "*.*" $att]} {
            set :$varname $value
          }
        }
        default {
          # user form content fields
          if {[regexp {^(.+)[.](tmpfile|content-type)} $att _ file field]} {
            set f [:lookup_form_field -name $file $form_fields]
            $f $field [string trim [$cc form_parameter $att]]
            #:msg "[$f name]: [list $f $field [string trim [$cc form_parameter $att]]]"
          } else {
            set f     [:lookup_form_field -name $att $form_fields]
            set value [$f value [string trim [$cc form_parameter $att]]]
            #:msg "value of $att ($f) = '$value' exists=[$cc exists_form_parameter $att]"
            if {![string match "*.*" $att]} {
              #
              # If the field is not a compound field, put the received
              # value into the instance attributes. The containerized
              # input values con compound fields are processed below.
              #
              dict set :instance_attributes $att $value
            }
            if {[$f exists is_category_field]} {
              foreach v $value {
                lappend category_ids $v
              }
            }
          }
        }
      }
      if {[string match "*.*" $att]} {
        lassign [split $att .] container component
        lappend containers($container) $component
      }
    }

    #
    # The first round was a processing based on the transmitted input
    # fields of the forms. Now we use the formfields to complete the
    # data and to validate it.
    #
    set leaf_components {}
    set container_fields {}
    foreach f $form_fields {
      if {[$f istype ::xowiki::formfield::CompoundField]} {
        #ns_log notice "TOP call leaf_components for [$f info class]"
        lappend leaf_components {*}[$f leaf_components]
        lappend container_fields $f
        set processed([$f name]) 1
      }
    }

    #ns_log notice "PROCESSED <[lsort [array names processed]]>"
    #ns_log notice "LEAF COMPONENTS <[lsort [lmap f $leaf_components {$f name}]]>"
    #ns_log notice "FORM_FIELDS [lsort [lmap f $form_fields {$f name}]]"
    #ns_log notice "CONTAINER   [lsort [array names containers]] + [lsort [lmap f $container_fields {$f name}]]"

    #
    # Certain HTML form field types are not transmitted by the browser
    # (e.g. unchecked checkboxes). Therefore, we have not processed
    # these fields above and have to do it now.
    #
    foreach f [concat $form_fields $leaf_components] {
      #:log "check processed $f [$f name] [info exists processed([$f name])] disabled=[$f is_disabled]"
      set att [$f name]

      if {![info exists processed($att)] && ![$f exists disabled]} {

        if {[$f exists is_repeat_template]} {
          continue
        }
        #:log  "==== form field $att [$f info class] not yet processed"

        switch -glob -- $att {
          __* {
            # other internal variables (like __object_name) are ignored
          }
          _* {
            # instance attribute fields
            set varname [string range $att 1 end]
            set default ""
            if {[info exists :$varname]} {set default [set :$varname]}
            set v [$f value_if_nothing_is_returned_from_form $default]
            #:log "===== value_if_nothing_is_returned_from_form [$f name] '$default' => '$v' (type=[$f info class])"
            set value [$f value $v]
            if {$v ne $default} {
              if {![string match "*.*" $att]} {set :$varname $value}
            }
          }
          default {
            # user form content fields
            set default ""
            #
            # The reason, why we set in the next line the default to
            # the old value is due to "show-solution" in the qti
            # use-case. Maybe one should alter this use-case to
            # simplify the semantics here.
            #
            if {[dict exists ${:instance_attributes} $att]} {
              set default [dict get ${:instance_attributes} $att]
            }
            set v [$f value_if_nothing_is_returned_from_form $default]
            #:log "===== value_if_nothing_is_returned_from_form [$f name] '$default' => '$v' (type=[$f info class])"

            set value [$f value $v]
            if {![string match "*.*" $att]} {
              dict set :instance_attributes $att $value
            }
          }
        }
      }
    }

    #
    # In the third iteration, combine the values from the components
    # of a container to the value of the container.
    #
    foreach f $container_fields {
      set name [$f name]
      #:log "container $name: compute value for [$f info class]"
      if {![$f is_disabled]} {
        dict set :instance_attributes $name [$f value]
        #:log "container $name: is set to '[dict get ${:instance_attributes} $name]'"
      } elseif {[dict exists ${:instance_attributes} $name]} {
        $f value [dict get ${:instance_attributes} $name]
      }
    }

    #
    # Finally run the validator on the toplevel fields
    #
    foreach f [concat $form_fields] {
      #
      # Run validator on every field
      #
      #:log "validate [$f name] ([$f info class]) with value '[$f value]'"
      set validation_error [$f validate [self]]
      if {$validation_error ne ""} {
        #:log "validation of $f [$f name] with value '[$f value]' returns '$validation_error'"
        $f error_msg $validation_error
        incr validation_errors
      }
    }

    #:msg "validation returns $validation_errors errors"
    set current_revision_id [$cc form_parameter __current_revision_id ""]
    if {$validation_errors == 0
        && $current_revision_id ne ""
        && $current_revision_id != ${:revision_id}
      } {
      set validation_errors [:mutual_overwrite_occurred]
      #:log "validation error due to mutual_overwrite current_revision_id <$current_revision_id> my ${:revision_id}"
    }

    if {[:validate=form_input_fields $form_fields] == 0} {
      incr validation_errors
      #:log "validation error due validate=form_input_fields"
    }

    if {$validation_errors == 0} {
      #
      # Postprocess based on form fields based on form-fields methods.
      #
      foreach f $form_fields {
        if {![$f is_disabled]} {
          $f convert_to_internal
        }
      }
    } else {
      :log validation_errors=$validation_errors
      #
      # There were validation errors.  Reset the value for form-fields
      # of type "file" to avoid confusions, since a file-name was
      # provided, but the file was not uploaded due to the validation
      # error. If we would not reset the value, the provided name
      # would cause an interpretation of an uploaded empty file. Maybe
      # a new method "reset-to-default" would be a good idea.
      #
      foreach f $form_fields {
        if {[$f type] eq "file"} {
          $f set value ""
        }
      }
    }

    #:log "=== get_form_data has validation_errors $validation_errors, instance_attributes: ${:instance_attributes}"

    return [list $validation_errors [lsort -unique $category_ids]]
  }

  FormPage instproc form_field_as_html {{-mode edit} before name form_fields} {
    set found 0
    foreach f $form_fields {
      if {[$f name] eq $name} {set found 1; break}
    }
    if {!$found} {
      set f [:create_raw_form_field -name $name -slot [:find_slot $name]]
    }

    #:msg "$found $name mode=$mode type=[$f set type] value=[$f value] disa=[$f exists disabled] display_field=[$f display_field]"
    if {$mode eq "edit" || [$f display_field]} {
      set html [$f asHTML]
    } else {
      set html @$name@
    }
    #:msg "RESULT: $name <$html>"
    return ${before}$html
  }

  Page instproc create_form_field {{-cr_field_spec ""} {-field_spec ""} field_name} {
    switch -glob -- $field_name {
      __* {}
      _* {
        set varname [string range $field_name 1 end]
        return [:create_raw_form_field -name $field_name \
                    -spec $cr_field_spec \
                    -slot [:find_slot $varname]]
      }
      default {
        return [:create_raw_form_field -name $field_name \
                    -spec $field_spec \
                    -slot [:find_slot $field_name]]
      }
    }
  }

  Page instproc create_form_fields {field_names} {
    set form_fields [:create_category_fields]
    foreach att $field_names {
      if {[string match "__*" $att]} continue
      lappend form_fields [:create_form_field $att]
    }
    return $form_fields
  }

  FormPage instproc create_form_field {{-cr_field_spec ""} {-field_spec ""} field_name} {
    if {$cr_field_spec eq ""} {set cr_field_spec [:get_short_spec @cr_fields]}
    if {$field_spec eq ""} {set field_spec [:get_short_spec @fields]}
    return [next -cr_field_spec $cr_field_spec -field_spec $field_spec $field_name]
  }

  FormPage instproc create_form_fields {field_names} {
    set form_fields   [:create_category_fields]
    foreach att $field_names {
      if {[string match "__*" $att]} continue

      if {[:form_field_exists $att]} {
        #ns_log notice "... found [set $key] for $key"
        lappend form_fields [:lookup_form_field -name $att {}]
      } else {
        lappend form_fields [:create_form_field \
                                 -cr_field_spec [:get_short_spec @cr_fields] \
                                 -field_spec [:get_short_spec @fields] $att]
      }
    }
    return $form_fields
  }

  FormPage instproc field_names {{-form ""}} {
    #
    # Ge the field-names mentioned in form (the provided form has
    # always highest precedence).
    #
    lassign [:field_names_from_form -form $form] form_vars needed_attributes
    #
    # In case, we have no form, get the field-names from the form
    # constraints.
    #
    if {[llength $needed_attributes] == 0} {
      set needed_attributes [:field_names_from_form_constraints]
    }
    #:log "form=$form, form_vars=$form_vars needed_attributes=$needed_attributes"

    array unset :__field_in_form
    array unset :__field_needed
    if {$form_vars} {
      foreach v $needed_attributes {
        set :__field_in_form($v) 1
      }
    }
    foreach v $needed_attributes {
      set :__field_needed($v) 1
    }

    #
    # Remove the fields already included in auto_fields form the needed_attributes.
    # The final list field_names determines the order of the fields in the form.
    #
    set auto_fields [list _name _page_order _title _creator _assignee _text _description _nls_language]
    set reduced_attributes $needed_attributes

    foreach f $auto_fields {
      set p [lsearch -exact $reduced_attributes $f]
      if {$p > -1} {
        set reduced_attributes [lreplace $reduced_attributes $p $p]
      }
    }
    #:msg reduced_attributes(after)=$reduced_attributes
    #:msg fields_from_form=[array names :__field_in_form]

    set field_names _name
    if {[::${:package_id} show_page_order]}  {
      lappend field_names _page_order
    }
    lappend field_names _title _creator _assignee
    foreach fn $reduced_attributes {
      lappend field_names $fn
    }
    foreach fn [list _text _description _nls_language] {
      lappend field_names $fn
    }
    #:msg final-field_names=$field_names
    return $field_names
  }

  Page instproc field_names {{-form ""}} {
    array set dont_modify {item_id 1 revision_id 1 object_id 1 object_title 1 page_id 1 name 1}
    set field_names [list]
    foreach field_name [[:info class] array names db_slot] {
      if {[info exists dont_modify($field_name)]} {
        continue
      }
      lappend field_names _$field_name
    }
    #:msg field_names=$field_names
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

  FormPage ad_instproc combine_data_and_form_field_default {is_new form_field data_value} {

    Combine the value of the form field (e.g. determined by the
    default) with the value in the instance attributes. This function
    decides, whether it should honor the data value or the form field
    value for e.g. rendering forms.

    @param is_new is this a new entry?
    @param form_field object id of the form field
    @param data_value the data from the instance attributes.
  } {
    set form_field_value [$form_field value]
    if {$is_new && $form_field_value ne "" && $data_value eq ""} {
      #
      # On fresh entries, take the default value in case the old
      # value is blank.
      #
    } else {
      #
      # Reset for form field value to the external
      # respresentation of the data value.
      #
      $form_field value [$form_field convert_to_external $data_value]
    }
    #ns_log notice "combine_data_and_form_field_default $is_new form_field [$form_field name] data_value <$data_value> final <[$form_field value]>"
  }


  FormPage instproc load_values_into_form_fields {form_fields} {
    set is_new [:is_new_entry ${:name}]

    foreach f $form_fields {
      set att [$f name]
      switch -glob $att {
        __* {}
        _* {
          set varname [string range $att 1 end]
          :combine_data_and_form_field_default $is_new $f [set :$varname]
        }
        default {
          if {[dict exists ${:instance_attributes} $att]} {
            :combine_data_and_form_field_default $is_new $f [dict get ${:instance_attributes} $att]
          }
        }
      }
    }
  }

  FormPage instproc render_form_action_buttons {{-CSSclass ""}} {
    set f [::xowiki::formfield::submit_button new -destroy_on_cleanup \
               -name __form_button_ok \
               -CSSclass $CSSclass]

    ::html::div [expr {[$f exists form_button_wrapper_CSSclass]
                       ? [list class [$f form_button_wrapper_CSSclass]]
                       : {} }] {
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
          && "::xowiki::formfield::omit" in [$f info mixin]} {
        # Never omit these fields, this would cause problems with
        # autonames and empty languages. Set these fields to hidden
        # instead.
        $f remove_omit
        $f class ::xowiki::formfield::hidden
        $f initialize
        #:msg "$f [$f name] [$f info class] [$f info mixin]"
      }
    }
  }

  Form set extraCSS ""
  Form proc requireFormCSS {} {
    #:msg requireFormCSS
    set css ${:extraCSS}
    if {$css ne ""} {
      ::xo::Page requireCSS $css
    }
  }

}
::xo::library source_dependent


#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
