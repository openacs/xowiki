namespace eval ::xowiki {
  #
  # ::xowiki::Weblog  
  #

  Class create ::xowiki::Weblog -parameter {
    package_id
    {page_size 20}
    {page_number ""}
    date
    tag
    ptag
    category_id
    {instances_of ""}
    filter_msg
    {sort_composite ""}
    {no_footer false}
    {name_filter ""}
    {entry_label "Postings"}
    {exclude_item_ids 0}
    {summary false}
    {entry_renderer ::xowiki::Weblog::Entry}
  }
  
  ::xowiki::Weblog instproc init {} {
    my instvar filter_msg package_id nr_items next_page_link prev_page_link
    my instvar date category_id tag ptag page_number page_size summary items 
    my instvar name_filter entry_label instances_of sort_composite
    
    my log "--W starting"
    set folder_id [::$package_id set folder_id]
    set filter_msg  ""
    set query_parm ""
    
    # set up filters
    set extra_from_clause ""
    set extra_where_clause ""
    
    if {$date ne ""} {
      #set date_clause "and date_trunc('day',p.publish_date) = '$date'"
      set date_clause "and [::xo::db::sql date_trunc_expression day p.publish_date $date]"
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
    if {$name_filter ne ""} {
      append extra_where_clause "and ci.name ~ E'$name_filter' "
    }
    set base_type ::xowiki::Page
    set base_table xowiki_pagei
    set attributes [list cr.revision_id p.publish_date p.title p.creator p.creation_user \
                        p.description s.body]
    if {$instances_of ne ""} {
      set form_items [list]
      foreach t [split $instances_of |] {
        set form_item_id [::xowiki::Form lookup -name $t -parent_id $folder_id]
        if {$form_item_id == 0} {error "Cannot lookup page $t"}
        lappend form_items $form_item_id
      }
      append extra_where_clause " and p.page_template in ('[join $form_items ',']') and p.page_instance_id = cr.revision_id "
      set base_type ::xowiki::FormPage
      set base_table xowiki_form_pagei
      lappend attributes instance_attributes
    }

    # create an item container, which delegates rendering to its children
    set items [::xo::OrderedComposite new -proc render {} {
      set content ""
      foreach c [my children] { append content [$c render] }
      return $content
    }]

    foreach i [split [my exclude_item_ids] ,] {lappend ::xowiki_page_item_id_rendered $i}
    $items set weblog_obj [self]
 
    set sql \
        [list -folder_id $folder_id \
             -select_attributes $attributes \
             -orderby "publish_date desc" \
             -from_clause "$extra_from_clause , $base_table p left outer join syndication s on s.object_id = p.revision_id" \
             -where_clause "ci.item_id not in ([my exclude_item_ids]) \
                and ci.name != '::$folder_id' and ci.name not like '%weblog%' $date_clause \
		[::xowiki::Page container_already_rendered ci.item_id] \
                and ci.content_type not in ('::xowiki::PageTemplate','::xowiki::Object') \
                and ci.publish_status <> 'production' \
		and p.revision_id = cr.revision_id \
                $extra_where_clause" ]

    if {$page_number ne ""} {
      lappend sql -page_number $page_number -page_size $page_size 
    }
    
    set nr_items [db_string count [eval $base_type instance_select_query $sql -count true]]
    
    set s [$base_type instantiate_objects -sql [eval  $base_type instance_select_query $sql]]
    
    foreach c [$s children] {
      $c instvar revision_id publish_date title name item_id creator creation_user description body

      regexp {^([^.]+)[.][0-9]+(.*)$} $publish_date _ publish_date tz
      set pretty_date [util::age_pretty -timestamp_ansi $publish_date \
                           -sysdate_ansi [clock_to_ansi [clock seconds]] \
                           -mode_3_fmt "%d %b %Y, at %X"]
      
      if {$summary} {
        # we need always: package_id item_id name title creator creation_user pretty_date
        set p [Page new -package_id $package_id -item_id $item_id \
                   -name $name -title $title -creator $creator]
        $p set creation_user $creation_user
        $p set description [expr {$description eq "" && $body ne ""? \
                                      "[string range $body 0 150]..." : $description}]
      } else {
        # do full instantiation and rendering
        # ns_log notice "--Render object revision_id = $revision_id $name $title ::$revision_id?[my isobject ::$revision_id]"
        set p [::Generic::CrItem instantiate -item_id 0 -revision_id $revision_id]
	# in cases, the revision was created already earlier, drop the mixins
	if {[$p info mixin] ne ""} {$p mixin {}}
        if {[my no_footer]} {$p set __no_footer 1}
        if {[catch {$p set description [$p render]} errorMsg]} {
          set description "Render Error ($errorMsg) $revision_id $name $title"
        }
	#my log "--W $p render (mixins=[$p info mixin]) => $description"
      }
      $p set pretty_date $pretty_date
      $p set publish_date $publish_date
      #my log "--W setting $p set publish_date $publish_date"
      #$p proc destroy {} {my log "--Render temporal object destroyed"; next}
      #ns_log notice "--W Render object $p DONE $revision_id $name $title "
      $p mixin add [my set entry_renderer]
      #my log "--W items=$items, added mixin [my set entry_renderer] to $p, has now <[$p info mixin]>"
      $items add $p
    }
    
    array set smsg {1 full 0 summary}
    set flink "<a href='[::xo::cc url]?summary=[expr {!$summary}]$query_parm'>$smsg($summary)</a>"
    
    if {$page_number ne ""} {
      set nr [llength [$items children]] 
      set from [expr {($page_number-1)*$page_size+1}]
      set to   [expr {($page_number-1)*$page_size+$nr}]
      set range [expr {$nr > 1 ? "$from - $to" : $from}]
      
      if {$filter_msg ne ""} {
        append filter_msg ", $range of $nr_items $entry_label (<a href='[::xo::cc url]'>all</a>, $flink)"
      } else {
        append filter_msg "Showing $range of $nr_items $entry_label ($flink)"
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
    }
    #my proc destroy {} {my log "--W"; next}
    
    if {$sort_composite ne ""} {
      foreach {kind att direction} [split $sort_composite ,] break
      if {$kind eq "method"} {$items mixin add ::xo::OrderedComposite::MethodCompare}
      $items orderby -order [expr {$direction eq "asc" ? "increasing" : "decreasing"}] $att
    }
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
    my instvar package_id name title creator creation_user pretty_date description 
    [my set __parent] instvar weblog_obj

    set link [::$package_id pretty_link $name]
    set more [expr {[$weblog_obj summary] ? 
                    " <span class='more'> \[<a href='$link'>#xowiki.weblog-more#</a>\]</span>" : ""}]
    append more "<p></p>"

    append content "<DIV class='post' style='clear: both;'>" \
        "<h2><a href='$link'>$title</a></h2>" \
        "<p class='auth'>Created by $creator, " \
        "last modfied by [::xo::get_user_name $creation_user] " \
        "<span class='date'>$pretty_date</span></p>" \
        $description $more \n\
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
