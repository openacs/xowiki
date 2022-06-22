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
    ns_log notice "Executing ::xowiki::before-uninstall"
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

  ad_proc -private ::xowiki::delete_instances_of_siblings {
    {-parent_id:required}
  } {
    It is possible to have formpages (e.g. workflow instances)
    depending on other formpages (e.g. workflows) stored under the
    same parent.

    content_item.delete stored procedure does respect parent->child
    relationship and will delete children before their parent,
    however, it won't honor the template->instance relationship. If
    template and instance belong to the same folder, the order in
    which they will be deleted is unspecified, so we might try to
    delete a workflow before we have deleted its instances.

    Since change
    https://cvs.openacs.org/changelog/OpenACS?cs=oacs-5-10%3Agustafn%3A20220613165033,
    deleting a template before its instances will throw an error. This
    is better than before the change, where zombie items would be
    silently left in the database.

    We address the cornercase of template and instance under the same
    parent by deleting such formpages before we delete all the rest.
  } {
    #
    # FormPages where the template is in their same folder, over the
    # whole tree with root in parent_id
    #
    foreach page_instance_id [::xo::dc list get_sibling_instances {
      with recursive parents as
      (
       select item_id from cr_items
       where item_id = :parent_id

       union

       select i.item_id
       from cr_items i,
            parents p
       where i.parent_id = p.item_id
       )
        select i.item_id
          from xowiki_form_instance_item_index i,
               xowiki_form_instance_item_index t,
               parents p
         where i.page_template = t.item_id
           and i.parent_id = t.parent_id
           and i.parent_id = p.item_id
    }] {
      ns_log notice "DELETING $page_instance_id"
      ::xo::db::sql::content_item delete -item_id $page_instance_id
    }
  }

  ad_proc -public ::xowiki::before-uninstantiate {
    {-package_id:required}
  } {
    Callback to be called whenever a package instance is deleted.

    @author Gustaf Neumann
  } {
    ns_log notice "Executing before-uninstantiate"
    # Delete the messages of general comments to allow one to
    # uninstantiate the package without violating constraints.
    general_comments_delete_messages -package_id $package_id
    set root_folder_id [::xo::db::CrClass lookup -name "xowiki: $package_id" -parent_id -100]
    if {$root_folder_id ne "0"} {

      # Cleanup instances of templates located in the same folder
      ::xowiki::delete_instances_of_siblings -parent_id $root_folder_id

      # we deal with a correctly installed package
      if {[::xo::dc 0or1row is_transformed_folder {
        select 1 from cr_folders where folder_id = :root_folder_id}
          ]} {
        ::xo::db::sql::content_folder delete -folder_id $root_folder_id -cascade_p 1
      } else {
        ::xo::db::sql::content_item delete -item_id $root_folder_id
      }
    }

    set instance_name [apm_instance_name_from_id $package_id]

    ::xo::xotcl_package_cache flush package_id-$instance_name
    ::xo::xotcl_package_cache flush package_key-$package_id
    ::xo::xotcl_package_cache flush root_folder-$package_id
    ::xo::xotcl_object_type_cache flush -partition_key -100 -100-$instance_name

    ns_log notice "before-uninstantiate DONE"
  }

  #
  # upgrade logic
  #

  ad_proc -private ::xowiki::upgrade_callback {
    {-from_version_name:required}
    {-to_version_name:required}
  } {

    Callback for upgrading

    @author Gustaf Neumann (neumann@wu-wien.ac.at)
  } {
    ns_log notice "-- UPGRADE $from_version_name -> $to_version_name"

    set upgrade_file $::acs::rootdir/packages/xowiki/tcl/upgrade/upgrade.tcl
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

  ad_proc -public -callback subsite::parameter_changed -impl xowiki {
    -package_id:required
    -parameter:required
    -value:required
  } {
    Implementation of subsite::parameter_changed for xowiki parameters.

    @param package_id the package_id of the package the parameter was changed for
    @param parameter  the parameter name
    @param value      the new value
  } {
    if {[::xowiki::Package is_xowiki_p $package_id]} {
      if {$parameter eq "use_hstore" && $value eq 1} {
        # hstore has been activated: make sure instance attributes are
        # persisted in there
        ::xowiki::hstore::update_hstore $package_id
      }
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
