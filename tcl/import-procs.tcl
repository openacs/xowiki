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
    my destroy_on_cleanup
  }
  Importer instproc report {} {
    my instvar added updated replaced
    return "$added objects newly inserted, $updated objects updated, $replaced objects replaced<p>"
  }

  Importer instproc import {-object -replace -base_object -keep_user_ids} {
    my instvar package_id folder_id user_id
    $object demarshall -parent_id $folder_id -package_id $package_id -creation_user $user_id
    set item_id [::xo::db::CrClass lookup -name [$object name] -parent_id [$object parent_id]]
    if {$item_id != 0} {
      if {$replace} { ;# we delete the original
	::xo::db::CrClass delete -item_id $item_id
	set item_id 0
	my incr replaced
      } else {
	::xo::db::CrClass get_instance_from_db -item_id $item_id
	$item_id copy_content_vars -from_object $object
	if {[info exists base_object]} {$item_id set page_template $base_object}
	$item_id save -use_given_publish_date [$item_id exists publish_date] \
            -modifying_user [$object set modifying_user]
	#my msg "$item_id updated: [$object name]"
	my incr updated
      }
    }
    if {$item_id == 0} {
      if {[info exists base_object]} {$object set page_template $base_object}
      set n [$object save_new -use_given_publish_date [$object exists publish_date] \
            -creation_user [$object set modifying_user] \
            ]
      $object set item_id $n
      set item_id $object
      #my msg "$object added: [$object name]"
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

  Importer instproc import_all {-replace -objects:required {-keep_user_ids 0}} {
    my instvar package_id folder_id
    set todo [list]
    foreach o $objects {
      # page instances have references to page templates, add these first
      if {[$o istype ::xowiki::PageInstance]} {
        lappend todo $o
        continue
      }
      my log "importing (1st round) $o [$o name] [$o info class]"
      my import -object $o -replace $replace -keep_user_ids $keep_user_ids
    }

    while {[llength $todo] > 0} {
      #my log "importing (2nd round) todo=$todo"
      set c 0
      set found 0
      foreach o $todo {
	set old_template_id [$o set page_template]
	set old_template_name [::$old_template_id set name] 
	if {[lsearch $todo ::$old_template_id] > -1} {
	  #my msg "*** delay import of $o ($old_template_id not processed yet)"
	  incr c
	  continue
	}
	set template_id [::xo::db::CrClass lookup -name $old_template_name -parent_id $folder_id ]
        if {$template_id == 0} {
          #my msg "delay import of $o ($old_template_id [$old_template_id set name] missing)"
          incr c
	  continue
        }
	#my msg "can import $o ($old_template_id [$old_template_id set name] not missing)"
	set todo [lreplace $todo $c $c]
	set found 1
	break
      }
      if {$found == 0} {
        my log "can't resolve dependencies in $todo"
        break
      }
      my log "importing (2nd round) process $o, todo=$todo"
      my import -object $o -replace $replace -base_object $template_id -keep_user_ids $keep_user_ids
    }
    foreach o $objects {$o destroy}
  }


}