::xo::library doc {
    XoWiki - dav procs.  Simple WebDAV implementation to access files in the wiki via the
    WebDAV protocol.

    @creation-date 2010-04-10
    @author Gustaf Neumann
    @cvs-id $Id$
}
package require XOTcl 2

namespace eval ::xowiki {

  #
  # Concrete storage manager
  #
  nx::Class create StorageManager=xowiki -superclass ::xo::StorageManager {
    :property {folder_form_name en:folder.form}
  }
  
  StorageManager=xowiki method get_folder_form {-package_id:required} {
    #
    # Get the xowiki form that represents the folder template
    #

    return [::xowiki::Weblog instantiate_forms -forms ${:folder_form_name} \
		-package_id $package_id]
  }

  StorageManager=xowiki method file_path_ref {-path:required} {
    set package_id  [${:dav} package_id]
    set parent_id   [$package_id folder_id]
    set package_url [$package_id package_url]
    set dav_prefix  [string trimright [${:dav} url] /]$package_url
    set rel_path    [string range $path [string length $package_url] end]
    #:log "##### rel_path '$rel_path' package_url '$package_url'"
    # provide default values for item props
    set r [dict create package_id $package_id parent_id $parent_id \
	       collection 0 item_id 0 href $dav_prefix$rel_path fname "" \
	       last_modified "" content_type "" content_length ""]

    set rpath [string trim $rel_path /]
    if {$rpath eq ""} {
      # the root folder of the package
      set folder_object [$package_id require_folder_object]
      return [dict replace $r item_id $parent_id href $dav_prefix$rpath \
		  creationdate [$folder_object set creation_date] \
		  last_modified [$folder_object last_modified] \
		  content_type "httpd/unix-directory" collection 1]
    }

    set elements [split $rpath /]
    # :log "##### elements: $elements"
    foreach elem $elements {
      set file_object [$package_id get_page_from_name -name file:$elem -parent_id $parent_id]
      #:log "##### lookup of file:$elem $parent_id => $file_object"
      if {$file_object ne ""} {
        #:log FO=[$file_object serialize]
        # The file_object does not contain a content_length. we could obtain it from the 
	# path, but the SQL query is more generic as it can deal with other types as well.
        set content_length [xo::dc get_value get_content_length \
               "select content_length from cr_revisions where revision_id = [$file_object revision_id]" \
                0]
        :log cl=$content_length-[$file_object full_file_name]-->[file size [$file_object full_file_name]]
        return [dict replace $r \
		    item_id [$file_object item_id] \
		    parent_id $parent_id \
		    fname file:$elem \
		    last_modified [$file_object last_modified] \
		    creationdate [$file_object set creation_date] \
		    content_type [$file_object mime_type] \
		    content_length $content_length]
      }
          
      set folder_page_object [$package_id get_page_from_name \
				  -assume_folder true -name $elem -parent_id $parent_id]
      :log "##### lookup of $elem $parent_id => $folder_page_object"
      if {$folder_page_object ne ""} {
        if {[$folder_page_object info class] ne "::xowiki::FormPage"} {
          return [dict replace $r fname $elem parent_id $parent_id]
        }
	set item_id [$folder_page_object item_id]
        set prev_parent_id $parent_id
        set parent_id [$folder_page_object item_id]
        set last_elem $elem
      } else {
        return [dict replace $r fname $elem parent_id $parent_id]
      }
    }
    
    return [dict replace $r \
		item_id $item_id parent_id $prev_parent_id fname $last_elem \
		collection 1 content_type "httpd/unix-directory"]
  }

  StorageManager=xowiki public method deliver_file {-path:required} {
    set r [:file_path_ref -path $path]
    if {[dict get $r item_id]} {
      set file_object [::xo::db::CrClass get_instance_from_db -item_id [dict get $r item_id]]
      if {![::[dict get $r package_id] check_permissions [dict get $r item_id] view]} {
	return [dict create success -1 msg "permission denied"]
      }
      # Calling download on a file or link should work this way.
      # Maybe we can extend this to photo.form instance or similar as well.
      $file_object set package_id [dict get $r package_id]
      [dict get $r package_id] reply_to_user [$file_object www-download]
      return [dict create success 1 msg "file $path scheduled for delivery"]
    } 
    return [dict create success 0 msg "file $path not found"]
  }

