
namespace eval ::xowiki::portlet {
  Class create ::xowiki::Portlet \
      -superclass ::xo::Context \
      -parameter {{name ""} {title ""} {__decoration "portlet"}}

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
      {-open_page ""}
      {-category_ids ""}
      {-except_category_ids ""}
    }
    
    my get_parameters

    set folder_id [$package_id folder_id]
    set open_item_id [expr {$open_page ne "" ?
                            [CrItem lookup -name $open_page -parent_id $folder_id] : 0}]
    set content ""
    foreach tree [category_tree::get_mapped_trees $package_id] {
      foreach {tree_id my_tree_name ...} $tree {break}
      if {$tree_name ne "" && ![string match $tree_name $my_tree_name]} continue
      if {!$no_tree_name} {
        append content "<h3>$my_tree_name</h3>"
      }
      set categories [list]
      set pos 0
      set cattree(0) [::xowiki::CatTree new -volatile -orderby pos -name $my_tree_name]
      foreach category_info [category_tree::get_tree $tree_id] {
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
    }
    my get_parameters
  
    set cattree [::xowiki::CatTree new -volatile -name "categories-recent"]

    foreach tree [category_tree::get_mapped_trees $package_id] {
      foreach {tree_id my_tree_name ...} $tree {break}
      if {$tree_name ne "" && ![string match $tree_name $my_tree_name]} continue
      lappend trees $tree_id
    }
    if {[info exists trees]} {
      set tree_select_clause "and c.tree_id in ([join $trees ,])"
    } else {
      set tree_select_clause ""
    }
    
    db_foreach get_pages \
        "select c.category_id, i.name, r.title, \
	 to_char(r.publish_date,'YYYY-MM-DD HH24:MI:SS') as publish_date \
       from category_object_map_tree c, cr_items i, cr_revisions r, xowiki_page p \
       where c.object_id = i.item_id and i.parent_id = [$package_id folder_id] \
	 and r.revision_id = i.live_revision \
	 and p.page_id = r.revision_id $tree_select_clause \
         and i.publish_status <> 'production' \
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
					   -label [category::get_name $category_id]\
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

}


