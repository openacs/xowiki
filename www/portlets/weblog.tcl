# $Id$
# display items
# -gustaf neumann
#
# valid parameters from the include are 
#     page_size: show given number of new entries per page

::xowiki::Page requireCSS "/resources/xowiki/weblog.css"

# get the folder id from the including page
set folder_id    [$__including_page set parent_id]

if {![info exists package_id]}  {set package_id [$folder_id set package_id]}
if {![info exists page_size]}  {set page_size 10}

set filter_msg  ""
set page_number [ns_queryget page_number 1]
set page_size   [ns_queryget page_size $page_size]
set date        [ns_queryget date]
set category_id [ns_queryget category_id]

$__including_page set render_adp 0  ;# no double substitutions

# set up filters
if {$date ne ""} {
  set date_clause "and date_trunc('day',p.publish_date) = '$date'"
  set filter_msg "Filtered by date $date"
} else {
  set date_clause ""
}
if {$category_id ne ""} {
  set cat_clause        "and c.object_id = ci.item_id and c.category_id = $category_id"
  set extra_from_clause ",category_object_map c"
  set filter_msg "Filtered by category [::category::get_name $category_id]"
} else {
  set cat_clause ""
  set extra_from_clause ""
}

# define item container
set items [::xo::OrderedComposite new -proc render {} {
  set content ""
  foreach c [my children] {append content [$c render]}
  return $content
}]
uplevel #0 $items volatile


Class ::xowiki::WeblogEntry -instproc render {} {
  append content "<DIV class='post' style='clear: both;'>" \
      "<h2><a href='[::xowiki::Page pretty_link [my set title]]'>[my set page_title]</a></h2>" \
      "<p class='auth'>Created by [my set creator], " \
      "<span class='date'>[my set pretty_date]</span></p>" \
      [my set description] \n \
      "</DIV>"
}

set query \
    [list -folder_id $folder_id \
	 -select_attributes [list p.publish_date] \
	 -order_clause "order by p.publish_date desc" \
	 -page_number $page_number -page_size $page_size \
	 -extra_from_clause $extra_from_clause \
	 -extra_where_clause "and ci.item_id != [$__including_page set item_id] $date_clause \
	        and ci.content_type not in ('::xowiki::PageTemplate') $cat_clause" \
	]

set nr_items [db_string count [eval ::xowiki::Page select_query $query -count true]]

db_foreach instance_select [eval ::xowiki::Page select_query $query] {
  set p [::Generic::CrItem instantiate -item_id 0 -revision_id $page_id]

  regexp {^([^.]+)[.][0-9]+(.*)$} $publish_date _ publish_date tz
  set pretty_date [util::age_pretty -timestamp_ansi $publish_date \
		       -sysdate_ansi [clock_to_ansi [clock seconds]] \
		       -mode_3_fmt "%d %b %Y, at %X"]
  
  #$p proc destroy {} {my log "--Render temporal object destroyed"; next}
  $p set pretty_date $pretty_date
  
  #ns_log notice "--Render object=$p, $page_id $title $page_title"
  if {[catch {$p set description [$p render]} errorMsg]} {
    ns_log notice "--Render Error ($errorMsg) $page_id $title $page_title"
    continue
  }
  #ns_log notice "--Render DONE $page_id $title $page_title"
  $items add $p
}

::xowiki::Page instmixin add ::xowiki::WeblogEntry
set content [$items render]
::xowiki::Page instmixin delete ::xowiki::WeblogEntry

proc ::xo::update_query_variable {old_query var value} {
  set query [list [list $var $value]]
  foreach pair [split $old_query &] {
    foreach {key value} [split $pair =] break
    if {$key eq $var} continue
    lappend query [list [ns_urldecode $key] [ns_urldecode $value]]
  }
  return $query
}

if {$filter_msg eq ""} {
  set filter_msg "Showing [llength [$items children]] of $nr_items Postings"
}

set next_p [expr {$nr_items > $page_number*$page_size}]
set prev_p [expr {$page_number > 1}]

if {$next_p} {
  set query [::xo::update_query_variable [ns_conn query] page_number [expr {$page_number+1}]]
  set next_page [export_vars -base [ad_conn url] $query]
}
if {$prev_p} {
  set query [::xo::update_query_variable [ns_conn query] page_number [expr {$page_number-1}]]
  set prev_page [export_vars -base [ad_conn url] $query]
}
set link [ad_conn url]