  StorageManager=xowiki public method create_folder {-path:required} {
    set r [:file_path_ref -path $path]
    set package_id [dict get $r package_id]

    set folder_form_id [:get_folder_form -package_id $package_id]
    if {![::$package_id check_permissions $package_id edit-new]} {
      return [dict create success -1 msg "folder create $path: permission denied"]
    }
    ::$package_id get_lang_and_name -name [dict get $r fname] lang strippedname

    set folder [$folder_form_id create_form_page_instance \
		    -name $strippedname \
		    -package_id $package_id \
		    -parent_id  [dict get $r parent_id] \
		    -publish_status "ready"]
    $folder set title $strippedname  
    $folder set creation_user [${:dav} user_id]
    $folder set creator [person::name -person_id [${:dav} user_id]]
    $folder save_new
    return [dict create success 1 msg "folder created $path"]
  }

  StorageManager=xowiki public method create_file {-path:required -contentfile:required} {
    set r [:file_path_ref -path $path]
    set item_id [dict get $r item_id]
    set package_id [dict get $r package_id]

    if {$item_id} {
      if {![::$package_id check_permissions $item_id edit]} {
	return [dict create success -1 msg "update $path: permission denied"]
      }
      # the file exists already, we add a new revision
      set file_object [::xo::db::CrClass get_instance_from_db -item_id $item_id]
      set save_method save
      set operation updated
      set success 2
    } else {
      if {![::$package_id check_permissions $package_id edit-new]} {
	return [dict create success -1 msg "create $path: permission denied"]
      }
      # create a fresh file
      set file_object [::xowiki::File new -destroy_on_cleanup \
                           -title [file tail $path] \
                           -name file:[dict get $r fname] \
                           -parent_id [dict get $r parent_id] \
                           -mime_type [::xowiki::guesstype [dict get $r fname]] \
                           -package_id $package_id \
                           -creation_user [${:dav} user_id]]
      set save_method save_new
      set operation created
      set success 1
    }

    $file_object set import_file $contentfile
    $file_object $save_method

    ::xo::xotcl_object_cache flush [$file_object set item_id]
    ::xo::xotcl_object_cache flush [$file_object set revision_id]

    return [dict create success $success msg "file $operation $path via $save_method"]
  }

  StorageManager=xowiki public method delete_file {-path:required} {
    set r [:file_path_ref -path $path]
    set item_id [dict get $r item_id]
    if {$item_id} {
      # We could check for deletion, but mac-os x likes to create tmp
      # files, where the create right has to be the same as the delete
      # right, otherwise operations are pending
      set package_id [dict get $r package_id]
      if {[::$package_id check_permissions $item_id write]} {
	$package_id www-delete -item_id $item_id \
	    -name [dict get $r fname] -parent_id [dict get $r parent_id]
	return [dict create success 1 msg "file [dict get $r fname] deleted"]
      } else {
	return [dict create success -1 msg "insufficient permissions to delete file $path"]
      }
    }
    return [dict create success 0 msg "file not found"]
  }

  StorageManager=xowiki public method copy_file {-path:required -destination:required} {
    set r [:file_path_ref -path $path]
    set item_id [dict get $r item_id]
    if {$item_id} {
      # maybe add "copy" permission
      if {[::[dict get $r package_id] check_permissions $item_id read]} {
	set dest [:file_path_ref -path $destination]
	:log "#### dest '$destination' => $dest"
	#if {![::[dict get $dest package_id] check_permissions [dict get $dest item_id]]} {
	#}
      } else {
	return [dict create success -3 msg "file copy: [dict get $r msg]"]
      }
      # Currently we have no cross package copy support. Maybe not needed.
      set file_object [::xo::db::CrClass get_instance_from_db -item_id $item_id]
      set r [:create_file -path $destination \
          -contentfile [$file_object full_file_name]]
      return [dict create success [dict get $r success] msg "file copy: [dict get $r msg]"]
    } else {
      return [dict create success 0 msg "File $path not found"]
    }
  }
  
