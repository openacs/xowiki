ad_library {
    XoWiki - Notification procs

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

      # Delete object types
      
      content::type::delete -content_type ::xowiki::Object -drop_children_p 1 -drop_table_p 1 -drop_objects_p 1
      content::type::delete -content_type ::xowiki::PageInstance -drop_children_p 1 -drop_table_p 1 -drop_objects_p 1
      content::type::delete -content_type ::xowiki::PageTemplate -drop_children_p 1 -drop_table_p 1 -drop_objects_p 1
      content::type::delete -content_type ::xowiki::File -drop_children_p 1 -drop_table_p 1 -drop_objects_p 1
      content::type::delete -content_type ::xowiki::PlainPage -drop_children_p 1 -drop_table_p 1 -drop_objects_p 1
      content::type::delete -content_type ::xowiki::Page -drop_children_p 1 -drop_table_p 1 -drop_objects_p 1
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

    if {$to_version_name eq "0.13"} {
      ns_log notice "-- upgrading to 0.13"
      set package_id [::Generic::package_id_from_package_key xowiki]
      set folder_id  [::xowiki::Page require_folder \
                         -package_id $package_id \
                         -name xowiki]
      set r [::CrWikiPage instantiate_all -folder_id $folder_id]
      db_transaction {
        array set map {
          ::CrWikiPage      ::xowiki::Page
          ::CrWikiPlainPage ::xowiki::PlainPage
          ::PageTemplate    ::xowiki::PageTemplate
          ::PageInstance    ::xowiki::PageInstance
        }
        foreach e [$r children] {
          set oldClass [$e info class]
          if {[info exists map($oldClass)]} {
            set newClass $map($oldClass)
            ns_log notice "-- old class [$e info class] -> $newClass, \
                        fetching [$e set item_id] "
            [$e info class] fetch_object -object $e -item_id [$e set item_id]
            set oldtitle [$e set title]
            $e append title " (old)"
            $e save
            $e class $newClass
            $e set title $oldtitle
            $e set name $oldtitle
            $e save_new
          } else {
            ns_log notice "-- no new class for $oldClass"
          }
        }       
      }
    }

    if {[apm_version_names_compare $from_version_name "0.19"] == -1 &&
        [apm_version_names_compare $to_version_name "0.19"] > -1} {
      ns_log notice "-- upgrading to 0.19"
      ::xowiki::sc::register_implementations
    }

    if {[apm_version_names_compare $from_version_name "0.21"] == -1 &&
        [apm_version_names_compare $to_version_name "0.21"] > -1} {
      ns_log notice "-- upgrading to 0.21"
      ::xo::db::CONTENT_TYPE CREATE_ATTRIBUTE {
        {content_type ::xowiki::Page} {attribute_name page_title} {datatype text}
        {pretty_name "Page Title"} {column_spec text}
      }
      ::xo::db::CONTENT_TYPE CREATE_ATTRIBUTE {
        {content_type ::xowiki::Page} {attribute_name creator} {datatype text}
        {pretty_name "Creator"} {column_spec text}
      }
      ::xowiki::update_views
    }

    if {[apm_version_names_compare $from_version_name "0.22"] == -1 &&
        [apm_version_names_compare $to_version_name "0.22"] > -1} {
      ns_log notice "-- upgrading to 0.22"
      set folder_ids [list]
      set package_ids [list]
      foreach package_id [::xowiki::Package instances] {
        set folder_id [db_list get_folder_id "select f.folder_id from cr_items c, cr_folders f \
                where c.name = 'xowiki: $package_id' and c.item_id = f.folder_id"]
        if {$folder_id ne ""} {
          db_dml update_package_id {update cr_folders set package_id = :package_id
            where folder_id = :folder_id}
          lappend folder_ids $folder_id
          lappend package_ids $package_id
        }
      }
      foreach f $folder_ids p $package_ids {
        db_dml update_context_ids "update acs_objects set context_id = $p where object_id = $f"
      }
    }

    if {[apm_version_names_compare $from_version_name "0.25"] == -1 &&
        [apm_version_names_compare $to_version_name "0.25"] > -1} {
      ns_log notice "-- upgrading to 0.25"
      acs_sc::impl::new_from_spec -spec {
        name "::xowiki::PageInstance"
        aliases {
          datasource ::xowiki::datasource
          url ::xowiki::url
        }
        contract_name FtsContentProvider
        owner xowiki
      }
#      foreach pkgid [::xowiki::Package instances] {
#       ::xowiki::Page reindex -package_id $pkgid
#       }
    }

    if {[apm_version_names_compare $from_version_name "0.27"] == -1 &&
        [apm_version_names_compare $to_version_name "0.27"] > -1} {
      ns_log notice "-- upgrading to 0.27"
      db_dml copy_page_title_into_title \
          "update cr_revisions set title = p.page_title from xowiki_page p \
                where page_title != '' and revision_id = p.page_id"

      db_list delete_deprecated_types_from_ancient_versions \
        [::xo::db::map "select content_item__delete(i.item_id) from cr_items i \
                where content_type in ('CrWikiPage', 'CrWikiPlainPage', \
                'PageInstance', 'PageTemplate','CrNote', 'CrSubNote')"]
    }

    if {[apm_version_names_compare $from_version_name "0.30"] == -1 &&
        [apm_version_names_compare $to_version_name "0.30"] > -1} {
      ns_log notice "-- upgrading to 0.30"
      # delete orphan cr revisions, created automatically by content_item
      # new, when e.g. a title is specified....
      foreach class {::xowiki::Page ::xowiki::PlainPage ::xowiki::Object
        ::xowiki::PageTemplate ::xowiki::PageInstance} {
        db_dml delete_orphan_revisions "
          delete from cr_revisions where revision_id in (
                 select r.revision_id from cr_items i,cr_revisions r  
                 where i.content_type = '$class' and r.item_id = i.item_id 
                 and not r.revision_id in (select [$class id_column] from [$class table_name]))
        "
        db_dml delete_orphan_items "
         delete from acs_objects where object_type = '$class' 
             and not object_id in (select item_id from cr_items where content_type = '$class') 
             and not object_id in (select [$class id_column] from [$class table_name])
         "
      }
    }

    if {[apm_version_names_compare $from_version_name "0.31"] == -1 &&
        [apm_version_names_compare $to_version_name "0.31"] > -1} {
      ns_log notice "-- upgrading to 0.31"
      set folder_ids [list]
      set package_ids [list]
      foreach package_id [::xowiki::Package instances] {
        set folder_id [db_string get_folder_id "select f.folder_id from cr_items c, cr_folders f \
                where c.name = 'xowiki: $package_id' and c.item_id = f.folder_id"]
        if {$folder_id ne ""} {
          db_dml update_package_id {update acs_objects set package_id = :package_id where object_id in 
            (select item_id as object_id from cr_items where parent_id = :folder_id)}
          db_dml update_package_id {update acs_objects set package_id = :package_id where object_id in 
            (select r.revision_id as object_id from cr_revisions r, cr_items i where 
             i.item_id = r.item_id and i.parent_id = :folder_id)}
          ::xowiki::Package initialize -package_id $package_id -init_url false
          ::$package_id reindex
        }
      }
    }

    if {[apm_version_names_compare $from_version_name "0.34"] == -1 &&
        [apm_version_names_compare $to_version_name "0.34"] > -1} {
      ns_log notice "-- upgrading to 0.34"
      ::xowiki::notifications-install
    }

    if {[apm_version_names_compare $from_version_name "0.39"] == -1 &&
        [apm_version_names_compare $to_version_name "0.39"] > -1} {
      ns_log notice "-- upgrading to 0.39"
      catch {db_dml create-xowiki-last-visited-time-idx \
        "create index xowiki_last_visited_time_idx on xowiki_last_visited(time)"
      }
    }

    if {[apm_version_names_compare $from_version_name "0.42"] == -1 &&
        [apm_version_names_compare $to_version_name "0.42"] > -1} {
      ns_log notice "-- upgrading to 0.42"
      ::xowiki::add_ltree_order_column
      # get rid of obsolete column
      catch {
      ::xo::db::CONTENT_TYPE DELETE_ATTRIBUTE {
        {content_type ::xowiki::Page} {attribute_name page_title} 
        {drop_column t}
      }}
      # drop old non-conformant indices
      foreach index { xowiki_ref_index 
        xowiki_last_visited_index_unique xowiki_last_visited_index
        xowiki_tags_index_tag xowiki_tags_index_user
      } {
        catch {db_dml drop_index "drop index $index"}
      }
      ::xowiki::update_views
    }
  }

  ad_proc fix_all_package_ids {} {
    earlier versions of openacs did not have the package_id set correctly
    in acs_objects; this proc updates the package_ids of all items
    and revisions in acs_objects
  } {
    set folder_ids [list]
    set package_ids [list]
    foreach package_id [::xowiki::Package instances] {
      ns_log notice "checking package_id $package_id"
      set folder_id [db_list get_folder_id "select f.folder_id from cr_items c, cr_folders f \
                where c.name = 'xowiki: $package_id' and c.item_id = f.folder_id"]
      if {$folder_id ne ""} {
        db_dml update_package_id {update acs_objects set package_id = :package_id 
          where object_id in 
          	(select item_id as object_id from cr_items where parent_id = :folder_id)
          and package_id is NULL}
        db_dml update_package_id {update acs_objects set package_id = :package_id 
          where object_id in 
                (select r.revision_id as object_id from cr_revisions r, cr_items i where 
                 i.item_id = r.item_id and i.parent_id = :folder_id)
          and package_id is NULL}
      }
    }
  }

  ad_proc update_views {} {
    update all automatic views of xowiki
  } {

    set sql(oracle) "select object_type, content_type.refresh_view(object_type) \
                     from acs_object_types \
                     connect by supertype = prior object_type 
                     start with object_type = '::xowiki::Page'"

    set sql(postgresql) "select object_type,content_type__refresh_view(object_type)
                      from acs_object_types \
		      where object_type like '::xowiki::%' \
                      order by tree_sortkey "

    db_list get_xowiki_types $sql([db_driverkey ""]) 

    catch {db_dml drop_live_revision_view "drop view xowiki_page_live_revision"}

    if {[db_driverkey ""] eq "postgresql"} {
      set sortkeys ", ci.tree_sortkey, ci.max_child_sortkey "
    } else {
      set sortkeys ""
    }

    ::xo::db::require view xowiki_page_live_revision \
	"select p.*, cr.*,ci.parent_id, ci.name, ci.locale, ci.live_revision, \
	  ci.latest_revision, ci.publish_status, ci.content_type, ci.storage_type, \
	  ci.storage_area_key $sortkeys \
          from xowiki_page p, cr_items ci, cr_revisions cr  \
          where p.page_id = ci.live_revision \
            and p.page_id = cr.revision_id  \
            and ci.publish_status <> 'production'"
  }

  ad_proc add_ltree_order_column {} {
    add ltree order column, if ltree is configured
  } {
    if {[::xo::db::has_ltree]} {
      # catch sql statement to allow multiple runs
      catch {::xo::db::CONTENT_TYPE CREATE_ATTRIBUTE {
        {content_type ::xowiki::Page} {attribute_name page_order} {datatype text}
        {pretty_name Order} {column_spec ltree}
      }}
      ::xo::db::require index -table xowiki_page -col page_order -using gist
      set result 1
    } else {
      set result 0
    }
    ::xowiki::update_views
    return $result
  }

}