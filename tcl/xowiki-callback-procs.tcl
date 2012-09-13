::xo::library doc {
    XoWiki - Callback procs

    @creation-date 2006-08-08
    @author Gustaf Neumann
    @cvs-id $Id$
}

namespace eval ::xowiki {

  ad_proc -private ::xowiki::after-install {} {
    ::xowiki::sc::register_implementations
    ::xowiki::notifications-install
  }

  ad_proc -private ::xowiki::before-uninstall {} {
    ::xowiki::sc::unregister_implementations
    ::xowiki::notifications-uninstall

    # Unregister all types from all folders 
    ::xowiki::Page folder_type_unregister_all 

    # Delete object types
    foreach type [::xowiki::Page object_types -subtypes_first true] {
      ::xo::db::sql::content_type drop_type -content_type $type \
          -drop_children_p t -drop_table_p t -drop_objects_p t
    }
  }

  ad_proc -public ::xowiki::before-uninstantiate {
    {-package_id:required}
  } {
    Callback to be called whenever a package instance is deleted.
    
    @author Gustaf Neumann
  } {
    ns_log notice "Executing before-uninstantiate"
    ::xowiki::delete_gc_messages -package_id $package_id
    set root_folder_id [::xo::db::CrClass lookup -name "xowiki: $package_id" -parent_id -100]
    if {[db_0or1row is_transformed_folder "select 1 from cr_folders where folder_id = $root_folder_id"]} {
      ::xo::db::sql::content_folder delete -folder_id $root_folder_id -cascade_p 1
    } else {
      ::xo::db::sql::content_item delete -item_id $root_folder_id
    }
    ns_log notice "          before-uninstantiate DONE"
  }


  ad_proc -public ::xowiki::delete_gc_messages {
    {-package_id:required}
  } {
    Deletes the messages of general comments to allow to
    uninstantiate the package without violating constraints.
    
    @author Gustaf Neumann
  } {
    set comment_ids [db_list get_comments "
      select g.comment_id
      from general_comments g, cr_items i,acs_objects o
      where i.item_id = g.object_id
      and o.object_id = i.item_id
      and o.package_id = $package_id"]
    foreach comment_id $comment_ids {
      ::xo::db::sql::acs_message delete -message_id $comment_id
    }
  }


  #
  # upgrade logic
  #

  ad_proc ::xowiki::upgrade_callback {
    {-from_version_name:required}
    {-to_version_name:required}
  } {

    Callback for upgrading

    @author Gustaf Neumann (neumann@wu-wien.ac.at)
  } {
    ns_log notice "-- UPGRADE $from_version_name -> $to_version_name"

    set upgrade_file [acs_root_dir]/packages/xowiki/tcl/upgrade/upgrade.tcl
    #
    # The upgrade file contains the upgrade proc of the following form:
    #
    #   proc __upgrade {from_version_name to_version_name} {...}
    #
    source $upgrade_file
    __upgrade $from_version_name $to_version_name

    # The upgrade is done, there is no need to keep this proc in
    # memory around, so we can delete it.
    rename __upgrade ""
  }
}
::xo::library source_dependent 

