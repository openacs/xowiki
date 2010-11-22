::xo::library doc {
    XoWiki - upgrade script (no need to keep this always in memory)

    @creation-date 2010-06-26
    @author Gustaf Neumann
    @cvs-id $Id$
}

namespace eval ::xowiki {

  #
  # For the time being, we keep the __upgrade proc a single tcl
  # function. We could split it into separate files like the sql
  # upgrade scripts, but on one hand side, the upgrade snippets are
  # often similar, so it is convenient to reuse the logic from there,
  # and on the other hand side, this is not performance nor memoriy
  # sensitive, such we have to remove the big cascade below.
  #
  proc __upgrade {from_version_name to_version_name} {
    ns_log notice "-- UPGRADE $from_version_name -> $to_version_name"

    if {$to_version_name eq "0.13"} {
      ns_log notice "-- upgrading to 0.13"
      set package_id [::xo::package_id_from_package_key xowiki]
      set folder_id  [::xowiki::Page require_folder \
			  -package_id $package_id \
			  -content_types ::xowki::Page* \
			  -name xowiki]
      set r [::CrWikiPage get_instances_from_db -folder_id $folder_id]
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
            #ns_log notice "-- old class [$e info class] -> $newClass, fetching [$e set item_id] "
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
      if {![attribute::exists_p ::xowiki::Page page_title]} {
        ::xo::db::sql::content_type create_attribute \
            -content_type ::xowiki::Page \
            -attribute_name page_title \
            -datatype text \
            -pretty_name "Page Title" \
            -column_spec text
      }
      if {![attribute::exists_p ::xowiki::Page creator]} {
        ::xo::db::sql::content_type create_attribute \
            -content_type ::xowiki::Page \
            -attribute_name creator \
            -datatype text \
            -pretty_name "Creator" \
            -column_spec text
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
      # Only run this if the PageInstance does not exist
      if {[catch {acs_sc::impl::get_id -owner xowiki -name ::xowiki::PageInstance}]} {
        acs_sc::impl::new_from_spec -spec {
          name "::xowiki::PageInstance"
          aliases {
            datasource ::xowiki::datasource
            url ::xowiki::url
          }
          contract_name FtsContentProvider
          owner xowiki
        }
      }
    }

    if {[apm_version_names_compare $from_version_name "0.27"] == -1 &&
        [apm_version_names_compare $to_version_name "0.27"] > -1} {
      ns_log notice "-- upgrading to 0.27"
      db_dml copy_page_title_into_title \
          "update cr_revisions set title = p.page_title from xowiki_page p \
                where page_title != '' and revision_id = p.page_id"

      db_list delete_deprecated_types_from_ancient_versions \
	  "select [::xo::db::sql map_function_name content_item__delete(i.item_id)] from cr_items i \
                where content_type in ('CrWikiPage', 'CrWikiPlainPage', \
                'PageInstance', 'PageTemplate','CrNote', 'CrSubNote')"
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
      ::xo::db::sql::content_type delete_attribute \
          -content_type ::xowiki::Page \
          -attribute_name page_title \
          -drop_column t
      }
      # drop old non-conformant indices
      foreach index { xowiki_ref_index 
        xowiki_last_visited_index_unique xowiki_last_visited_index
        xowiki_tags_index_tag xowiki_tags_index_user
      } {
        catch {db_dml drop_index "drop index $index"}
      }
      ::xowiki::update_views
    }

    if {[apm_version_names_compare $from_version_name "0.56"] == -1 &&
        [apm_version_names_compare $to_version_name "0.56"] > -1} {
      ns_log notice "-- upgrading to 0.56"
      db_dml add_integer_column \
	  "alter table xowiki_page_instance add npage_template \
		integer references cr_items(item_id)"
      db_dml copy_old_values \
	  "update xowiki_page_instance set npage_template = cast(page_template as integer)"
      db_dml rename_old_column \
	  "alter table xowiki_page_instance rename column page_template to old_page_template"
      db_dml rename_new_column \
	  "alter table xowiki_page_instance rename column npage_template to page_template"
      # a few releases later, drop old column
      if {[db_0or1row in_between_version \
	       "select 1 from acs_object_types where \
		object_type = '::xowiki::Form' and supertype = '::xowiki::Page'"]} {
	# we have a version with a type hierarchy not compatible with the new one.
	# this comes by updating often from head. 
	# The likelyhood to have such as version is rather low.
	ns_log notice "Deleting incompatible version of ::xowiki::Form"
	::xo::db::sql::content_type drop_type -content_type ::xowiki::FormInstance \
	    -drop_children_p t -drop_table_p t -drop_objects_p t
	::xo::db::sql::content_type drop_type -content_type ::xowiki::Form \
	    -drop_children_p t -drop_table_p t -drop_objects_p t
      }
      ::xowiki::update_views
    }

    if {[apm_version_names_compare $from_version_name "0.58"] == -1 &&
        [apm_version_names_compare $to_version_name "0.58"] > -1} {
      ns_log notice "-- upgrading to 0.58"

      if {[catch {acs_sc::impl::get_id -owner xowiki -name ::xowiki::FormPage}]} {
        acs_sc::impl::new_from_spec -spec {
          name "::xowiki::FormPage"
          aliases {
            datasource ::xowiki::datasource
            url ::xowiki::url
          }
          contract_name FtsContentProvider
          owner xowiki
        }
      }
    }

    if {[apm_version_names_compare $from_version_name "0.59"] == -1 &&
        [apm_version_names_compare $to_version_name "0.59"] > -1} {
      ns_log notice "-- upgrading to 0.59"
      # Remove all old objects of tyoe ::xowiki::FormInstance and the type
      # from the database.
      if {[catch {
        ::xo::db::sql::content_type drop_type -content_type ::xowiki::FormInstance \
            -drop_children_p t -drop_table_p t -drop_objects_p t
      } errorMsg]} {
        ns_log notice "--upgrade produced error: $errorMsg"
      }
    }

    if {[apm_version_names_compare $from_version_name "0.60"] == -1 &&
        [apm_version_names_compare $to_version_name "0.60"] > -1} {
      ns_log notice "-- upgrading to 0.60"
      # load for all xowiki package instances the weblog-portlet prototype page
      foreach package_id [::xowiki::Package instances] {
	::xowiki::Package initialize -package_id $package_id -init_url false
	$package_id import-prototype-page weblog-portlet
      }
    }

    set v 0.62
    if {[apm_version_names_compare $from_version_name $v] == -1 &&
        [apm_version_names_compare $to_version_name $v] > -1} {
      ns_log notice "-- upgrading to $v"

      # make sure, the page_order is added for the upgrade
      ::xowiki::add_ltree_order_column

      # for all xowiki package instances 
      foreach package_id [::xowiki::Package instances] {
	::xowiki::Package initialize -package_id $package_id -init_url false
	# rename swf:name and image:name to file:name
	db_dml change_swf \
	    "update cr_items set name = 'file' || substr(name,4) \
		where name like 'swf:%' and parent_id = [$package_id folder_id]"
	db_dml change_image \
	    "update cr_items set name = 'file' || substr(name,6) \
		where name like 'image:%' and parent_id = [$package_id folder_id]"
	# reload updated prototype pages
	$package_id import-prototype-page book
	$package_id import-prototype-page weblog
	# TODO check: jon.griffin
      }
    }

    set v 0.70
    if {[apm_version_names_compare $from_version_name $v] == -1 &&
        [apm_version_names_compare $to_version_name $v] > -1} {
      ns_log notice "-- upgrading to $v"
      # for all xowiki package instances 
      foreach package_id [::xowiki::Package instances] {
	::xowiki::Package initialize -package_id $package_id -init_url false
	$package_id import-prototype-page categories-portlet
      }
      # perform the upgrate of 0.62 for the s5 package as well
      if {[info command ::s5::Package] ne ""} {
	foreach package_id [::s5::Package instances] {
	  ::s5::Package initialize -package_id $package_id -init_url false
	  # rename swf:name and image:name to file:name
	  db_dml change_swf \
	      "update cr_items set name = 'file' || substr(name,4) \
		where name like 'swf:%' and parent_id = [$package_id folder_id]"
	  db_dml change_image \
	      "update cr_items set name = 'file' || substr(name,6) \
		where name like 'image:%' and parent_id = [$package_id folder_id]"
	}
      }
      catch {
	# for new installs, the old column might not exist, therefor the catch
	db_dml drop_old_column \
	    "alter table xowiki_page_instance drop column old_page_template cascade"
      }
      ::xowiki::update_views
    }

    set v 0.77
    if {[apm_version_names_compare $from_version_name $v] == -1 &&
        [apm_version_names_compare $to_version_name $v] > -1} {
      ns_log notice "-- upgrading to $v"
      # load for all xowiki package instances the weblog-portlet prototype page
      foreach package_id [::xowiki::Package instances] {
	::xowiki::Package initialize -package_id $package_id -init_url false
	$package_id import-prototype-page announcements
	$package_id import-prototype-page news
	$package_id import-prototype-page weblog-portlet
      }
    }

    set v 0.78
    if {[apm_version_names_compare $from_version_name $v] == -1 &&
        [apm_version_names_compare $to_version_name $v] > -1} {
      ns_log notice "-- upgrading to $v"
      # load for all xowiki package instances the weblog-portlet prototype page
      foreach package_id [::xowiki::Package instances] {
	::xowiki::Package initialize -package_id $package_id -init_url false
	$package_id import-prototype-page news
	$package_id import-prototype-page weblog-portlet
      }
      # To iterate over all kind of xowiki packages, we could do
      # foreach package [concat ::xowiki::Package [::xowiki::Package info subclass]] {
      #    foreach package_id [$package instances] {
      #       ...
      #    }
      # }
    }
    set v 0.79
    if {[apm_version_names_compare $from_version_name $v] == -1 &&
        [apm_version_names_compare $to_version_name $v] > -1} {
      ns_log notice "-- upgrading to $v"
      # load for all xowiki package instances the weblog-portlet prototype page
      foreach package_id [::xowiki::Package instances] {
	::xowiki::Package initialize -package_id $package_id -init_url false
	$package_id import-prototype-page news-item
      }
      copy_parameter top_portlet top_includelet
    }

    set v 0.83
    if {[apm_version_names_compare $from_version_name $v] == -1 &&
        [apm_version_names_compare $to_version_name $v] > -1} {
      ns_log notice "-- upgrading to $v"
      ::xowiki::add_ltree_order_column
    }

    set v 0.86
    if {[apm_version_names_compare $from_version_name $v] == -1 &&
        [apm_version_names_compare $to_version_name $v] > -1} {
      ns_log notice "-- upgrading to $v"
      foreach package_id [::xowiki::Package instances] {
	::xowiki::Package initialize -package_id $package_id -init_url false
	$package_id import-prototype-page weblog
	$package_id import-prototype-page weblog-portlet
      }
    }

    set v 0.90
    if {[apm_version_names_compare $from_version_name $v] == -1 &&
        [apm_version_names_compare $to_version_name $v] > -1} {
      ns_log notice "-- upgrading to $v"
      set dir [acs_package_root_dir xowiki]
      foreach file {
        tcl/xowiki-portlet-procs.tcl
        www/delete-revision.tcl www/delete.tcl www/edit.tcl www/revisions.tcl
        www/index.adp www/index.tcl 
        www/view.adp www/view.tcl
        www/make-live-revision.tcl www/popular_tags.tcl www/save_tags.tcl www/weblog.tcl
        www/portlets/categories-recent.adp
        www/portlets/categories-recent.tcl
        www/portlets/categories.adp
        www/portlets/categories.tcl
        www/portlets/last-visited.adp
        www/portlets/last-visited.tcl
        www/portlets/most-popular.adp
        www/portlets/most-popular.tcl
        www/portlets/recent.adp 
        www/portlets/recent.tcl 
        www/portlets/rss-button.adp
        www/portlets/rss-button.tcl
        www/portlets/tags.tcl
        www/portlets/weblog.adp
        www/portlets/weblog.tcl
        www/portlets/wiki.adp
        www/portlets/wiki.tcl
        www/prototypes/announcements.page 
        www/admin/regression_test.tcl
      } {
        if {[file exists $dir/$file]} {
          ns_log notice "Deleting obsolete file $dir/$file"
          file delete $dir/$file
        }
      }
    }

    set v 0.96
    if {[apm_version_names_compare $from_version_name $v] == -1 &&
        [apm_version_names_compare $to_version_name $v] > -1} {
      ns_log notice "-- upgrading to $v"
      foreach package_id [::xowiki::Package instances] {
	::xowiki::Package initialize -package_id $package_id -init_url false
	$package_id import-prototype-page ical
      }
    }

    set v 0.116
    if {[apm_version_names_compare $from_version_name $v] == -1 &&
        [apm_version_names_compare $to_version_name $v] > -1} {
      ns_log notice "-- upgrading to $v"
      foreach package_id [::xowiki::Package instances] {
	::xowiki::Package initialize -package_id $package_id -init_url false
	$package_id import-prototype-page weblog
      }
      db_dml strip_colons_from_tags \
	    "update xowiki_tags set tag = trim(both ',' from tag)  where tag like '%,%'"
    }

    set v 0.120
    if {[apm_version_names_compare $from_version_name $v] == -1 &&
        [apm_version_names_compare $to_version_name $v] > -1} {
      ns_log notice "-- upgrading to $v"
      delete_parameter top_portlet
    }

    set v 0.128
    if {[apm_version_names_compare $from_version_name $v] == -1 &&
        [apm_version_names_compare $to_version_name $v] > -1} {
      ns_log notice "-- upgrading to $v"

      ::xowiki::Package initialize -package_id [::xowiki::Package first_instance]
      ::xowiki::Package require_site_wide_pages
      foreach p [::xowiki::Package instances -closure true] {
	::xowiki::transform_root_folder $p
      }

      foreach package_id [::xowiki::Package instances] {
	::xowiki::Package initialize -package_id $package_id
	set item_id [$package_id lookup -name ::[$package_id folder_id]]
	if {$item_id ne 0} {
	  ::xowiki::Object get_instance_from_db -item_id $item_id
	  set p [$item_id get_payload widget_specs]
	  if {$p ne ""} {
	    ns_log notice "Transfering widget_specs to parameter WidgetSpecs for $package_id [$package_id package_url]"
	    parameter::set_value -package_id $package_id -parameter WidgetSpecs -value $p
	  }
	} else {
	  ns_log notice "no folder object found for $package_id - [$package_id package_url]"
	}
      }
    }

    set v 0.130
    if {[apm_version_names_compare $from_version_name $v] == -1 &&
        [apm_version_names_compare $to_version_name $v] > -1} {
      ns_log notice "-- upgrading to $v"

      # load for all xowiki package instances the weblog-portlet prototype page
      foreach package_id [::xowiki::Package instances] {
	::xowiki::Package initialize -package_id $package_id -init_url false
	$package_id import-prototype-page weblog-portlet
	$package_id import-prototype-page news
      }
    }

    set v 0.131
    if {[apm_version_names_compare $from_version_name $v] == -1 &&
        [apm_version_names_compare $to_version_name $v] > -1} {
      ns_log notice "-- upgrading to $v"
      foreach package_id [::xowiki::Package instances -closure true] {
	::xowiki::Package initialize -package_id $package_id -init_url false
	# strip language prefix from folder pages
	set ff [::xowiki::Weblog instantiate_forms -forms en:folder.form -package_id $package_id]
	set e [::xowiki::FormPage get_form_entries -form_fields "" \
		   -base_item_ids $ff -package_id $package_id \
		   -always_queried_attributes *]
	foreach fp [$e children] {
	  set n [$fp name]
	  regexp {^..:(.+)$} $n . n
	  $fp rename -old_name [$fp name] -new_name $n
        }
      }
    }

    set v 0.133
    if {[apm_version_names_compare $from_version_name $v] == -1 &&
        [apm_version_names_compare $to_version_name $v] > -1} {
      ns_log notice "-- upgrading to $v"

      ::xowiki::Package initialize -package_id [::xowiki::Package first_instance]
      ::xowiki::Package require_site_wide_pages -refetch true
      foreach package_id [::xowiki::Package instances] {
	::xowiki::Package initialize -package_id $package_id -init_url false
	$package_id import-prototype-page weblog
      }
    }

    set v 0.134
    if {[apm_version_names_compare $from_version_name $v] == -1 &&
        [apm_version_names_compare $to_version_name $v] > -1} {
      ns_log notice "-- upgrading to $v"
      ::xowiki::Package initialize -package_id [::xowiki::Package first_instance]
      ::xowiki::Package require_site_wide_pages -refetch true
    }

    set v 0.135
    if {[apm_version_names_compare $from_version_name $v] == -1 &&
        [apm_version_names_compare $to_version_name $v] > -1} {
      ns_log notice "-- upgrading to $v"

      db_dml fix_transformed_folders \
	  "update acs_objects set object_type = '::xowiki::FormPage' where object_id in (select object_id from acs_objects,cr_revisions cr,cr_items ci where ci.item_id = cr.item_id and revision_id = object_id and object_type = 'content_folder' and content_type = '::xowiki::FormPage')"

      # Reset potentially wrong context-ids 
      # (the context id of the root folder should be the package id)
      foreach p [::xowiki::Package instances -closure true] {
	::xowiki::Package initialize -package_id $p
	set folder_id [$p folder_id]
	set c [db_string get_ctx "select context_id from acs_objects where object_id = $folder_id" ]
	if {$c == -100} {
	  ::xo::db::sql::acs_object set_attribute -object_id_in $folder_id \
	      -attribute_name_in context_id -value_in $p
	}
      }
    }
  }
}
