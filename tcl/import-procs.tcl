::xo::library doc {
    XoWiki - importer

    @creation-date 2008-04-25
    @author Gustaf Neumann
    @cvs-id $Id$
}


namespace eval ::xowiki {

  Class Importer -parameter {
    {added 0} {replaced 0} {updated 0} {inherited 0}
    {package_id} {parent_id} {user_id}
  }
  Importer instproc init {} {
    my set log ""
    my destroy_on_cleanup
  }
  Importer instproc report_lines {} {
    return "<table>[my set log]</table>"
  }
  Importer instproc report_line {obj operation} {
    set href [$obj pretty_link]
    set name [[$obj package_id] external_name -parent_id [$obj parent_id] [$obj name]]
    my append log "<tr><td>$operation</td><td><a href='$href'>$name</a></td></tr>\n"
  }
  Importer instproc report {} {
    my instvar added updated replaced inherited
    return "$added objects newly inserted,\
	$updated objects updated, $replaced objects replaced, $inherited inherited (update ignored)<p>\
	[my report_lines]"
  }

  Importer instproc import {-object:required -replace -create_user_ids} {
    #
    # Import a single object. In essence, this method demarshalls a
    # single object and inserts it (or updates it) in the database. It
    # takes as well care about categories.
    # 
    my instvar package_id user_id

    $object demarshall -parent_id [$object parent_id] -package_id $package_id \
	-creation_user $user_id -create_user_ids $create_user_ids
    set item_id [::xo::db::CrClass lookup -name [$object name] -parent_id [$object parent_id]]
    #my msg "lookup of [$object name] parent [$object parent_id] => $item_id"
    if {$item_id != 0} {
      if {$replace} { ;# we delete the original
	::xo::db::CrClass delete -item_id $item_id
	set item_id 0
        my report_line $object replaced
	my incr replaced
      } else {
	#my msg "$item_id update: [$object name]"
	::xo::db::CrClass get_instance_from_db -item_id $item_id
	$item_id copy_content_vars -from_object $object
	$item_id save -use_given_publish_date [$item_id exists publish_date] \
            -modifying_user [$object set modifying_user]
	#my log "$item_id saved"
        $object set item_id [$item_id item_id]
	#my msg "$item_id updated: [$object name]"
        my report_line $item_id updated
	my incr updated
      }
    }
    if {$item_id == 0} {
      set n [$object save_new -use_given_publish_date [$object exists publish_date] \
            -creation_user [$object set modifying_user] ]
      $object set item_id $n
      set item_id $object
      #my msg "$object added: [$object name]"
      my report_line $object added
      my incr added
    }
    #
    # The method demarshall might set the mapped __category_ids in $object.
    # Insert these into the category object map
    #
    if {[$object exists __category_ids]} {
      #my msg "$item_id map_categories [object set __category_ids] // [$item_id item_id]"
      $item_id map_categories [$object set __category_ids]
    }

    $package_id flush_references -item_id [$object item_id] -name [$object name]
  }

