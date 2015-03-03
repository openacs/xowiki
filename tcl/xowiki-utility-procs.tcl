::xo::library doc {

  XoWiki - Utility procs

  @creation-date 2006-08-08
  @author Gustaf Neumann
  @cvs-id $Id$
}

namespace eval ::xowiki {

  #
  # Simple clipboard functionality
  #
  ::xotcl::Object create clipboard
  clipboard proc add {ids} {
    set clipboard [ad_get_client_property xowiki clipboard]
    lappend clipboard {*}$ids
    ad_set_client_property xowiki clipboard [lsort -unique $clipboard]
  }
  clipboard proc clear {} {
    ad_set_client_property xowiki clipboard ""
  }
  clipboard proc get {} {
    return [ad_get_client_property xowiki clipboard]
  }
  clipboard proc is_empty {} {
    expr {[my size] < 1}
  }
  clipboard proc size {} {
    set clipboard [ad_get_client_property xowiki clipboard]
    return [llength $clipboard]
  }

  #
  #
  # Helper for tidying up HTML
  #
  ::xotcl::Object create tidy
  tidy proc clean {text} {
    if {[[::xo::cc package_id] get_parameter tidy 0] 
        && [info commands ::util::which] ne ""} { 
      set tidycmd [::util::which tidy]
      if {$tidycmd ne ""} {
        set in_file [ad_tmpnam]
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

  #
  #
  # Helper for virus checks
  #
  ::xotcl::Object create virus
  virus proc check {fn} {
    if {[[::xo::cc package_id] get_parameter clamav 1]
        && [info commands ::util::which] ne ""} { 
      set clamscanCmd [::util::which clamscan]
      if {$clamscanCmd ne "" && [file readable $fn]} {
        if {[catch {exec $clamscanCmd $fn 2>@1} result]} {
          ns_log warning "[self] virus found:\n$result"
          return 1
        }
      }
    }
    return 0
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

  proc delete_parameter {from} {
    set parameter_obj [::xo::parameter get_parameter_object \
                           -parameter_name $from -package_key xowiki]
    if {$parameter_obj eq ""} {error "no such parameter $from"}
    apm_parameter_unregister -package_key [$parameter_obj package_key] [string trimleft $parameter_obj :]
    $parameter_obj destroy
  }

  ad_proc fix_all_package_ids {} {
    Earlier versions of OpenACS did not have the package_id set correctly
    in acs_objects; this proc updates the package_ids of all items
    and revisions in acs_objects
  } {
    set folder_ids [list]
    set package_ids [list]
    foreach package_id [::xowiki::Package instances] {
      ns_log notice "checking package_id $package_id"
      set folder_id [::xo::dc list get_folder_id "select f.folder_id from cr_items c, cr_folders f \
                where c.name = 'xowiki: :package_id' and c.item_id = f.folder_id"]
      if {$folder_id ne ""} {
        ::xo::dc dml update_package_id {update acs_objects set package_id = :package_id 
          where object_id in 
          (select item_id as object_id from cr_items where parent_id = :folder_id)
          and package_id is NULL}
        ::xo::dc dml update_package_id {update acs_objects set package_id = :package_id 
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

    catch {::xo::dc dml drop_live_revision_view "drop view xowiki_page_live_revision"}
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
    Add page_order of type ltree, when ltree is configured (otherwise string)
  } {
    # catch sql statement to allow multiple runs
    catch {::xo::db::sql::content_type create_attribute \
               -content_type ::xowiki::Page \
               -attribute_name page_order \
               -datatype text \
               -pretty_name Order \
               -column_spec [::xo::dc map_datatype ltree]}
    
    ::xo::db::require index -table xowiki_page -col page_order \
        -using [expr {[::xo::dc has_ltree] ? "gist" : ""}]
    ::xowiki::update_views
    return 1
  }

  ad_proc cr_thin_out {
    {-doit false} 
    {-delete_orphans false} 
    {-delete_sequences false} 
    {-edit_interval 300} 
    {-older_than "1 month ago"} 
    -package_id
    -item_id
  } {
    Delete supposedly uninportant items and revision from the content repository.
    
    @param doit if not true, then just write delete operation to the logfile
    @param delete_orphans if true, delete orphaned items
    @param delete_sequences if true, delete revisions from edit sequences lower than edit_interval
    @param edit_interval delete entries, which never become older than this interval (in seconds, default 300)
    @param older_than delete only entries, which were modified longer than the provided time ago
    @param package_id if specified, perform operation just on the specified package
    @param item_id if specified, perform operation just on the specified item
  } {
    set extra_clause ""
    if {[info exists package_id]} {
      append extra_clause " and o.package_id = :package_id"
    }
    if {[info exists item_id]} {
      append extra_clause " and i.item_id = :item_id"
    }

    # only delete revisions older than this date
    set older_than [clock scan $older_than]

    if {$delete_orphans} {
      #
      # Removes orphaned items, where a user pressed "new", but never
      # saved the page. We could check as well, if the item has
      # exactly one revision.
      #
      set sql "
         select i.name, o.package_id, i.item_id, r.revision_id, o.last_modified
         from acs_objects o, xowiki_page p, cr_revisions r, cr_items i 
         where p.page_id = r.revision_id and r.item_id = i.item_id and o.object_id = r.revision_id 
         and i.publish_status = 'production' and i.name = r.revision_id::varchar
         $extra_clause
      "
      ::xo::dc foreach get_revisions $sql {
        #::xotcl::Object msg "tuple = $tuple"
        lassign $tuple name package_id item_id revision_id last_modified 
        set time [clock scan [::xo::db::tcl_date $last_modified tz_var]]
        if {$time > $older_than} continue
        ::xotcl::Object log "...will delete $name doit=$doit $last_modified"
        if {$doit} {
          ::xowiki::Package require $package_id
          $package_id delete -item_id $item_id -name $name
        }
      }
    }

    if {$delete_sequences} {
      #
      # The second query removes quick edits, where from a sequence of edits of the same user,
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
      
      xo::dc foreach get_revisions $sql {
        #::xotcl::Object msg "tuple = $tuple"
        lassign $tuple name item_id revision_id last_modified user package_id 
        set time [clock scan [::xo::db::tcl_date $last_modified tz_var]]
        if {$time > $older_than} continue
        #::xotcl::Object msg "compare time $time with $older_than => [expr {$time < $older_than}]"
        if {$last_user eq $user && $last_item == $item_id} {
          set timediff [expr {$time-$last_time}]
          #::xotcl::Object msg "   timediff=[expr {$time-$last_time}]"
          if {$timediff < $edit_interval && $timediff >= 0} {
            ::xotcl::Object log "...will delete $name revision=$last_revision, doit=$doit $last_modified"
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
  }

  proc unmounted_instances {} {
    return [::xo::dc list unmounted_instances {
      select package_id from apm_packages p where not exists 
      (select 1 from site_nodes where object_id = p.package_id) 
      and p.package_key = 'xowiki'
    }]
  }

  proc form_upgrade {} {
    ::xo::dc dml from_upgrade {
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
    set F [::open $fn w]
    ::fconfigure $F -translation binary
    ::puts -nonewline $F $content
    ::close $F
  }

  proc ::xowiki::page_order_uses_ltree {} {
    if {[::xo::dc has_ltree]} {
      ns_cache eval xotcl_object_cache ::xowiki::page_order_uses_ltree {
        return [::xo::dc get_value check_po_ltree {
          select count(*) from pg_attribute a, pg_type t, pg_class c 
          where attname = 'page_order' and a.atttypid = t.oid and c.oid = a.attrelid 
          and relname = 'xowiki_page'}]
      }
    } else {
      return 0
    }
  }


  proc ::xowiki::transform_root_folder {package_id} {
    ::xo::Package initialize -package_id $package_id
    set item_id [$package_id folder_id]
    ::xo::clusterwide ns_cache flush xotcl_object_type_cache $item_id
    set form_id [::xowiki::Weblog instantiate_forms -forms en:folder.form -package_id $package_id]

    if {[::xo::dc 0or1row check {
      select 1 from cr_items where content_type = '::xowiki::FormPage' and item_id = :item_id
    }]} {
      ns_log notice "folder $item_id is already converted"
      set f [FormPage get_instance_from_db -item_id $item_id]
      if {[$f page_template] != $form_id} {
        ns_log notice "... must change form_id from [$f page_template] to $form_id"
        ::xo::dc dml chg0 "update xowiki_page_instance set page_template = $form_id where page_instance_id = [$f revision_id]"
      }
      return
    }
    set revision_id [::xo::db::sql::content_revision new \
                         -title [$package_id instance_name] -text "" \
                         -item_id $item_id -package_id $package_id]
    ::xo::dc dml chg1 "insert into xowiki_page (page_id) values ($revision_id)"
    ::xo::dc dml chg2 "insert into xowiki_page_instance (page_instance_id, page_template) values ($revision_id, $form_id)"
    ::xo::dc dml chg3 "insert into xowiki_form_page (xowiki_form_page_id) values ($revision_id)"
    
    ::xo::dc dml chg4 "update acs_objects set object_type = 'content_item' where object_id = :item_id"
    ::xo::dc dml chg5 "update acs_objects set object_type = '::xowiki::FormPage' where object_id = :revision_id"
    ::xo::dc dml chg6 "update cr_items set content_type = '::xowiki::FormPage',  publish_status = 'ready', live_revision = :revision_id, latest_revision = :revision_id where item_id = :item_id"
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

}

#
# Some Date utilities
#

::xo::Module create ::xowiki::utility -eval {
  my set age \
      [list \
           [expr {3600*24*365}] year years \
           [expr {3600*24*30}]  month months \
           [expr {3600*24*7}]   week weeks \
           [expr {3600*24}]     day days \
           [expr {3600}]        hour hours \
           [expr {60}]          minute minutes \
           [expr {1}]           second seconds \
          ]
  
  my proc pretty_age {
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
        break
      }
      incr pos
    }
    if {$msg eq ""} {
      set time "0 [::lang::message::lookup $locale xowiki.seconds]"
      set msg [::lang::message::lookup $locale xowiki.ago [list [list time $time]]]
    }
    return $msg
  }
}

#
# utility functions for Page orders
#

::xo::Module create ::xowiki::utility -eval {

  my proc incr_page_order {p} {
    lassign [list "" $p] prefix suffix
    regexp {^(.*[.])([^.]+)$} $p _ prefix suffix
    if {[string is integer -strict $suffix]} {
      incr suffix
    } elseif {[string is lower -strict $suffix]} {
      regexp {^(.*)(.)$} $suffix _ before last
      if {$last eq "z"} {
        set last "aa"
      } else {
        set last [format %c [expr {[scan $last %c] + 1}]]
      }
      set suffix $before$last
    } elseif {[string is upper -strict $suffix]} {
      regexp {^(.*)(.)$} $suffix _ before last
      if {$last eq "Z"} {
        set last "AA"
      } else {
        set last [format %c [expr {[scan $last %c] + 1}]]
      }
      set suffix $before$last
    }
    return $prefix$suffix
  }
  
  my proc page_order_compute_new_names {start page_orders} {
    lappend pairs [lindex $page_orders 0] $start
    foreach p [lrange $page_orders 1 end] {
      lappend pairs $p [set start [my incr_page_order $start]]
    }
    return $pairs
  }
  
  my proc get_page_order_items {-parent_id {-publish_status "production"} page_orders} {
    set likes [list]
    foreach page_order $page_orders {
      if {[::xowiki::page_order_uses_ltree]} {
        lappend likes "p.page_order <@ '$page_order'" 
      } else {
        lappend likes "p.page_order = '$page_order'" "p.page_order like '$page_order.%'"
      }
    }
    set sql "select p.page_order, p.page_id, cr.item_id, ci.name
          from xowiki_page p, cr_items ci, cr_revisions cr  \
          where p.page_id = ci.live_revision \
            and p.page_id = cr.revision_id  \
            [::xowiki::Includelet publish_status_clause $publish_status] \
            and ci.parent_id = $parent_id \
            and ([join $likes { or }])"
    #my log $sql
    set pages [::xo::dc list_of_lists get_pages_with_page_order $sql]
    return $pages
  }
  
  ::xowiki::utility proc page_order_renames {
     -parent_id 
     {-publish_status "production"} 
     -start 
     -from 
     -to
   } {
    set pages [my get_page_order_items -parent_id $parent_id -publish_status $publish_status $to]
    #my log "pages=$pages"
    array set npo [::xowiki::utility page_order_compute_new_names $start $to]
    #my log npo=[array get npo]=>to='$to'
    set renames [list]
    foreach tuple $pages {
      lassign $tuple old_page_order page_id item_id name
      if {[info exists npo($old_page_order)]} {
        #
        # We have a name in the translation list
        #
        if {$npo($old_page_order) eq $old_page_order} {
          # Nothing to do
          #my log "--cpo name $old_page_order not changed"
        } else {
          #my log "--cpo name $old_page_order changed to '$npo($old_page_order)'"
          lappend renames $page_id $item_id $name $old_page_order $npo($old_page_order)
        }
      } else {
        # 
        # We have no translation in the list. This must be an item
        # from a subtree of changed page_orders.
        #
        #my log "--cpo no translation for $old_page_order, check prefix"
        foreach new_name [array names npo] {
          if {[string match $new_name.* $old_page_order]} {
            #
            # The name matches. Add to the rename list if the prefix name actually changed.
            #
            if {$npo($new_name) ne $new_name} {
              set l [string length $new_name]
              set new_page_order "$npo($new_name)[string range $old_page_order $l end]"
              my log "--cpo tree name $old_page_order changed to '$new_page_order'"
              lappend renames $page_id $item_id $name $old_page_order $new_page_order
            }
            break
          }
        }
      }
    }
    return $renames
  }

  #
  # The standard ns_urlencode of aolserver is oversimplifying the
  # encoding, leading to names with too many percent-encodings. This
  # is not nice, but not a problem. A real problem with ns_encode in
  # aolserver is that it encodes spaces in the url path as "+" which is
  # not backed by RFC 3986. The aolserver coding does not harm as long
  # the code is just used with aolserver. However, naviserver
  # implements an RFC-3986 compliant encoding, which distinguishes
  # between the various parts of the url (via parameter "-part
  # ..."). The problem occurs, when the url path is decoded according
  # to the RFC rules, which happens actually in the C implementation
  # within [ns_conn url] in naviserver. Naviserver performs the
  # RFC-compliant handling of "+" in the "path" segment of the url,
  # namely no interpretation.
  #
  # Here an example, consider an url path "a + b".  The aolserver
  # ns_encode yields "a+%2b+b", the aolserver ns_decode maps it back
  # to "a + b", everything is fine. However, the naviserver C-level
  # decode in [ns_conn url] converts "a+%2b+b" to "a+++b", which is
  # correct according to the RFC.
  #
  # The problem can be solved for xowiki by encoding spaces not as
  # "+", but as "%20", which is always correct. The tiny
  # implementation below fixes the problem at the Tcl level. A better
  # solution might be to backport ns_urlencode from naviserver to
  # aolserver or to provide a naviserver compliant Tcl implementation
  # for aolserver (but these options might break some existing
  # programs).
  #
  # -gustaf neumann (nov 2010)

  if {[ns_info name] eq "NaviServer"} {
    my proc urlencode {string} {ns_urlencode $string}
  } else {
    set ue_map [list]
    for {set i 0} {$i < 256} {incr i} {
      set c [format %c $i]
      set x %[format %02x $i]
      if {![string match {[-a-zA-Z0-9_.]} $c]} {
        lappend ue_map $c $x
      }
    }
    my proc urlencode {string} {string map [my set ue_map] $string}
  }


  my ad_proc user_is_active {{-asHTML:boolean false} uid} {
  } {
    if {[info commands ::throttle] ne "" && 
        [::throttle info methods user_is_active] ne ""} {
      set active [throttle user_is_active $uid]
      if {$asHTML} {
        array set color {1 green 0 red}
        array set state {1 active 0 inactive}
        return "<span class='$state($active)' style='background: $color($active);'>&nbsp;</span>"
      } else {
        return $active
      }
    } else {
      ns_log notice "user_is_active requires xotcl-request monitor in a recent version"
      return 0
    }
  }
}


proc util_jsquotevalue {value} {
  return '[::xowiki::Includelet js_encode $value]'
}


proc util_map2json {pairs} {
  set json_pairs [list]
  foreach {key value} $pairs {
    lappend json_pairs "'${key}':[util_jsquotevalue ${value}]"
  }
  return [join $json_pairs {,}]
}

proc util_coalesce {args} {
  foreach value $args {
    if { $value ne {} } {
      return $value
    }
  }
}


#
# intersect3 - perform the intersecting of two lists, returning a list
# containing three lists.  The first list is everything in the first
# list that wasn't in the second, the second list contains the intersection
# of the two lists, the third list contains everything in the second list
# that wasn't in the first.
#

proc util_intersect3 {list1 list2} {
  set la1(0) {} ; unset la1(0)
  set lai(0) {} ; unset lai(0)
  set la2(0) {} ; unset la2(0)
  foreach v $list1 {
    set la1($v) {}
  }
  foreach v $list2 {
    set la2($v) {}
  }
  foreach elem [concat $list1 $list2] {
    if {[info exists la1($elem)] && [info exists la2($elem)]} {
      unset la1($elem)
      unset la2($elem)
      set lai($elem) {}
    }
  }
  list [lsort [array names la1]] [lsort [array names lai]] \
      [lsort [array names la2]]
}


proc util_createDom {list_of_specs} {
  foreach spec $list_of_specs {
    set cmdName [lindex $spec 0]
    if { $cmdName eq "\#text" } {
      lassign $spec cmdName text
      html::t $text
    } else {
      lassign $spec cmdName atts inside_spec
      html::${cmdName} $atts [list util_createDom $inside_spec]
    }
  }
}


proc util_spec2json {list_of_specs} {

  set result [list]
  foreach spec $list_of_specs {
    set cmdName [lindex $spec 0]

    lassign $spec cmdName atts inner_spec

    # We need to handle text nodes in a better way
    # but our corresponding javascript function,
    # i.e. wu.repeatable.createDom does not support it
    # at the moment (August 2012)
    if { $cmdName eq "\#text" } { continue } 

    set json "\{'tag':[util_jsquotevalue $cmdName]"
    if { $atts ne {} } {
      append json ",[util_map2json $atts]"
    }
    if { $inner_spec ne {} } {
      lassign [lindex $inner_spec 0] nodeType text
      # llength needs to go, please see comment above 
      # it would give us trouble if we have spec that starts with
      # a text node but is then followed by element nodes, e.g.
      # e.g. text node, element node 1, element node 2, and so on
      # would give us trouble - we choose to ignore text nodes
      # in this case
      if { ${nodeType} eq "\#text" && [llength $inner_spec] == 1 } {
        # text node
        lassign [lindex $inner_spec 0] _nodeType_ text
        append json ",'html':[util_jsquotevalue $text]"
      } else {
        # list of children nodes
        append json ",'children':\[[util_spec2json $inner_spec]\]"
      }
    }
    append json "\}"
    lappend result $json
  }
  return [join $result {,}]
}

proc util_tdom2list {script {rootTag "div"}} {
  set doc [dom createDocument $rootTag]
  set root [$doc documentElement]
  $root appendFromScript {uplevel $script}
  return [$root asList]
}

::xo::library source_dependent
#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
