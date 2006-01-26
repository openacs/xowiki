set msg ""
ad_form \
    -name upload_form \
    -mode edit \
    -export {fs_package_id folder_id orderby selector_type file_types} \
    -html { enctype multipart/form-data } \
    -form {
      {upload_file:file(file) {html {size 30}} }
      {ok_btn:text(submit) {label "[_ acs-templating.HTMLArea_SelectUploadBtn]"}
      }
    } \
    -on_submit {
      # check file name
      if {$upload_file eq ""} {
	template::form::set_error upload_form upload_file \
	    [_ acs-templating.HTMLArea_SpecifyUploadFilename]
	break
      }

      set file_name [template::util::file::get_property filename $upload_file]
      set upload_tmpfile [template::util::file::get_property tmp_filename $upload_file]
      set mime_type [template::util::file::get_property mime_type $upload_file]
      set f [open $upload_tmpfile]; set content [read $f]; close $f
      if {[catch {eval $content} error]} {
	append  msg "Error: $error"
      } else {

	set replace 0 ;# 1 is overwrite mode
	set object_type ::xowiki::Page
	set folder_id [$object_type require_folder -name xowiki]

	append  msg "objects=[$object_type allinstances]<p>"
	set added 0
	foreach o [$object_type allinstances] {
	  $o set parent_id $folder_id
	  $o set package_id [ad_conn package_id]
	  # page instances have references to page templates, add these first
	  if {[$o istype ::xowiki::PageInstance]} continue
	  set item [CrItem lookup -title [$o set title] -parent_id $folder_id]
	  if {$item != 0 && $replace} { ;# we delete the original 
	    ::Generic::CrItem delete -item_id $item 
	    set item 0
	  }
	  if {$item == 0} {
	    $o save_new
	    incr added
	  }
	}

	foreach o [$object_type allinstances] {
	  if {[$o istype ::xowiki::PageInstance]} {
	    db_transaction {
	      set item [CrItem lookup -title [$o set title] -parent_id $folder_id]
	      if {$item != 0 && $replace} { ;# we delete the original
		::Generic::CrItem delete -item_id $item 
		set item 0
	      }
	      if {$item == 0} {  ;# the item does not exist -> update reference and save
		set old_template_id [$o set page_template]
		set template [CrItem lookup \
				  -title [$old_template_id set title] \
				  -parent_id $folder_id]
		$o set page_template $template
		$o save_new
		incr added
	      }
	    }
	  }
	  $o destroy
	}
	append msg "$added objects inserted<p>"
      }
    }


set page_title "Import XoWiki Pages"
set context {}
ad_return_template