  Importer instproc import_all {-replace -objects:required {-create_user_ids 0} {-keep_inherited 1}} {
    #
    # Import a series of objects. This method takes care especially
    # about dependencies of objects, which is reflected by the order
    # of object-imports.
    #
    #
    # Extact information from objects to be imported, that might be
    # changed later in the objects.
    #
    foreach o $objects {
      #
      # Remember old item_ids and old_names for pages with
      # item_ids. Only these can have parents (page_templates) or
      # child_objects
      #
      if {[$o exists item_id]}   {
        set item_ids([$o item_id]) $o
        set old_names([$o item_id]) [$o name]
      } {
        $o item_id ""
      }
      # Remember old parent_ids for name-mapping, names are
      # significant per parent_id.
      if {[$o exists parent_id]} {
        set parent_ids([$o item_id]) [$o parent_id]
      } {
        $o parent_id ""
      }
      set todo($o) 1
      
      #
      # Handle import of categories in the first pass
      #
      if {[$o exists __map_command]} {
        $o package_id [my package_id]
        $o eval [$o set __map_command]
      }
      # FIXME remove?
      #if {[$o exists __category_map]} {
      #  array set ::__category_map [$o set __category_map]
      #}
    }
    #my msg "item_ids=[array names item_ids], parent_ids=[array names parent_ids]"

    #
    # Make a fix-point iteration during import. Do only import, when
    # all prerequirement pages are already loaded.
    #
    while {[llength [array names todo]] > 0} {
      set new 0
      foreach o [array names todo] {
        #my msg "work on $o [$o info class] [$o name]"

        set old_name      [$o name]
        set old_item_id   [$o item_id]
        set old_parent_id [$o parent_id]

        # page instances have references to page templates, add the templates first
        if {[$o istype ::xowiki::PageInstance]} {
          set old_template_id [$o page_template]
          if {![info exists old_names($old_template_id)]} {
            set new 0
            my msg "need name for $old_template_id. Maybe item_ids for PageTemplate missing?"
            break
          }
          
          set template_name_key $parent_ids($old_template_id)-$old_names($old_template_id)
          if {![info exists name_map($template_name_key)]} {
            #my msg "... delay import of $o (no object with name $template_name_key) imported"
            continue
          }
          #my msg "we found entry for name_map($template_name_key) = $name_map($template_name_key)"
        }

        if {[info exists item_ids($old_parent_id)]} {
          # we have a child object
          if {![info exists id_map($old_parent_id)]} {
            #my msg "... delay import of $o (map of parent_id $old_parent_id missing)"
            continue
          }
        }

	set need_to_import 1
	#
	# If the page was implicitely added (due to being a
	# page_template of an exported page), and a page (e.g. a form
	# or a workflow) with the same name is inherited to the
	# target, don't materialize the inherited page.
	#
	if {$keep_inherited 
	    && [$o exists __export_reason] 
	    && [$o set __export_reason] eq "implicit_page_template"} {
	  #my msg "importing implicit_page_template [$o name]"
	  $o unset __export_reason
	  set page [[my package_id] get_page_from_item_ref \
			-allow_cross_package_item_refs false \
			-use_package_path true \
			-use_site_wide_pages true \
			-use_prototype_pages false \
			[$o name] \
		       ]
	  if {$page ne "" && [$page physical_parent_id] ne [$page parent_id]} {
	    #my msg "page [$o name] is inherited in folder [my parent_id]"
	    my incr inherited
	    unset todo($o)
	    set o $page
	    set need_to_import 0
	  }
	}

	if {$need_to_import} {
	  # Now, all requirements are met, parent-object and
	  # child-object conditions are fulfilled. We have to map
	  # page_template for PageInstances and parent_ids for child
	  # objects to new IDs.
	  #
	  if {[$o istype ::xowiki::PageInstance]} {
	    #my msg "importing [$o name] page_instance, map $template_name_key to $name_map($template_name_key)"
	    $o page_template $name_map($template_name_key)
	    #my msg "exists template? [my isobject [$o page_template]]"
	    if {![my isobject [$o page_template]]} {
	      ::xo::db::CrClass get_instance_from_db -item_id [$o page_template]
	      my msg "[my isobject [$o page_template]] loaded"
	    }
	  }
	  
	  if {[info exists item_ids($old_parent_id)]} {
	    $o set parent_id $id_map($old_parent_id)
	  } else {
	    $o set parent_id [my parent_id]
	  }
	  
	  # Everything is mapped, we can now do the import.
	  
	  #my msg "start import for $o, name=[$o name]"
	  my import \
	      -object $o \
	      -replace $replace \
	      -create_user_ids $create_user_ids
	  #my msg "import for $o done, name=[$o name]"

	  unset todo($o)
	}

	#
        # Maintain the maps and iterate
	#
        if {$old_item_id ne ""} {
          set id_map($old_item_id) [$o item_id]
        }
        set name_map($old_parent_id-$old_name) [$o item_id]
        #my msg "setting name_map($old_parent_id-$old_name)=$name_map($old_parent_id-$old_name), o=$o, old_item_id=$old_item_id"
        
        set new 1
      }
      if {$new == 0} {
        my msg "could not import [array names todo]"
        break
      }
    }
    #my msg "final name_map=[array get name_map], id_map=[array get id_map]"

    #
    # final cleanup
    #
    foreach o $objects {$o destroy}

    [my package_id] flush_page_fragment_cache
  }

  #
  # A small helper for exporting objects
  #

  Object create exporter 
  exporter proc include_needed_objects {item_ids} {
    #
    # Load the objects
    #
    foreach item_id $item_ids {
      if {[::xo::db::CrClass get_instance_from_db -item_id $item_id] eq ""} {
	my log "Warning: cannot fetch item $item_id for exporting"
      } else {
	set items($item_id) 1
      }
    }

    #
    # In a second step, include the objects which should be exported implicitly
    #
    while {1} {
      set new 0
      ns_log notice "--export works on [array names items]"
      foreach item_id [array names items] {
	#
	# We flag the reason, why the implicitely included elements were
	# included. If the target can resolve already such items
	# (e.g. forms), we might not have to materialize these finally.
	#
	# For PageInstances (or its subtypes), include the parent-objects as well
	#
	if {[$item_id istype ::xowiki::PageInstance]} {
	  set template_id [$item_id page_template]
	  if {![info exists items($template_id)]} {
	    ns_log notice "--export including parent-object $template_id [$template_id name]"
	    set items($template_id) 1
	    ::xo::db::CrClass get_instance_from_db -item_id $template_id
	    set new 1
	    $template_id set __export_reason implicit_page_template
	  }
	}
	#
	# check for child objects of the item
	#
	set sql [[$item_id info class] instance_select_query -folder_id $item_id -with_subtypes true]
	db_foreach instance_select $sql {
	  if {![info exists items($item_id)]} {
	    ::xo::db::CrClass get_instance_from_db -item_id $item_id
	    ns_log notice "--export including child $item_id [$item_id name]"
	    set items($item_id) 1 
	    set new 1
	    $template_id set __export_reason implicit_child_page
	  }
	}
      }
      if {!$new} break
    }
    return [array names items]
  }

