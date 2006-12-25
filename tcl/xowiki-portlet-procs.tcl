
namespace eval ::xowiki::portlet {
  Class create ::xowiki::Portlet \
      -superclass ::xo::Context \
      -parameter {{name ""} {title ""} {__decoration "portlet"}}

  ::xowiki::Portlet instproc locale_clause {package_id locale} {
    set default_locale [$package_id default_locale]
    set system_locale ""

    set with_system_locale [regexp {(.*)[+]system} $locale _ locale]
    if {$locale eq "default"} {
      set locale $default_locale
      set include_system_locale 0
    }

    set locale_clause ""    
    if {$locale ne ""} {
      set locale_clause " and r.nls_language = '$locale'" 
      if {$with_system_locale} {
        set system_locale [lang::system::locale -package_id $package_id]
        if {$system_locale ne $default_locale} {
          set locale_clause " and (r.nls_language = '$locale' 
		or r.nls_language = '$system_locale' and not exists
		  (select 1 from cr_items i where i.name = '[string range $locale 0 1]:' || 
		  substring(ci.name,4) and i.parent_id = ci.parent_id))"
        }
      } 
    }

    #my log "--locale $locale, def=$default_locale sys=$system_locale, cl=$locale_clause"
    return [list $locale $locale_clause]
  }


  #############################################################################
  # dotlrn style portlet decoration for includelets
  #
  Class ::xowiki::portlet::decoration=portlet -instproc render {} {
    my instvar package_id name title
    set link [expr {[string match "*:*" $name] ? [$package_id pretty_link $name] : ""}]
    return "<div class='portlet-title'>\
        <span><a href='$link'>$title</a></span></div>\
        <div class='portlet'>[next]</div>"
  }

  #############################################################################
  # rss button
  #

  Class create rss-button \
      -superclass ::xowiki::Portlet \
      -parameter {{__decoration plain}}

  rss-button instproc render {} {
    # use "span" to specify parameters to the rss call
    my initialize -parameter {
      {-span "10d"}
    }
    my get_parameters
    return "<a href='[$package_id package_url]?rss=$span' class='rss'>RSS</a>"
  }

  #############################################################################
  # valid parameters from the adp include are 
  #     tree_name: match pattern, if specified displays only the trees 
  #                with matching names
  #     no_tree_name: if specified, tree names are not displayed
  #     open_page: name (e.g. en:iMacs) of the page to be opened initially
  #     tree_style: boolean, default: true, display based on mktree

  Class create categories \
      -superclass ::xowiki::Portlet \
      -parameter {{title "Categories"}}
  
  categories instproc render {} {

    my initialize -parameter {
      {-tree_name ""}
      {-tree_style:boolean 1}
      {-no_tree_name:boolean 0}
      {-count:boolean 0}
      {-summary:boolean 0}
      {-locale ""}
      {-open_page ""}
      {-category_ids ""}
      {-except_category_ids ""}
    }
    
    my get_parameters

    set content ""
    set folder_id [$package_id folder_id]
    set open_item_id [expr {$open_page ne "" ?
                            [CrItem lookup -name $open_page -parent_id $folder_id] : 0}]

    foreach {locale locale_clause} [my locale_clause $package_id $locale] break

    set have_locale [expr {[lsearch [info args category_tree::get_mapped_trees] locale] > -1}]
    set trees [expr {$have_locale ?
                     [category_tree::get_mapped_trees $package_id $locale] :
                     [category_tree::get_mapped_trees $package_id]}]
    foreach tree $trees {
      foreach {tree_id my_tree_name ...} $tree {break}
      if {$tree_name ne "" && ![string match $tree_name $my_tree_name]} continue
      if {!$no_tree_name} {
        append content "<h3>$my_tree_name</h3>"
      }
      set categories [list]
      set pos 0
      set cattree(0) [::xowiki::CatTree new -volatile -orderby pos -name $my_tree_name]
      set category_infos [expr {$have_locale ?
                                [category_tree::get_tree $tree_id $locale] :
                                [category_tree::get_tree $tree_id]}]

      foreach category_info $category_infos {
        foreach {cid category_label deprecated_p level} $category_info {break}
        
        set c [::xowiki::Category new -orderby pos -category_id $cid -package_id $package_id \
                   -level $level -label $category_label -pos [incr pos]]
        set cattree($level) $c
        set plevel [expr {$level -1}]
        $cattree($plevel) add $c
        set category($cid) $c
        lappend categories $cid
        #set itemobj [Object new -set name en:index -set title MyTitle -set prefix "" -set suffix ""]
        #$cattree(0) add_to_category -category $c -itemobj $itemobj -orderby title
      }
      
      set sql "category_object_map c, cr_items ci, cr_revisions r, xowiki_page p \
		where c.object_id = ci.item_id and ci.parent_id = $folder_id \
		and ci.content_type not in ('::xowiki::PageTemplate') \
		and category_id in ([join $categories ,]) \
		and r.revision_id = ci.live_revision \
		and p.page_id = r.revision_id"

      if {$except_category_ids ne ""} {
        append sql \
            " and not exists (select * from category_object_map c2 \
		where ci.item_id = c2.object_id \
		and c2.category_id in ($except_category_ids))"
      }
      #ns_log notice "--c category_ids=$category_ids"
      if {$category_ids ne ""} {
        foreach cid [split $category_ids ,] {
          append sql " and exists (select * from category_object_map \
	where object_id = ci.item_id and category_id = $cid)"
        }
      }
      append sql $locale_clause
      
      if {$count} {
        db_foreach get_counts \
            "select count(*) as nr,category_id from $sql group by category_id" {
              $category($category_id) set count $nr
              set s [expr {$summary ? "&summary=$summary" : ""}]
              $category($category_id) href [ad_conn url]?category_id=$category_id$s
              $category($category_id) open_tree
	  }
        append content [$cattree(0) render -tree_style $tree_style]
      } else {
        db_foreach get_pages \
            "select ci.item_id, ci.name, ci.content_type, r.title, category_id from $sql" {
              if {$title eq ""} {set title $name}
              set itemobj [Object new]
              set prefix ""
              set suffix ""
              foreach var {name title prefix suffix} {$itemobj set $var [set $var]}
              $cattree(0) add_to_category \
                  -category $category($category_id) \
                  -itemobj $itemobj \
                  -orderby title \
                  -open_item [expr {$item_id == $open_item_id}]
            }
        append content [$cattree(0) render -tree_style $tree_style]
      }
    }
    return $content
  }

  #############################################################################
  # $Id$
  # display recent entries by categories
  # -gustaf neumann
  #
  # valid parameters from the include are 
  #     tree_name: match pattern, if specified displays only the trees with matching names
  #     max_entries: show given number of new entries
  
  Class create categories-recent \
      -superclass ::xowiki::Portlet \
      -parameter {{title "Recently Changed Pages by Categories"}}

  categories-recent instproc render {} {

    my initialize -parameter {
      {-max_entries:integer 10}
      {-tree_name ""}
      {-locale ""}
    }
    my get_parameters
  
    set cattree [::xowiki::CatTree new -volatile -name "categories-recent"]

    foreach {locale locale_clause} [my locale_clause $package_id $locale] break

    set have_locale [expr {[lsearch [info args category_tree::get_mapped_trees] locale] > -1}]
    set trees [expr {$have_locale ?
                     [category_tree::get_mapped_trees $package_id $locale] :
                     [category_tree::get_mapped_trees $package_id]}]

    foreach tree $trees {
      foreach {tree_id my_tree_name ...} $tree {break}
      if {$tree_name ne "" && ![string match $tree_name $my_tree_name]} continue
      lappend tree_ids $tree_id
    }
    if {[info exists tree_ids]} {
      set tree_select_clause "and c.tree_id in ([join $tree_ids ,])"
    } else {
      set tree_select_clause ""
    }
      
    db_foreach get_pages \
        "select c.category_id, ci.name, r.title, \
	 to_char(r.publish_date,'YYYY-MM-DD HH24:MI:SS') as publish_date \
       from category_object_map_tree c, cr_items ci, cr_revisions r, xowiki_page p \
       where c.object_id = ci.item_id and ci.parent_id = [$package_id folder_id] \
	 and r.revision_id = ci.live_revision \
	 and p.page_id = r.revision_id $tree_select_clause $locale_clause \
         and ci.publish_status <> 'production' \
	 order by r.publish_date desc limit $max_entries \
     " {
       if {$title eq ""} {set title $name}
       set itemobj [Object new]
       set prefix  "$publish_date "
       set suffix  ""
       foreach var {name title prefix suffix} {$itemobj set $var [set $var]}
       if {![info exists categories($category_id)]} {
	 set categories($category_id) [::xowiki::Category new \
                                           -package_id $package_id \
					   -label [category::get_name $category_id $locale]\
					   -level 1]
	 $cattree add  $categories($category_id)
       }
       $cattree add_to_category -category $categories($category_id) -itemobj $itemobj
     }
    return [$cattree render]
  }

  #############################################################################
  #
  # display recent entries 
  #
  
  Class create recent \
      -superclass ::xowiki::Portlet \
      -parameter {{title "Recently Changed Pages"}}
  
  recent instproc render {} {
    ::xowiki::Page requireCSS "/resources/acs-templating/lists.css"

    my initialize -parameter {
      {-max_entries:integer 10}
    }
    my get_parameters
    
    TableWidget t1 -volatile \
        -columns {
          Field date -label "Modification Date"
          AnchorField title -label [_ xowiki.page_title]
        }
    
    db_foreach get_pages \
        "select i.name, r.title, \
                to_char(r.publish_date,'YYYY-MM-DD HH24:MI:SS') as publish_date \
         from cr_items i, cr_revisions r, xowiki_page p \
         where i.parent_id = [$package_id folder_id] \
                and r.revision_id = i.live_revision \
                and p.page_id = r.revision_id \
		and i.publish_status <> 'production' \
                order by r.publish_date desc limit $max_entries\
      " {
        t1 add \
            -title $title \
            -title.href [$package_id pretty_link $name] \
            -date $publish_date
      }
    return [t1 asHTML]
  }


  #############################################################################
  # $Id$
  # display last visited entries 
  # -gustaf neumann
  #
  # valid parameters from the include are 
  #     max_entries: show given number of new entries
  #
  
  Class create last-visited \
      -superclass ::xowiki::Portlet \
      -parameter {{title "Last Visited Pages"}}
  
  last-visited instproc render {} {
    ::xowiki::Page requireCSS "/resources/acs-templating/lists.css"

    my initialize -parameter {
      {-max_entries:integer 20}
    }
    my get_parameters

    TableWidget t1 -volatile \
        -columns {
          AnchorField title -label [_ xowiki.page_title]
        }

    db_foreach get_pages \
        "select r.title,i.name, to_char(x.time,'YYYY-MM-DD HH24:MI:SS') as visited_date  \
           from xowiki_last_visited x, xowiki_page p, cr_items i, cr_revisions r  \
           where x.page_id = i.item_id and i.live_revision = p.page_id  \
	    and r.revision_id = p.page_id and x.user_id = [::xo::cc user_id] \
	    and x.package_id = $package_id  and i.publish_status <> 'production' \
	order by x.time desc limit $max_entries \
      " {
        t1 add \
            -title $title \
            -title.href [$package_id pretty_link $name] 
      }
    return [t1 asHTML]
  }

  #############################################################################
  #
  # list the most popular pages
  #

  Class create most-popular \
      -superclass ::xowiki::Portlet \
      -parameter {{title "Most Popular Pages"}}
  
  most-popular instproc render {} {
    ::xowiki::Page requireCSS "/resources/acs-templating/lists.css"

    my initialize -parameter {
      {-max_entries:integer "10"}
    }
    my get_parameters
   
    TableWidget t1 -volatile \
        -columns {
          AnchorField title -label [_ xowiki.page_title]
          Field count -label Count -html { align right }
        }

    db_foreach get_pages \
        "select sum(x.count), x.page_id, r.title,i.name  \
          from xowiki_last_visited x, xowiki_page p, cr_items i, cr_revisions r  \
          where x.page_id = i.item_id and i.live_revision = p.page_id  and r.revision_id = p.page_id \
            and x.package_id = $package_id and i.publish_status <> 'production' \
            group by x.page_id, r.title, i.name \
            order by sum desc limit $max_entries " \
        {
          t1 add \
              -title $title \
              -title.href [$package_id pretty_link $name] \
              -count $sum
        }
    return [t1 asHTML]
  }

  #############################################################################
  #
  # Show the tags
  #

  Class create tags \
      -superclass ::xowiki::Portlet \
      -parameter {{title "Tags"}}
  
  tags instproc render {} {
    ::xowiki::Page requireCSS "/resources/acs-templating/lists.css"

    my initialize -parameter {
      {-limit:integer 20}
      {-summary:boolean 0}
      {-popular:boolean 0}
    }
    my get_parameters
    
    if {$popular} {
      set label [_ xowiki.popular_tags_label]
      set tag_type ptag
      set sql "select count(*) as nr,tag from xowiki_tags where \
        package_id=$package_id group by tag order by tag limit $limit"
    } else {
      set label [_ xowiki.your_tags_label]
      set tag_type tag 
      set sql "select count(*) as nr,tag from xowiki_tags where \
        user_id=[::xo::cc user_id] and package_id=$package_id group by tag order by tag"
    }
    set content "<h3>$label</h3> <BLOCKQUOTE>"
    set entries [list]
    db_foreach get_counts $sql {
      set s [expr {$summary ? "&summary=$summary" : ""}]
      set href [ad_conn url]?$tag_type=[ad_urlencode $tag]$s
      lappend entries "$tag <a href='$href'>($nr)</a>"
    }
    append content "[join $entries {, }]</BLOCKQUOTE>\n"
    return $content
  }


  #############################################################################
  # presence
  #

  Class create presence \
      -superclass ::xowiki::Portlet \
      -parameter {{__decoration plain}}

  presence instproc render {} {
    my initialize -parameter {
      {-interval "10 minutes"}
      {-max_users:integer 40}
      {-page}
    }
    my get_parameters

    set sql "select user_id,time from xowiki_last_visited \
	where package_id = $package_id "

    if {[info exists page] && $page eq "this"} {
      my instvar __including_page
      append sql "and page_id = [$__including_page item_id] "
      set limit_clause "limit $max_users"
      set what "last on page [$__including_page title]"
    } else {
      append sql "and time > now() - '$interval'::interval "
      set limit_clause ""
      set what "currently in community [$package_id instance_name]"

    }

    append sql "order by time desc $limit_clause"

    set count 0
    set output ""
    db_foreach get_visitors $sql {
      if {[info exists seen($user_id)]} continue
      set seen($user_id) $time
      if {[incr count]>$max_users} {
        set count $max_users
        break
      }

      if {[::xo::cc user_id]>0} { 
        regexp {^([^.]+)[.]} $time _ time
        set pretty_time [util::age_pretty -timestamp_ansi $time \
                             -sysdate_ansi [clock_to_ansi [clock seconds]] \
                             -mode_3_fmt "%d %b %Y, at %X"]
        
        set name [::xo::get_user_name $user_id]
        append output "<TR><TD class='user'>$name</TD><TD class='timestamp'>$pretty_time</TD></TR>\n"
      }
    }
    if {$output ne ""} {set output "<TABLE>$output</TABLE>\n"}
    set users [expr {$count == 0 ? "No users" : "$count users"}]
    return "<DIV id='presence'><H1>$users $what</H1>$output</DIV>"
  }

  #############################################################################
  # this might become some usful stuff for digg
  #

  Class create digg \
      -superclass ::xowiki::Portlet \
      -parameter {{__decoration plain}}

  digg instproc render {} {
    # use "span" to specify parameters to the rss call
    my initialize -parameter {}
    my get_parameters
    my instvar __including_page
    set description [$__including_page set description]
    if {$description eq ""} {
      set description [ad_html_text_convert -from text/html -to text/plain -- \
                           [$__including_page set text]]
    }
    return "<div style='border: 1px solid #a9a9a9; padding: 5px 5px; background: #f8f8f8'>\
	$description</div>"
  }


}
