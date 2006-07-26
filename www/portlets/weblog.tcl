# $Id$
# display items
# -gustaf neumann
#
# valid parameters from the include are 
#     page_size: show given number of new entries per page

::xowiki::Page requireCSS "/resources/xowiki/weblog.css"

Class ::xowiki::WeblogEntry -instproc render {} {
  append content "<DIV class='post' style='clear: both;'>" \
      "<h2><a href='[::xowiki::Page pretty_link [my set name]]'>[my set title]</a></h2>" \
      "<p class='auth'>Created by [my set creator], " \
      "<span class='date'>[my set pretty_date]</span></p>" \
      [my set description] \n \
      "</DIV>"
}

::xowiki::Page proc __render_html {
  -folder_id 
  -including_page
  -page_size
  -page_number
  -date
  -tag
  -ptag
  -category_id
  -filter_msg
  -nr_items
  {-summary:boolean false}
} {
  upvar $filter_msg my_filter_msg  ;# pass info back to caller
  upvar $nr_items   my_nr_items    ;# pass info back to caller

  set package_id [$folder_id set package_id]
  $including_page set render_adp 0  ;# no double substitutions
  set my_filter_msg  ""
  set query_parm ""

  # set up filters
  set extra_from_clause ""
  set extra_where_clause ""

  if {$date ne ""} {
    set date_clause "and date_trunc('day',p.publish_date) = '$date'"
    set my_filter_msg "Filtered by date $date"
    set query_parm "&date=$date"
  } else {
    set date_clause ""
  }
  if {$category_id ne ""} {
    append extra_where_clause "and c.object_id = ci.item_id and c.category_id = $category_id "
    append extra_from_clause  ",category_object_map c "
    set my_filter_msg "Filtered by category [::category::get_name $category_id]"
    set query_parm "&category_id=$category_id"
  }
  if {$tag ne ""} {
    set my_filter_msg "Filtered by your tag $tag"
    append extra_from_clause ",xowiki_tags tags "
    append extra_where_clause "and tags.item_id = ci.item_id and tags.tag = :tag and tags.user_id = [ad_conn user_id]" 
    set query_parm "&tag=[ad_urlencode $tag]"
  }
  if {$ptag ne ""} {
    set my_filter_msg "Filtered by popular tag $ptag"
    append extra_from_clause ",xowiki_tags tags "
    append extra_where_clause "and tags.item_id = ci.item_id and tags.tag = :ptag " 
    set query_parm "&ptag=[ad_urlencode $ptag]"
  }


  # define item container
  set items [::xo::OrderedComposite new -proc render {} {
    set content ""
    foreach c [my children] {append content [$c render]}
    return $content
  }]
  uplevel #0 $items volatile
  
  
  set query \
      [list -folder_id $folder_id \
	   -select_attributes [list p.publish_date p.title] \
	   -order_clause "order by p.publish_date desc" \
	   -page_number $page_number -page_size $page_size \
	   -extra_from_clause $extra_from_clause \
	   -extra_where_clause "and ci.item_id != [$including_page set item_id] \
		and ci.name != '::$folder_id' $date_clause \
	        and ci.content_type not in ('::xowiki::PageTemplate') $extra_where_clause" ]

  set my_nr_items [db_string count [eval ::xowiki::Page select_query $query -count true]]

  db_foreach instance_select [eval ::xowiki::Page select_query $query] {
    set p [::Generic::CrItem instantiate -item_id 0 -revision_id $page_id]
    $p set package_id [$including_page set package_id]
    
    regexp {^([^.]+)[.][0-9]+(.*)$} $publish_date _ publish_date tz
    set pretty_date [util::age_pretty -timestamp_ansi $publish_date \
			 -sysdate_ansi [clock_to_ansi [clock seconds]] \
			 -mode_3_fmt "%d %b %Y, at %X"]
    
    #$p proc destroy {} {my log "--Render temporal object destroyed"; next}
    $p set pretty_date $pretty_date
    
    #ns_log notice "--Render object=$p, $page_id $name $title"
    if {!$summary && [catch {$p set description [$p render]} errorMsg]} {
      ns_log notice "--Render Error ($errorMsg) $page_id $name $title"
      continue
    }
    ns_log notice "--W Render DONE $page_id $name $title"
    $items add $p
  }
  
  array set smsg {1 full 0 summary}
  set flink "<a href='[ad_conn url]?summary=[expr {!$summary}]$query_parm'>$smsg($summary)</a>"

  if {$my_filter_msg eq ""} {
    append my_filter_msg "Showing [llength [$items children]] of $my_nr_items Postings " \
	"($flink)"
  } else {
    append my_filter_msg " (<a href='[ad_conn url]'>all</a>, $flink)"
  }

  ::xowiki::Page instmixin add ::xowiki::WeblogEntry
  set content [$items render]
  ::xowiki::Page instmixin delete ::xowiki::WeblogEntry
  return $content
}

proc ::xo::update_query_variable {old_query var value} {
  set query [list [list $var $value]]
  foreach pair [split $old_query &] {
    foreach {key value} [split $pair =] break
    if {$key eq $var} continue
    lappend query [list [ns_urldecode $key] [ns_urldecode $value]]
  }
  return $query
}

if {![info exists page_size]}  {set page_size 10}
set page_size   [ns_queryget page_size $page_size]
set page_number [ns_queryget page_number 1]
set summary     [ns_queryget summary 0]
set content [::xowiki::Page __render_html \
		 -folder_id   [$__including_page set parent_id] \
		 -including_page $__including_page \
		 -page_size $page_size \
		 -page_number $page_number \
		 -summary $summary \
		 -date [ns_queryget date] \
		 -category_id [ns_queryget category_id] \
		 -tag [ns_queryget tag] \
		 -ptag [ns_queryget ptag] \
		 -filter_msg filter_msg \
		 -nr_items nr_items]

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