  StorageManager=xowiki public method move_file {-path:required -destination:required} {
    set r [:file_path_ref -path $path]
    set item_id [dict get $r item_id]
    if {$item_id} {
      set file_object [::xo::db::CrClass get_instance_from_db -item_id $item_id]
      if {![$file_object istype ::xowiki::File]} {
	# this must be a folder
	set package_id [dict get $r package_id]
	if {![::$package_id check_permissions $package_id edit-new]} {
	  return [dict create success -1 msg "folder create $path: permission denied"]
	}
	set dest [split [string trimright $destination "/"] /]
	set name [lindex $dest end]
	set target [join [lrange $dest 0 end-1] /]
	#set b [:file_path_ref -path $target]
	#$file_object reparent -target_item_id [dict get $b item_id]
	$file_object rename -old_name [$file_object name] -new_name $name 
	$file_object set title $name
	$file_object save
	::xo::clusterwide ns_cache flush xotcl_object_cache $file_object
	return [dict create success 1 msg "folder moved"]
      }
    }
    # The RFC says that we have to create a new file and delete the
    # old one.
    set r [:copy_file -path $path -destination $destination]
    if {[dict get $r success] > 0} {
      :delete_file -path $path
    }
    return [dict create success [dict get $r success] msg "file rename: [dict get $r msg]"]
  }

  StorageManager=xowiki public method file_properties {
      -path:required 
      {-prefix ""} 
      {-depth 0}
    } {
    :log "##### file_properties path=$path prefix=$prefix depth=$depth"
    set item_props [:file_path_ref -path $path]
    set item_id [dict get $item_props item_id]
    #:log "##### item_props $item_props"

    if {!$item_id} {
      return [dict create success 0 msg "File $path not found" props ""]
    }

    set props [list]
    if {![dict get $item_props collection]} {
      #
      # Properties of a single file
      #
      return [dict create success 1 msg "Properties of $path" props [list $item_props]]

    } else {
      #
      # Properties of a container
      # -depth is ignored for now
      #
      # first, include the folder entry ....
      lappend props $item_props
      # ... and then the entries of the folder
      #
      if {$depth != 0} {
	#
	# Get the file entries
	#
	set package_id [dict get $item_props package_id]
	if {[string range $path end end] ne "/"} {append path /}
	set sql [::xowiki::File instance_select_query \
		     -folder_id $item_id \
		     -from_clause ", xowiki_page p" \
		     -where_clause "p.page_id = bt.revision_id" \
		     -select_attributes {content_length mime_type last_modified} \
		     -orderby ci.name]

	foreach entry [db_list_of_lists dbqd..instance_select $sql] {
	  lassign $entry \
	      file_item_id name publish_status object_type file_package_id \
	      content_length mime_type last_modified
	  if {![regexp {^file:(.*)$} $name _ fname]} continue

	  set href [dict get $item_props href]$fname
          # set href [ad_urlencode_path $href]
	  :log "..... FILE $href content_length $content_length"
	  lappend props [dict create collection 0 \
			     href $href \
			     last_modified $last_modified \
			     content_type $mime_type \
			     content_length $content_length]
	}
	
	#
	# Get the folder form entries
	#
	set folder_form_id [:get_folder_form -package_id $package_id]
	set folder_pages [::xowiki::FormPage get_form_entries \
			      -parent_id $item_id \
			      -base_item_ids $folder_form_id -form_fields "" \
			      -publish_status ready -package_id $package_id]
	#:log props=$props
	foreach folder [$folder_pages children] {
          set href [$package_id pretty_link \
                        -path_encode false \
                        -parent_id [$folder parent_id] \
                        [$folder name]]
	  set href [string trimright [${:dav} url] /]$href
          #set href [ad_urlencode_path $href]
	  :log "..... FOLDER [dict get $item_props href] "
	  lappend props [dict create collection 1 \
			     href $href \
			     last_modified [$folder last_modified] \
			     content_type "httpd/unix-directory" \
			     content_length ""]
	  :log after-lappend-props=$props
	}
      }

      return [dict create success 1 msg "Properties of $path" props $props]
    }
  }
 
}

#
# finally create handler objects
#
namespace eval ::xowiki {
  # create an instance of the xowiki storage manager
  StorageManager=xowiki create WebDav-stm-xowiki

  # create an instance of the the webdav handler for xowiki
  ::xo::WebDAV create ::xowiki::dav -stm ::xowiki::WebDav-stm-xowiki
}
::xo::library source_dependent 

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
