ad_library {
    XoWiki - Utility procs

    @creation-date 2006-08-08
    @author Gustaf Neumann
    @cvs-id $Id$
}

namespace eval ::xowiki {

  Object create tidy
  tidy proc clean {text} {
    if {[[::xo::cc package_id] get_parameter tidy 0] 
        && [info command ::util::which] ne ""} { 
      set tidycmd [::util::which tidy]
      if {$tidycmd ne ""} {
	set in_file [ns_tmpnam]
	::xowiki::write_file $in_file $text
	catch {exec $tidycmd -q -w 0 -ashtml < $in_file 2> /dev/null} output
	file delete $in_file
	#my msg o=$output
	regexp <body>\n(.*)\n</body> $output _ text
	#my msg o=$text
	return $text
      }
    }
    return $text
  }

  proc copy_parameter {from to} {
    set parameter_obj [::xo::parameter get_parameter_object \
                           -parameter_name $from -package_key xowiki]
    if {$parameter_obj eq ""} {error "no such parameter $from"}
    foreach package_id [::xowiki::Package instances] {
      set value [$parameter_obj get -package_id $package_id]
      parameter::set_value -package_id $package_id -parameter $to -value $value
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
    foreach object_type [::xowiki::Page object_types] {
      ::xo::db::sql::content_type refresh_view -content_type $object_type
    }

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
    add page_order of type ltree, when ltree is configured (otherwise string)
  } {
    # catch sql statement to allow multiple runs
    catch {::xo::db::sql::content_type create_attribute \
	       -content_type ::xowiki::Page \
	       -attribute_name page_order \
	       -datatype text \
	       -pretty_name Order \
	       -column_spec [::xo::db::sql map_datatype ltree]}
    
    ::xo::db::require index -table xowiki_page -col page_order \
	-using [expr {[::xo::db::has_ltree] ? "gist" : ""}]
    ::xowiki::update_views
    return 1
  }

  ad_proc cr_thin_out {{-doit 0} {-edit_interval 300} {-older_than "1 month ago"} -package_id -item_id} {
    Delete supposedly uninportant revision from the content repository.
    
    @param edit_interval delete entries, which never become older than this interval (in seconds, default 300)
    @param older_than delete only entries, which were modified longer than the provided time ago
  } {
    set extra_cause ""
    if {[info exists package_id]} {
      append extra_clause " and o.package_id = $package_id"
    }
    if {[info exists item_id]} {
      append extra_clause " and i.item_id = $item_id"
    }

    # only delete revisions older than this date
    set older_than [clock scan $older_than]

    #
    # The first query removes widow entries, where a user pressed new, but
    # never saved it. We could check as well, if the item has exactly one revision.
    #
    set sql "
       select i.name, o.package_id, i.item_id, r.revision_id, o.last_modified
       from acs_objects o, xowiki_page p, cr_revisions r, cr_items i 
       where p.page_id = r.revision_id and r.item_id = i.item_id and o.object_id = r.revision_id 
       and i.publish_status = 'production' and i.name = r.revision_id::varchar
    "
    foreach tuple [db_list_of_lists get_revisions $sql] {
      #::xotcl::Object msg "tuple = $tuple"
      foreach {name package_id item_id revision_id last_modified} $tuple break 
      set time [clock scan [::xo::db::tcl_date $last_modified tz_var]]
      if {$time > $older_than} continue
      ::xotcl::Object msg "...will delete $name doit=$doit $last_modified"
      if {$doit} {
        ::xowiki::Package require $package_id
        $package_id delete -item_id $item_id -name $name
      }
    }
    
    #
    # The first query removes quick edits, where from a sequence of edits of the same user,
    # only the last edit is kept
    #
    set sql "
      select i.name, i.item_id, r.revision_id,  o.last_modified, o.creation_user, o.package_id
      from acs_objects o, xowiki_page p, cr_revisions r, cr_items i 
      where p.page_id = r.revision_id and r.item_id = i.item_id
      and o.object_id = r.revision_id  
      $extra_clause
      order by item_id, revision_id asc
    "
    set last_item ""
    set last_time 0
    set last_user ""
    set last_revision ""

    foreach tuple [db_list_of_lists get_revisions $sql] {
      #::xotcl::Object msg "tuple = $tuple"
      foreach {name item_id revision_id last_modified user package_id} $tuple break 
      set time [clock scan [::xo::db::tcl_date $last_modified tz_var]]
      if {$time > $older_than} continue
      #::xotcl::Object msg "compare time $time with $older_than => [expr {$time < $older_than}]"
      if {$last_user eq $user && $last_item == $item_id} {
        set timediff [expr {$time-$last_time}]
        #::xotcl::Object msg "   timediff=[expr {$time-$last_time}]"
        if {$timediff < $edit_interval && $timediff >= 0} {
          ::xotcl::Object msg "...will delete $name revision=$last_revision, doit=$doit $last_modified"
          if {$doit} {
            ::xowiki::Package require $package_id
            $package_id delete_revision -revision_id $last_revision -item_id $item_id
          }
        }
      }
      set last_user $user
      set last_time $time
      set last_item $item_id
      set last_revision $revision_id
    }
  }

  proc unmounted_instances {} {
    return [db_list unmounted_instances {
      select package_id from apm_packages p where not exists 
      (select 1 from site_nodes where object_id = p.package_id) 
      and p.package_key = 'xowiki'
    }]
  }

  proc form_upgrade {} {
    db_dml from_upgrade {
      update xowiki_form f set form = xowiki_formi.data from xowiki_formi 
      where f.xowiki_form_id = xowiki_formi.revision_id
    }
  }

  proc read_file {fn} {
    set F [open $fn]
    fconfigure $F -translation binary
    set content [read $F]
    close $F
    return $content
  }
  proc write_file {fn content} {
    set F [open $fn w]
    fconfigure $F -translation binary
    puts -nonewline $F $content
    close $F
  }

  ad_proc -public -callback subsite::url -impl apm_package {
    {-package_id:required}
    {-object_id:required}
    {-type ""}
  } {
    return the page_url for an object of type tasks_task
  } {
    ns_log notice "got package_id=$package_id, object_id=$object_id, type=$type"
    ::xowiki::Package initialize -package_id $package_id
    if {[::xotcl::Object isobject ::$package_id]} {
      return [$package_id package_url]
    } else {
      return ""
    }
  }

  Object create ::xowiki::utility
  ::xowiki::utility set age \
      [list \
           [expr {3600*24*365}] year years \
           [expr {3600*24*30}]  month months \
           [expr {3600*24*7}]   week weeks \
           [expr {3600*24}]     day days \
           [expr {3600}]        hour hours \
           [expr {60}]          minute minutes \
           [expr {1}]           second seconds \
          ]
  ::xowiki::utility proc pretty_age {
                           -timestamp:required 
                           -timestamp_base 
                           {-locale ""}
                           {-levels 1}
                         } {
    #
    # This is an internationalized pretty age functions, which prints
    # the rough date in a user friendly fashion.
    #
    #todo: caching?
    
#     outlook categories:
#     Unknown
#     Older
#     Last Month
#     Earlier This Month
#     Three Weeks Ago
#     Two Weeks Ago
#     Last Week
#     Yesterday
#     Today
#     This Week
#     Tomorrow
#     Next Week
#     Two Weeks Away
#     Three Weeks Away
#     Later This Month
#     Next Month
#     Beyond Next Month

#     Another possibilty: no ago, but "Today 10:00", "Yesterday 10:00", within a
#     week: "Thursday 10:00", older than about 30 days "13 May 2005" and
#     if anything else (ie. > 7 and < 30 days) it shows date and time "13-Oct 2005 10:00".

    if {![info exists timestamp_base]} {set timestamp_base [clock seconds]}
    set age_seconds [expr {$timestamp_base - $timestamp}]

    set pos 0
    set msg ""
    my instvar age
    foreach {interval unit unit_plural} $age {
      set base [expr {int($age_seconds / $interval)}]
      if {$base > 0} {
        set label [expr {$base == 1 ? $unit : $unit_plural}]
	set localized_label [::lang::message::lookup $locale xowiki.$label]
        set msg "$base $localized_label"
        # $pos < 5: do not report details under a minute
        if {$pos < 5 && $levels > 1} {
          set remaining_age [expr {$age_seconds-$base*$interval}]
          set interval    [lindex $age [expr {($pos+1)*3}]]
          set unit        [lindex $age [expr {($pos+1)*3+1}]]
          set unit_plural [lindex $age [expr {($pos+1)*3+2}]]
          set base [expr {int($remaining_age / $interval)}]
          if {$base > 0} {
            set label [expr {$base == 1 ? $unit : $unit_plural}]
	    set localized_label [::lang::message::lookup $locale xowiki.$label]
            append msg " $base $localized_label"
          }
        }
	set time $msg
	set msg [::lang::message::lookup $locale xowiki.ago [list [list time $msg]]]
        #append msg " ago"
        break
      }
      incr pos
    }
    return $msg
  }

}