  exporter proc marshall_all {item_ids} {
    set content ""
    foreach item_id $item_ids {
      if {[catch {set obj [$item_id marshall]} errorMsg]} {
	ns_log error "Error while exporting $item_id [$item_id name]\n$errorMsg\n$::errorInfo"
      } else {
	append content $obj\n
      }
    }
    return $content
  }

  exporter proc export {item_ids} {
    #
    # include implictely needed objects, instantiate the objects.
    #
    set item_ids [my include_needed_objects $item_ids]
    #
    # stream the objects via ns_write
    #
    ns_set put [ns_conn outputheaders] "Content-Type" "text/plain"
    ns_set put [ns_conn outputheaders] "Content-Disposition" "attachment;filename=export.xotcl"
    ReturnHeaders 
    
    foreach item_id $item_ids {
      ns_log notice "--exporting $item_id [$item_id name]"
      if {[catch {set obj [$item_id marshall]} errorMsg]} {
	ns_log error "Error while exporting $item_id [$item_id name]\n$errorMsg\n$::errorInfo"
      } else {
	ns_write "$obj\n" 
      }
    }
  }


  #
  # Simple archive file manager
  #
  # The Archive manages supports importing .zip files and .tar.gz
  # files as ::xowiki::File into xowiki folders.
  #
  ::xotcl::Class create ArchiveFile -parameter {
    file
    name
    parent_id
  }
  ArchiveFile instproc init {} {
    my destroy_on_cleanup
    ::xo::db::CrClass get_instance_from_db -item_id [my parent_id]
    my set tmpdir [ns_tmpnam]
    file mkdir [my set tmpdir]
  }
  ArchiveFile instproc delete {} {
    file delete -force [my set tmpdir]
    next
  }
  ArchiveFile instproc unpack {} {
    my instvar name file
    set success 0
    switch [::xowiki::guesstype $name] {
      application/x-zip-compressed {
	set zipcmd [::util::which unzip]
	#my msg "zip = $zipcmd, tempdir = [my set tmpdir]"
	exec $zipcmd $file -d [my set tmpdir]
	my import -dir [my set tmpdir] -parent_id [my parent_id]
	set success 1
      }
      application/x-compressed {
	if {[string match *tar.gz $name]} {
	  set cmd [::util::which tar]
	  exec $cmd -xzf $file -C [my set tmpdir]
	  my import -dir [my set tmpdir] -parent_id [my parent_id]
	  set success 1
	} else {
	  my msg "unknown compressed file type $name"
	}
      }
      default {my msg "type [::xowiki::guesstype $name] of $name unknown"}
    }
    my msg success=$success
    return $success
  }
  ArchiveFile instproc import {-dir -parent_id} {
    set package_id [$parent_id package_id]

    foreach tmpfile [glob -nocomplain -directory $dir *] {
      #my msg "work on $tmpfile [::file isdirectory $tmpfile]"
      set file_name [::file tail $tmpfile]
      if {[::file isdirectory $tmpfile]} {
	# ignore mac os x resource fork directories
	if {[string match *__MACOSX $tmpfile]} continue
	set folder_object [$package_id get_page_from_name -assume_folder true \
			       -name $file_name -parent_id $parent_id]
	if {$folder_object ne ""} {
	  # if the folder exists already, we have nothing to do
	} else {
	  # we create a new folder ...
	  set folder_form_id [::xowiki::Weblog instantiate_forms -forms en:folder.form \
				  -package_id $package_id]
	  set folder_object [FormPage new -destroy_on_cleanup \
				 -title $file_name \
				 -name $file_name \
				 -package_id $package_id \
				 -parent_id $parent_id \
				 -nls_language en_US \
				 -instance_attributes {} \
				 -page_template $folder_form_id]
	  $folder_object save_new
	  # ..... and refetch it under its canonical name
	  ::xo::db::CrClass get_instance_from_db -item_id [$folder_object item_id]
	}
	my import -dir $tmpfile -parent_id [$folder_object item_id]
      } else {
	set mime_type [::xowiki::guesstype $file_name]
	set file_object [$package_id get_page_from_name -name file:$file_name -parent_id $parent_id]
	if {$file_object ne ""} {
	  my msg "file $file_name exists already"
	  # file entry exists already, create a new revision
	  $file_object set import_file $tmpfile
	  $file_object set mime_type $mime_type
	  $file_object set title $file_name
	  $file_object save
	} else {
	  my msg "file $file_name created new"
	  set file_object [::xowiki::File new -destroy_on_cleanup \
			       -title $file_name \
			       -name file:$file_name \
			       -parent_id $parent_id \
			       -mime_type $mime_type \
			       -package_id $package_id \
			       -creation_user [::xo::cc user_id] ]
	  $file_object set import_file $tmpfile
	  $file_object save_new
	}
      }
    }
  }
}
::xo::library source_dependent 

