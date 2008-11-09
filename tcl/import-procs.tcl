ad_library {
    XoWiki - importer

    @creation-date 2008-04-25
    @author Gustaf Neumann
    @cvs-id $Id$
}


namespace eval ::xowiki {

  Class Importer -parameter {
    {added 0} {replaced 0} {updated 0} 
    {package_id} {folder_id} {user_id}
  }
  Importer instproc init {} {
    my set log ""
    my destroy_on_cleanup
  }
  Importer instproc report_lines {} {
    return "<table>[my set log]</table>"
  }
  Importer instproc report_line {obj operation} {
    set href [[$obj package_id] pretty_link [$obj name]]
    my append log "<tr><td>$operation</td><td><a href='$href'>[$obj name]</a></td></tr>\n"
  }
  Importer instproc report {} {
    my instvar added updated replaced
    return "$added objects newly inserted,\
	$updated objects updated, $replaced objects replaced<p>\
	[my report_lines]"
  }

  Importer instproc import {-object:required -replace -create_user_ids} {
    my instvar package_id user_id

    $object demarshall -parent_id [$object parent_id] -package_id $package_id \
	-creation_user $user_id -create_user_ids $create_user_ids
    set item_id [::xo::db::CrClass lookup -name [$object name] -parent_id [$object parent_id]]
    if {$item_id != 0} {
      if {$replace} { ;# we delete the original
	::xo::db::CrClass delete -item_id $item_id
	set item_id 0
        my report_line $object replaced
	my incr replaced
      } else {
	::xo::db::CrClass get_instance_from_db -item_id $item_id
	$item_id copy_content_vars -from_object $object
	$item_id save -use_given_publish_date [$item_id exists publish_date] \
            -modifying_user [$object set modifying_user]
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
  }

  Importer instproc import_all {-replace -objects:required {-create_user_ids 0}} {
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

        # Now, all requirements are met, parent-object and
        # child-object conditions are fulfilled. We have to map
        # page_template for PageInstances and parent_ids for child
        # objects to new IDs.
        #
        if {[$o istype ::xowiki::PageInstance]} {
          #my msg "importing [$o name] page_instance, map $template_name_key to $name_map($template_name_key)"
          $o page_template $name_map($template_name_key)
          #my msg "exists template? [my isobject [$o page_template]]"
        }

        if {[info exists item_ids($old_parent_id)]} {
          $o set parent_id $id_map($old_parent_id)
        } else {
          $o set parent_id [my folder_id]
        }

        # Everything is mapped, we can now do the import.
       
        my import \
            -object $o \
            -replace $replace \
            -create_user_ids $create_user_ids
        #my msg "import for $o done, name=[$o name]"

        # Maintain the maps and mark the item as done.

        if {$old_item_id ne ""} {
          set id_map($old_item_id) [$o item_id]
        }
        set name_map($old_parent_id-$old_name) [$o item_id]
        #my msg "setting name_map($old_parent_id-$old_name)=$name_map($old_parent_id-$old_name), o=$o, old_item_id=$old_item_id"
        #set ::__xowiki_import_object([$o item_id]) [self]
        
        unset todo($o)
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
  }


}