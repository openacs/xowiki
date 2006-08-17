namespace eval ::xowiki {
  #
  # ::xowiki::Weblog  
  #

  Class create ::xowiki::Weblog -parameter {
    package_id
    page_size
    page_number
    date
    tag
    ptag
    category_id
    filter_msg
    {exclude_item_ids 0}
    {summary false}
    {entry_renderer ::xowiki::Weblog::Entry}
  }
  
  ::xowiki::Weblog instproc init {} {
    my instvar filter_msg package_id nr_items next_page_link prev_page_link
    my instvar date category_id tag ptag page_number page_size summary items
    
    my log "--W starting"
    set folder_id [::$package_id set folder_id]
    set filter_msg  ""
    set query_parm ""
    
    # set up filters
    set extra_from_clause ""
    set extra_where_clause ""
    
    if {$date ne ""} {
      set date_clause "and date_trunc('day',p.publish_date) = '$date'"
      set filter_msg "Filtered by date $date"
      set query_parm "&date=$date"
    } else {
      set date_clause ""
    }
    if {$category_id ne ""} {
      set cnames [list]
      #append extra_where_clause "and c.object_id = ci.item_id and c.category_id = $category_id "
      #append extra_from_clause  ",category_object_map c "
      foreach cid [split $category_id ,] {
      append extra_where_clause "and exists (select * from category_object_map \
        where object_id = ci.item_id and category_id = $cid)"
        lappend cnames [::category::get_name $cid]
      }
      append extra_from_clause  ""
      set filter_msg "Filtered by category [join $cnames {, }]"
      set query_parm "&category_id=$category_id"
    }
    if {$tag ne ""} {
      set filter_msg "Filtered by your tag $tag"
      append extra_from_clause ",xowiki_tags tags "
      append extra_where_clause "and tags.item_id = ci.item_id and tags.tag = :tag and \
        tags.user_id = [::xo::cc user_id]" 
      set query_parm "&tag=[ad_urlencode $tag]"
    }
    if {$ptag ne ""} {
      set filter_msg "Filtered by popular tag $ptag"
      append extra_from_clause ",xowiki_tags tags "
      append extra_where_clause "and tags.item_id = ci.item_id and tags.tag = :ptag " 
      set query_parm "&ptag=[ad_urlencode $ptag]"
    }
    
    # create an item container, which delegates rendering to its chidlren
    set items [::xo::OrderedComposite new -proc render {} {
      set content ""
      foreach c [my children] {
        $c mixin add [my set entry_renderer]
        append content [$c render]
      }
      return $content
    }]
 
    set sql \
        [list -folder_id $folder_id \
             -select_attributes [list p.publish_date p.title p.creator p.creation_user p.description] \
             -order_clause "order by p.publish_date desc" \
             -page_number $page_number -page_size $page_size \
             -extra_from_clause $extra_from_clause \
             -extra_where_clause "and ci.item_id not in ([my exclude_item_ids]) \
                and ci.name != '::$folder_id' and ci.name not like '%weblog%' $date_clause \
                and ci.content_type not in ('::xowiki::PageTemplate','::xowiki::Object') \
                $extra_where_clause" ]
    
    set nr_items [db_string count [eval ::xowiki::Page select_query $sql -count true]]
    
    set s [::xowiki::Page instantiate_objects -sql [eval ::xowiki::Page select_query $sql]]
    foreach c [$s children] {
      $c instvar page_id publish_date title name item_id creator creation_user description

      regexp {^([^.]+)[.][0-9]+(.*)$} $publish_date _ publish_date tz
      set pretty_date [util::age_pretty -timestamp_ansi $publish_date \
                           -sysdate_ansi [clock_to_ansi [clock seconds]] \
                           -mode_3_fmt "%d %b %Y, at %X"]
      
      if {$summary} {
        # we need always: package_id name title creator creation_user pretty_date
        set p [Page new -package_id $package_id -name $name -title $title -creator $creator]
        $p set creation_user $creation_user
        $p set description $description
      } else {
        # do full instantiation and rendering
        # ns_log notice "--Render object=$p, $page_id $name $title"
        set p [::Generic::CrItem instantiate -item_id 0 -revision_id $page_id]
        if {[catch {$p set description [$p render]} errorMsg]} {
          set description "Render Error ($errorMsg) $page_id $name $title"
        }
      }
      $p set pretty_date $pretty_date
      #$p proc destroy {} {my log "--Render temporal object destroyed"; next}
      #ns_log notice "--W Render object $p DONE $page_id $name $title "

      $items add $p
    }
    
    array set smsg {1 full 0 summary}
    set flink "<a href='[::xo::cc url]?summary=[expr {!$summary}]$query_parm'>$smsg($summary)</a>"
    
    set nr [llength [$items children]] 
    set from [expr {($page_number-1)*$page_size+1}]
    set to   [expr {($page_number-1)*$page_size+$nr}]
    set range [expr {$nr > 1 ? "$from - $to" : $from}]
    
    if {$filter_msg ne ""} {
      append filter_msg ", $range of $nr_items Postings (<a href='[::xo::cc url]'>all</a>, $flink)"
    } else {
      append filter_msg "Showing $range of $nr_items Postings ($flink)"
    }
    
    set next_p [expr {$nr_items > $page_number*$page_size}]
    set prev_p [expr {$page_number > 1}]
  
    if {$next_p} {
      set query [::xo::update_query_variable [ns_conn query] page_number [expr {$page_number+1}]]
      set next_page_link [export_vars -base [::xo::cc url] $query]
    }
    if {$prev_p} {
      set query [::xo::update_query_variable [ns_conn query] page_number [expr {$page_number-1}]]
      set prev_page_link [export_vars -base [::xo::cc url] $query]
    }
    my proc destroy {} {my log "--W"; next}
    my log "--W done"
  }

  ::xowiki::Weblog instproc render {} {
    my log "--W begin"
    my instvar items
    #
    # We need the following CSS file for rendering
    #
    ::xowiki::Page requireCSS "/resources/xowiki/weblog.css"

    $items set entry_renderer [my entry_renderer]
    set content [$items render]
    $items destroy_on_cleanup
    my log "--W end"
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

  # default layout for weblog entries
  Class create ::xowiki::Weblog::EntryRenderer -instproc render {} {
    my instvar package_id name title creator creation_user pretty_date
    my log "-- rendering default $name" 
    append content "<DIV class='post' style='clear: both;'>" \
        "<h2><a href='[::$package_id pretty_link $name]'>$title</a></h2>" \
        "<p class='auth'>Created by $creator, " \
        "last modfified by [::xo::get_user_name $creation_user] " \
        "<span class='date'>$pretty_date</span></p>" \
        [my set description] \n \
        "</DIV>"
  }

  # Default layout for weblog
  Class create ::xowiki::Weblog::WeblogRenderer -instproc render {} {
    my instvar filter_msg link name prev_page_link next_page_link 

    set filter ""
    set prev ""
    set next ""
    
    if {[info exists filter_msg]} {
      set filter  "<div class='filter'>$filter_msg</div>"
    } 
    if {[info exists prev_page_link]} {
      set prev "<a href='$prev_page_link'>\
        <img border=0 src='/resources/acs-subsite/left.gif' \
             alt='Previous Page' style='float: left;  top: 0px;'></a>"
    }
    if {[info exists next_page_link]} {
      set next "<a href='$next_page_link'>\
        <img border=0 src='/resources/acs-subsite/right.gif' \
             alt='Next Page' style='float: left;  top: 0px;'></a>"
    }
    return "<div class='weblog'> $filter [next] $prev $next </div>"
  }


}
