
::xo::Page requireCSS "/resources/calendar/calendar.css"
set package_id        [::xo::cc package_id]
set parent_id         [$__including_page set parent_id]
set including_item_id [$__including_page set item_id]

if {![exists_and_not_null base_url]} {
  if {![info exists page]} {set page  [$package_id get_parameter weblog_page]}
  set base_url [$package_id pretty_link -parent_id $parent_id $page]
}

set date [ns_queryget date]
if {![exists_and_not_null date]} {
  set date [dt_sysdate]
} 

array set message_key_array {
    list #acs-datetime.List#
    day #acs-datetime.Day#
    week #acs-datetime.Week#
    month #acs-datetime.Month#
}

# Get the current month, day, and the first day of the month
if {[catch {
  dt_get_info $date
} errmsg]} {
  set date [dt_sysdate]
  dt_get_info $date
}

set now       [clock scan $date]
set prev_mon  [clock scan "1 month ago" -base $now]
set next_mon  [clock scan "1 month" -base $now]

set date_list [dt_ansi_to_list $date]
set year      [dt_trim_leading_zeros [lindex $date_list 0]]
set month     [dt_trim_leading_zeros [lindex $date_list 1]]
set day       [dt_trim_leading_zeros [lindex $date_list 2]]

set months_list    [dt_month_names]
set curr_month_idx [expr {[dt_trim_leading_zeros [clock format $now -format "%m"]]-1}]
set curr_month     [lindex $months_list $curr_month_idx ]

set first_day_of_week [lc_get firstdayofweek]
set week_days [lc_get abday]
multirow create days_of_week day_short
for {set i 0} {$i < 7} {incr i} {
  multirow append days_of_week [lindex $week_days [expr {($i + $first_day_of_week) % 7}]]
}

set innersql "from xowiki_pagei p, cr_items ci \
        where ci.parent_id = $parent_id \
        and ci.item_id = p.item_id and  ci.live_revision = p.page_id \
        and ci.content_type not in ('::xowiki::PageTemplate', '::xowiki::Form') \
        and ci.item_id != $including_item_id \
        and ci.publish_status <> 'production' "

db_foreach entries_this_month "select count(ci.item_id) as c, 
        [::xo::db::sql date_trunc day p.publish_date] as d \
        $innersql
        and [::xo::db::sql date_trunc_expression month p.publish_date $year-$month-01] \
        group by [::xo::db::sql date_trunc day p.publish_date]" {
          set entries([lindex $d 0]) $c
        }

#
# The following time range specifies the dates between the navigation
# arrows of the weblog mini calendar should be. Without a limitation,
# crawler will iterate over this pages until they reach infinite past
# or infinite future. 
#
#set earliest_date "2006-01-1"
#set latest_date   "1 year"
#
# Compute the available time range
#
set dates [db_list_of_lists get_dates "select min([::xo::db::sql date_trunc day p.publish_date]),max([::xo::db::sql date_trunc day p.publish_date]) $innersql"]
set earliest_date [::xo::db::tcl_date [lindex $dates 0 0] _]
set latest_date   [::xo::db::::tcl_date [lindex $dates 0 end] _]

if {$prev_mon < [clock scan $earliest_date]} {
  set prev_month_url ""
} else {
  set prev_month     [clock format $prev_mon -format "%Y-%m-%d"]
  set prev_month_url [export_vars -base $base_url {{date $prev_month} page_num summary}]
}
if {$next_mon > [clock scan $latest_date]} {
  set next_month_url ""
} else {
  set next_month     [clock format $next_mon -format "%Y-%m-%d"]
  set next_month_url [export_vars -base $base_url {{date $next_month} page_num summary}]
}


multirow create days day_number beginning_of_week_p end_of_week_p today_p active_p url count class

set day_of_week 1

# Calculate number of active days
set active_days_before_month [expr {[dt_first_day_of_month $year $month] -1}]
set active_days_before_month [expr {($active_days_before_month + 7 - $first_day_of_week) % 7}]

set calendar_starts_with_julian_date [expr {$first_julian_date_of_month - $active_days_before_month}]
set day_number [expr {$days_in_last_month - $active_days_before_month + 1}]

for {set julian_date $calendar_starts_with_julian_date} {$julian_date <= $last_julian_date + 7} {incr julian_date} {

  if {$julian_date > $last_julian_date_in_month && $end_of_week_p eq "t" } {
    break
  }
  set today_p f
  set active_p t
  
  if {$julian_date < $first_julian_date_of_month} {
    set active_p f
  } elseif {$julian_date > $last_julian_date_in_month} {
    set active_p f
  } 
  set ansi_date [dt_julian_to_ansi $julian_date]
  
  if {$julian_date == $first_julian_date_of_month} {
    set day_number 1
  } elseif {$julian_date == $last_julian_date_in_month +1} {
    set day_number 1
  }

  if {$julian_date == $julian_date_today} {
    set today_p t
  }
  
  if { $day_of_week == 1} {
    set beginning_of_week_p t
  } else {
    set beginning_of_week_p f
  }
  
  if { $day_of_week == 7 } {
    set day_of_week 0
    set end_of_week_p t
  } else {
    set end_of_week_p f
  }
  # ns_log notice "--D julian_date = $julian_date [dt_julian_to_ansi $julian_date] //$ansi_date"
  set count [expr {[info exists entries($ansi_date)] ? 
                   ([info exists noparens] && $noparens ? "$entries($ansi_date)" : "($entries($ansi_date))") 
                   : ""}]
  if {$today_p} {
    set class today
  } elseif {$active_p} {
    set class active
  } else {
    set class inactive
  }

  multirow append days $day_number $beginning_of_week_p $end_of_week_p $today_p $active_p \
      "[export_vars -base $base_url {{date $ansi_date} summary}]" $count $class
  incr day_number
  incr day_of_week
}

set sysdate [dt_sysdate]
set today_url [export_vars -base $base_url {{date $sysdate} page_num}]
if {$sysdate eq $date} {
  set today_p t
} else {
  set today_p f
}

