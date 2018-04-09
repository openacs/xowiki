namespace eval ::xowiki {
  #
  # ::xowiki::Weblog  
  #

  Class create ::xowiki::Weblog -parameter {
    package_id
    {parent_id 0}
    {page_size 20}
    {page_number ""}
    date
    tag
    ptag
    category_id
    {entries_of ""}
    {locale ""}
    filter_msg
    {sort_composite ""}
    {no_footer false}
    {name_filter ""}
    {entry_label "Postings"}
    {exclude_item_ids 0}
    {entry_renderer ::xowiki::Weblog::Entry}
    {entry_flag}
    {summary:boolean false}
    {summary_chars 150}
    {compute_summary:boolean false}
  }

  ::xowiki::Weblog proc instantiate_forms {
     {-default_lang ""} 
     {-parent_id ""} 
     -forms:required 
     -package_id:required
     } {
    set form_item_ids [list]
    foreach t [split $forms |] {
      #:log "trying to get $t // parent_id $parent_id"
      set page [$package_id get_page_from_item_ref \
                    -use_prototype_pages true \
                    -use_package_path true \
                    -parent_id $parent_id \
                    $t]
      #:log "weblog form $t => $page"
      if {$page ne ""} {
        lappend form_item_ids [$page item_id]
      }
    }
    #:log "instantiate: parent_id=$parent_id-forms=$forms -> $form_item_ids"
    return $form_item_ids
  }

  ::xowiki::Weblog instproc init {} {
    
    #:log "--W starting"
    set folder_id [::${:package_id} folder_id]
    set :filter_msg  ""
    set query_parm ""
    set query [expr {[ns_conn isconnected] ? [ns_conn query] : ""}]
    
    # set up filters
    set extra_from_clause ""
    set extra_where_clause ""

    if {${:date} ne ""} {
      if {![regexp {^\d\d\d\d[-]\d\d[-]\d\d$} ${:date}]} {
        ns_log Warning "invalid date '${:date}'"
        ad_return_complaint 1 "invalid date"
        ad_script_abort
      }
    }
    if {${:date} ne ""} {
      #set date_clause "and date_trunc('day',bt.publish_date) = '${:date}'"
      set date ${:date}
      set date_clause "and [::xo::dc date_trunc_expression day bt.publish_date :date]"
      set :filter_msg "Filtered by date ${:date}"
      set query_parm "&date=${:date}"
      set query [::xo::update_query $query date ${:date}]
    } else {
      set date_clause ""
    }
    if {${:category_id} ne ""} {
      set cnames {}
      set category_ids {}
      foreach cid [split ${:category_id} ,] {
        if {![string is integer -strict $cid]} {
          ad_return_complaint 1 "invalid category_id"
          ad_script_abort
        }
        append extra_where_clause "and exists (select * from category_object_map \
           where object_id = ci.item_id and category_id = '$cid')"
        lappend cnames [::category::get_name $cid]
        lappend category_ids $cid
      }
      set :category_id [join $category_ids ,]
      append extra_from_clause  ""
      set :filter_msg "Filtered by category [join $cnames {, }]"
      set query_parm "&category_id=${:category_id}"
      set query [::xo::update_query $query category_id ${:category_id}]
    }
    #:msg "tag=${:tag}"
    if {${:tag} ne ""} {
      ${:package_id} validate_tag ${:tag}
      set :filter_msg "Filtered by your tag ${:tag}"
      set tag ${:tag}
      append extra_from_clause " join xowiki_tags tags on (tags.item_id = bt.item_id) "
      append extra_where_clause "and tags.tag = :tag and \
        tags.user_id = [::xo::cc user_id]" 
      set query_parm "&tag=[ad_urlencode ${:tag}]"
    }
    #:msg "ptag=${:ptag}"
    if {${:ptag} ne ""} {
      ${:package_id} validate_tag ${:ptag}
      set :filter_msg "Filtered by popular tag ${:ptag}"
      set ptag ${:ptag}
      append extra_from_clause " join xowiki_tags tags on (tags.item_id = bt.item_id) "
      append extra_where_clause "and tags.tag = :ptag " 
      set query_parm "&ptag=[ad_urlencode ${:ptag}]"
      set query [::xo::update_query $query ptag ${:ptag}]
    }
    #:msg filter_msg=${:filter_msg} 
    if {${:name_filter} ne ""} {
      append extra_where_clause "and ci.name ~ E'${:name_filter}' "
    }
    set base_type ::xowiki::Page
    set base_table xowiki_pagei
    set attributes [list bt.revision_id bt.publish_date bt.title bt.creator bt.creation_user \
                        ci.parent_id bt.description s.body \
                        pi.instance_attributes pi.page_template fp.state]
    
    set class_clause \
        " and ci.content_type not in ('::xowiki::PageTemplate','::xowiki::Object')"

    if {${:entries_of} ne ""} {
      if {[string match "::*" ${:entries_of}]} {
        # class names were provided as a filter
        set class_clause \
            " and ci.content_type in ('[join [split ${:entries_of} { }] ',']')"
      } else {
        if {[regexp {^[0-9 ]+$} ${:entries_of}]} {
          # form item_ids were provided as a filter
          set :form_ids ${:entries_of}
        } else {
          # form names provided as a filter
          set :form_ids [::xowiki::Weblog instantiate_forms \
                             -forms ${:entries_of} \
                             -package_id ${:package_id}]
        }
        if {${:form_ids} ne ""} {
          append extra_where_clause " and bt.page_template in ('[join ${:form_ids} ',']') and bt.page_instance_id = bt.revision_id "
        } else {
          :msg "could not lookup forms ${:entries_of}"
        }
        set base_type ::xowiki::FormPage
        set base_table xowiki_form_pagei
        append attributes ,bt.page_template,bt.state
        set class_clause ""
      }
    }

    if {${:locale} ne ""} {
      #set :locale "default+system"
      lassign [::xowiki::Includelet locale_clause -revisions bt -items ci ${:package_id} ${:locale}] :locale locale_clause
      #:msg "--L locale_clause=$locale_clause"
      append extra_where_clause $locale_clause
    }
    
    # create an item container, which delegates rendering to its children
    set :items [::xo::OrderedComposite new -proc render {} {
      set content ""
      foreach c [:children] { append content [$c render] }
      return $content
    }]

    foreach i [split [:exclude_item_ids] ,] {lappend ::xowiki_page_item_id_rendered $i}
    ${:items} set weblog_obj [self]

    set query_parent_id ${:parent_id}
    if {$query_parent_id == 0} {
      set query_parent_id $folder_id
    }

    set sqlParams \
        [list -parent_id :query_parent_id \
             -select_attributes $attributes \
             -orderby "publish_date desc" \
             -base_table $base_table \
             -where_clause "ci.item_id not in ([:exclude_item_ids]) \
                and ci.name != '::$folder_id' and ci.name not like '%weblog%' $date_clause \
                [::xowiki::Page container_already_rendered ci.item_id] \
                $class_clause \
                and ci.publish_status <> 'production' \
                $extra_where_clause"]
    
    if {${:page_number} ne ""} {
      lappend sqlParams -page_number ${:page_number} -page_size ${:page_size}
    }
    #
    # Since there is no filtering on the left join tables, there is no
    # need to include these in the count query.
    #
    set :nr_items [::xo::dc get_value count-weblog-entries \
                       [$base_type instance_select_query \
                            -from_clause $extra_from_clause \
                            {*}$sqlParams -count true]]
    #:log count=${:nr_items}

    #
    # Obtain the set of answers
    #
    set s [$base_type instantiate_objects \
               -sql [$base_type instance_select_query \
                         -from_clause "\
        left outer join syndication s on s.object_id = bt.revision_id \
        left outer join xowiki_page_instance pi on (bt.revision_id = pi.page_instance_id) \
        left outer join xowiki_form_page fp on (bt.revision_id = fp.xowiki_form_page_id) \
        $extra_from_clause" \
                         {*}$sqlParams]]
    
    foreach c [$s children] {
      $c instvar revision_id publish_date title name item_id creator creation_user \
          parent_id description body instance_attributes
      
      set time [::xo::db::tcl_date $publish_date tz]
      set pretty_date [util::age_pretty -timestamp_ansi $time \
                           -sysdate_ansi [clock_to_ansi [clock seconds]] \
                           -mode_3_fmt "%d %b %Y, at %X"]
      
      if {${:summary}} {
        # we need always: package_id item_id parent_id name title creator creation_user pretty_date
        set p [Page new \
                   -package_id ${:package_id} -parent_id $parent_id \
                   -item_id $item_id -revision_id $revision_id \
                   -name $name -title $title -creator $creator]
        $p set creation_user $creation_user
        if {$description eq "" && [:compute_summary] && $body ne ""} {
          $p set description  [:get_description -nr_chars ${:summary_chars} $body]
        } else {
          $p set description $description
        }
        $p set instance_attributes $instance_attributes
      } else {
        # do full instantiation and rendering
        # ns_log notice "--Render object revision_id = $revision_id $name $title ::$revision_id?[:isobject ::$revision_id]"
        set p [::xo::db::CrClass get_instance_from_db -item_id 0 -revision_id $revision_id]
        # in cases, the revision was created already earlier, drop the mixins
        if {[$p info mixin] ne ""} {$p mixin {}}
        if {[info exists :entry_flag]} {$p set [:entry_flag] 1}
        if {[:no_footer]} {$p set __no_footer 1}
        ad_try {
          $p set description [$p render -with_footer false]
        } on error {errorMsg} {
          $p set description "Render Error ($errorMsg) $revision_id $name $title"
        }
        if {[info exists :entry_flag]} {$p unset [:entry_flag]}
        #:log "--W $p render (mixins=[$p info mixin]) => $description"
      }
      $p set pretty_date $pretty_date
      $p set publish_date $publish_date
      #:log "--W setting $p set publish_date $publish_date"
      #$p proc destroy {} {:log "--Render temporal object destroyed"; next}
      #ns_log notice "--W Render object $p DONE $revision_id $name $title "
      $p mixin add ${:entry_renderer}
      #:log "--W items=${:items}, added mixin ${:entry_renderer} to $p, has now <[$p info mixin]>"
      ${:items} add $p
    }
    array set smsg {1 full 0 summary}
    
    set summary_href [::xo::cc url]?[::xo::update_query $query summary [expr {!${:summary}}]]
    #set flink "<a href='[ns_quotehtml $summary_href$query_parm]'>[ns_quotehtml $smsg(${:summary})]</a>"
    set flink "<a href='[ns_quotehtml $summary_href]'>[ns_quotehtml $smsg([string is true ${:summary}])]</a>"
    
    if {${:page_number} ne ""} {
      set nr [llength [${:items} children]] 
      set from [expr {(${:page_number} - 1) * ${:page_size} + 1}]
      set to   [expr {(${:page_number} - 1) * ${:page_size} + $nr}]
      set range [expr {$nr > 1 ? "$from - $to" : $from}]
      
      if {${:filter_msg} ne ""} {
        set all_href  [${:package_id} package_url][${:package_id} get_parameter weblog_page weblog-portlet]
        append :filter_msg ", $range of ${:nr_items} ${:entry_label} (<a href='[ns_quotehtml $all_href]'>all</a>, $flink)"
      } else {
        append :filter_msg "Showing $range of ${:nr_items} ${:entry_label} ($flink)"
      }
      
      set next_p [expr {${:nr_items} > ${:page_number} * ${:page_size}}]
      set prev_p [expr {${:page_number} > 1}]
      
      if {$next_p} {
        set query [::xo::update_query $query page_number [expr {${:page_number} + 1}]]
        set :next_page_link [::xo::cc url]?$query
      } elseif {$prev_p} {
        set query [::xo::update_query $query page_number [expr {${:page_number} - 1}]]
        set :prev_page_link [::xo::cc url]?$query
      }
    }
    #my proc destroy {} {:log "--W"; next}
    
    if {${:sort_composite} ne ""} {
      lassign [split ${:sort_composite} ,] kind att direction
      if {$kind eq "method"} {${:items} mixin add ::xo::OrderedComposite::MethodCompare}
      ${:items} orderby -order [expr {$direction eq "asc" ? "increasing" : "decreasing"}] $att
    }
    #:log "--W done"
  }

  ::xowiki::Weblog instproc render {} {
    #:log "--W begin"
    #
    # We need the following CSS file for rendering
    #
    ::xo::Page requireCSS "/resources/xowiki/weblog.css"

    #${:items} set entry_renderer [:entry_renderer]

    set content [${:items} render]
    ${:items} destroy_on_cleanup
    #:log "--W end"
    return $content
  }
  

  # default layout for weblog entries
  Class create ::xowiki::Weblog::EntryRenderer -instproc render {{-with_footer false}} {
    ${:__parent} instvar weblog_obj

    set link [:pretty_link]
    regsub -all & $link "&amp;" link
    set more [expr {[$weblog_obj summary] ? 
                    " <span class='more'> \[<a href='[ns_quotehtml $link]'>#xowiki.weblog-more#</a>\]</span>" : ""}]
    #append more "<p></p>"

    append content "<DIV class='post'>" \
        "<h2><a href='[ns_quotehtml $link]'>[ns_quotehtml ${:title}]</a></h2>" \
        "<p class='auth'>Created by ${:creator}, " \
        "last modified by [::xo::get_user_name ${:creation_user}] " \
        "<span class='date'>${:pretty_date}</span></p>" \
        ${:description} $more \n\
        "</DIV>"
  }


  # Default layout for weblog
  Class create ::xowiki::Weblog::WeblogRenderer -instproc render {} {
    set filter ""
    set prev ""
    set next ""
    
    if {[info exists :filter_msg]} {
      set filter  "<div class='filter'>${:filter_msg}</div>"
    } 
    if {[info exists :prev_page_link]} {
      set prev "<a href='[ns_quotehtml ${:prev_page_link}]'>\
        <img border='0' src='/resources/acs-subsite/left.gif' width='13' height='13' \
             alt='Previous Page' style='float: left;  top: 0px;'></a>"
    }
    if {[info exists :next_page_link]} {
      set next "<a href='[ns_quotehtml ${:next_page_link}]'>\
        <img border='0' src='/resources/acs-subsite/right.gif' width='13' height='13'\
             alt='Next Page' style='float: left;  top: 0px;'></a>"
    }
    return "<div class='weblog'> $filter [next] $prev $next </div>"
  }


}
::xo::library source_dependent 


#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
