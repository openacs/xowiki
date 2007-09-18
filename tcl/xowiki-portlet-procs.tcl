ad_library {
    XoWiki - define various kind of includelets

    @creation-date 2006-10-10
    @author Gustaf Neumann
    @cvs-id $Id$
}
namespace eval ::xowiki::portlet {
  Class create ::xowiki::Portlet \
      -superclass ::xo::Context \
      -parameter {
        {name ""} 
        {title ""} 
        {__decoration "portlet"} 
        {parameter_declaration {}}
        {id}
      }

  ::xowiki::Portlet proc describe_includelets {portlet_classes} {
    my log "--plc=$portlet_classes "
    foreach cl $portlet_classes {
      set result ""
      append result "{{<b>[namespace tail $cl]</b>"
      foreach p [$cl info parameter] {
        if {[llength $p] != 2} continue
        foreach {name value} $p break
        if {$name eq "parameter_declaration"} {
          foreach pp $value {
            #append result ""
            switch [llength $pp] {
              1 {append result " $pp"}
              2 {
                set v [lindex $pp 1]
                if {$v eq ""} {set v {""}}
                append result " [lindex $pp 0] <em>$v</em>"
              }
            }
            #append result "\n"
          }
        }
      }
      append result "}}\n"
      my set html([namespace tail $cl]) $result
      my describe_includelets [$cl info subclass]
    }
  }
  ::xowiki::Portlet proc available_includelets {} {
    if {[my array exists html]} {my array unset html}
    my describe_includelets [::xowiki::Portlet info subclass]
    set result "<UL>"
    foreach d [lsort [my array names html]] {
      append result "<LI>" [my set html($d)] "</LI>" \n
    }
    append result "</UL>"
    return $result
  }

  ::xowiki::Portlet instproc js_name {} {
    return [string map [list : _ # _] [self]]
  }

  ::xowiki::Portlet instproc self_id {} {
    return [string map [list : _ # _] [self]]
  }
  ::xowiki::Portlet proc html_id {name} {
    # Construct a valid HTML id or name. 
    # For details, see http://www.w3.org/TR/html4/types.html
    #
    # For XOTcl object names, strip first the colons
    set name [string trimleft $name :]
    
    # make sure, the ID starts with characters
    if {![regexp {^[A-Za-z]} $name]} {
      set name id_$name
    }

    # replace unwanted characters
    regsub -all {[^A-Za-z0-9_:.-]} $name _ name
    return $name
  }

  ::xowiki::Portlet proc detail_link {
     {-absolute:boolean false} 
     -package_id 
     -name 
     -instance_attributes
   } {
    array set ia $instance_attributes
    if {[info exists ia(detail_link)] && $ia(detail_link) ne ""} {
      set link $ia(detail_link)
    } else {
      set link [::$package_id pretty_link $name]
    }
    return $link
  }

  ::xowiki::Portlet instproc screen_name {user_id} {
    acs_user::get -user_id $user_id -array user
    return [expr {$user(screen_name) ne "" ? $user(screen_name) : $user(name)}]
  }

  
  ::xowiki::Portlet proc incr_page_order {p} {
    regexp {^(.*[.]?)([^.])$} $p _ prefix suffix
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

  ::xowiki::Portlet proc locale_clause {
    -revisions 
    -items 
    package_id 
    locale
  } {
    set default_locale [$package_id default_locale]
    set system_locale ""

    set with_system_locale [regexp {(.*)[+]system} $locale _ locale]
    if {$locale eq "default"} {
      set locale $default_locale
      set include_system_locale 0
    }
    #my msg "--L with_system_locale=$with_system_locale, locale=$locale, default_locale=$default_locale"

    set locale_clause ""    
    if {$locale ne ""} {
      set locale_clause " and $revisions.nls_language = '$locale'" 
      if {$with_system_locale} {
        set system_locale [lang::system::locale -package_id $package_id]
        #my msg "system_locale=$system_locale, default_locale=$default_locale"
        if {$system_locale ne $default_locale} {
          set locale_clause " and ($revisions.nls_language = '$locale' 
		or $revisions.nls_language = '$system_locale' and not exists
		  (select 1 from cr_items i where i.name = '[string range $locale 0 1]:' || 
		  substring($items.name,4) and i.parent_id = $items.parent_id))"
        }
      } 
    }

    #my msg "--locale $locale, def=$default_locale sys=$system_locale, cl=$locale_clause locale_clause=$locale_clause"
    return [list $locale $locale_clause]
  }

  ::xowiki::Portlet instproc category_clause {category_spec {item_ref p.item_id}} {
    # the category_spec has the syntax "a,b,c|d,e", where the values are category_ids
    # pipe symbols are or-operations, commas are and-operations;
    # no parenthesis are permitted
    set extra_where_clause ""
    set or_names [list]
    set ors [list]
    foreach cid_or [split $category_spec |] {
      set ands [list]
      set and_names [list]
      foreach cid_and [split $cid_or ,] {
        lappend and_names [::category::get_name $cid_and]
        lappend ands "exists (select 1 from category_object_map \
           where object_id = p.item_id and category_id = $cid_and)"
      }
      lappend or_names "[join $and_names { and }]"
      lappend ors "([join $ands { and }])"
    }
    set cnames "[join $or_names { or }]"
    set extra_where_clause "and ([join $ors { or }])"
    #my log "--cnames $category_spec -> $cnames"
    return [list $cnames $extra_where_clause]
  }

  ::xowiki::Portlet instproc require_page {source} {
    if {$source ne ""} {
      my instvar package_id
      set page [$package_id resolve_page $source __m]
      if {$page eq ""} {
        error "Cannot find page '$source'"
      }
      $page destroy_on_cleanup
    } else {
      set page [my set __including_page]
    }
    return $page
  }  

  ::xowiki::Portlet instproc get_page_order {-source -ordered_pages -pages} {
    my instvar page_order pages ordered_pages
    # 
    # first check, if we can load the page_order from the page
    # denoted by source
    #
    if {[info exists source]} {
      set p [my require_page $source]
      if {$p ne ""} {
	array set ia [$p set instance_attributes]
	if {[info exists ia(pages)]} {
	  set pages $ia(pages)
	} elseif {[info exists ia(ordered_pages)]} {
	  set ordered_pages $ia(ordered_pages)
	}
      }
    }
    
    # compute a list of ordered_pages from pages, if necessary
    if {[info exists ordered_pages]} {
      foreach {order page} $ordered_pages {set page_order($page) $order}
    } else {
      set i 0
      foreach page $pages {set page_order($page) [incr i]}
    }
  }
  
}

namespace eval ::xowiki::portlet {
  #############################################################################
  Class create available-includelets \
      -superclass ::xowiki::Portlet \
      -parameter {
        {title "The following includelets can be used in a page"}
      }

  available-includelets instproc render {} {
    my get_parameters
    return [::xowiki::Portlet available_includelets]
  }
}
  
namespace eval ::xowiki::portlet {
  #############################################################################
  # dotlrn style portlet decoration for includelets
  #
  Class ::xowiki::portlet::decoration=portlet -instproc render {} {
    my instvar package_id name title
    set class [namespace tail [my info class]]
    set id [expr {[my exists id] ? "id='[my id]'" : ""}]
    set html [next]
    set link [expr {[string match "*:*" $name] ? 
                    "<a href='[$package_id pretty_link $name]'>$title</a>" : 
                    $title}]
    return [subst [[self class] set template]]
  } -set template [expr {[apm_version_names_compare [ad_acs_version] 5.3.0] == 1 ? 
       {<div class='$class'><div class='portlet-wrapper'><div class='portlet-header'>
	 <div class='portlet-title-no-controls'>$link</div></div>
	 <div $id class='portlet'>$html</div></div></div>
       } : {<div class='$class'><div class='portlet-title'><span>$link</span></div>
        <div $id class='portlet'>[next]</div></div>}
       }]
  Class ::xowiki::portlet::decoration=plain -instproc render {} {
    set class [namespace tail [my info class]]
    set id [expr {[my exists id] ? "id='[my id]'" : ""}]
    return "<div $id class='$class'>[next]</div>"
  }

  Class ::xowiki::portlet::decoration=rightbox -instproc render {} {
    set class [namespace tail [my info class]]
    set id [expr {[my exists id] ? "id='[my id]'" : ""}]
    return "<div class='rightbox'><div $id class='$class'>[next]</div></div>"
  }
}

namespace eval ::xowiki::portlet {

  Class create get \
      -superclass ::xowiki::Portlet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-variable:required }
          {-source ""}
        }}
      } -instproc render {} {
        my get_parameters
        set page [my require_page $source]
        if {[$page exists $variable]} {
          return [$page set $variable]
        } else {
          return "no such variable $variable in page [$page set name]"
        }
      }
 
  Class create creation-date \
      -superclass ::xowiki::Portlet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-source ""}
          {-format "%m-%d-%Y"}
        }}
      } -instproc render {} {
        my get_parameters
        set page [my require_page $source]
        set time [$page set creation_date]
        regexp {^([^.]+)[.]} $time _ time
        return [clock format [clock scan $time] -format $format]
      }

  #############################################################################
  # rss button
  #
  Class create rss-button \
      -superclass ::xowiki::Portlet \
      -parameter {
        {__decoration plain}
        {parameter_declaration {
          {-span "10d"}
          {-name_filter}
          {-entries_of}
          {-title}
        }}
      }

  rss-button instproc render {} {
    my get_parameters
    set href [export_vars -base [$package_id package_url] {{rss $span} name_filter title entries_of}]
    return "<a href=\"$href \" class='rss'>RSS</a>"
  }

  #############################################################################
  # set-parameter "includelet"
  #
  Class create set-parameter \
      -superclass ::xowiki::Portlet \
      -parameter {{__decoration none}}

  set-parameter instproc render {} {
    my get_parameters
    set pl [my set __caller_parameters]
    if {[llength $pl] % 2 == 1} {
      error "no even number of parameters '$pl'"
    }
    foreach {att value} $pl {
      ::xo::cc set_parameter $att $value
    }
    return ""
  }
}

namespace eval ::xowiki::portlet {
  #############################################################################
  # valid parameters for he categories portlet are
  #     tree_name: match pattern, if specified displays only the trees 
  #                with matching names
  #     no_tree_name: if specified, tree names are not displayed
  #     open_page: name (e.g. en:iMacs) of the page to be opened initially
  #     tree_style: boolean, default: true, display based on mktree

  Class create categories \
      -superclass ::xowiki::Portlet \
      -parameter {
        {title "Categories"}
        {parameter_declaration {
          {-tree_name ""}
          {-tree_style:boolean 1}
          {-no_tree_name:boolean 0}
          {-count:boolean 0}
          {-summary:boolean 0}
          {-locale ""}
          {-open_page ""}
          {-order_items_by "title,asc"}
          {-category_ids ""}
          {-except_category_ids ""}
        }}
      }
  
  categories instproc render {} {
    my get_parameters

    set content ""
    set folder_id [$package_id folder_id]
    set open_item_id [expr {$open_page ne "" ?
                [::xo::db::CrClass lookup -name $open_page -parent_id $folder_id] : 0}]

    foreach {locale locale_clause} \
        [::xowiki::Portlet locale_clause -revisions r -items ci $package_id $locale] break

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
      }
      
      set sql "category_object_map c, cr_items ci, cr_revisions r, xowiki_page p \
		where c.object_id = ci.item_id and ci.parent_id = $folder_id \
		and ci.content_type not in ('::xowiki::PageTemplate') \
		and category_id in ([join $categories ,]) \
		and r.revision_id = ci.live_revision \
		and p.page_id = r.revision_id \
                and ci.publish_status <> 'production'"

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
        db_foreach [my qn get_counts] \
            "select count(*) as nr,category_id from $sql group by category_id" {
              $category($category_id) set count $nr
              set s [expr {$summary ? "&summary=$summary" : ""}]
              $category($category_id) href [ad_conn url]?category_id=$category_id$s
              $category($category_id) open_tree
	  }
        append content [$cattree(0) render -tree_style $tree_style]
      } else {
        foreach {orderby direction} [split $order_items_by ,]  break     ;# e.g. "title,asc"
        set increasing [expr {$direction ne "desc"}]
        
        #
        # If we have ltree, we query the order_column from the database, 
        # otherwise we don't retrieve it, but set the Tcl variable page_order empty.
        #
        if {[::xo::db::has_ltree]} {
          set order_column ", p.page_order" 
        } else {
          set order_column ""
          set page_order ""
        }

        db_foreach [my qn get_pages] \
            "select ci.item_id, ci.name, ci.content_type, r.title, category_id $order_column from $sql" {
              if {$title eq ""} {set title $name}
              set itemobj [Object new]
              set prefix ""
              set suffix ""
              foreach var {name title prefix suffix page_order} {$itemobj set $var [set $var]}
              
              $cattree(0) add_to_category \
                  -category $category($category_id) \
                  -itemobj $itemobj \
                  -orderby $orderby \
                  -increasing $increasing \
                  -open_item [expr {$item_id == $open_item_id}]
            }
        append content [$cattree(0) render -tree_style $tree_style]
      }
    }
    return $content
  }
}


namespace eval ::xowiki::portlet {
  #############################################################################
  #
  # display recent entries by categories
  # -gustaf neumann
  #
  # valid parameters from the include are 
  #     tree_name: match pattern, if specified displays only the trees with matching names
  #     max_entries: show given number of new entries
  
  Class create categories-recent \
      -superclass ::xowiki::Portlet \
      -parameter {
        {title "Recently Changed Pages by Categories"}
        {parameter_declaration {
          {-max_entries:integer 10}
          {-tree_name ""}
          {-locale ""}
        }}
      }

  categories-recent instproc render {} {
    my get_parameters
  
    set cattree [::xowiki::CatTree new -volatile -name "categories-recent"]

    foreach {locale locale_clause} \
        [::xowiki::Portlet locale_clause -revisions r -items ci $package_id $locale] break

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
    set sql [::xo::db::sql select \
                 -vars "c.category_id, ci.name, r.title, r.publish_date, \
                        to_char(r.publish_date,'YYYY-MM-DD HH24:MI:SS') as formatted_date" \
                 -from "category_object_map_tree c, cr_items ci, cr_revisions r, xowiki_page p" \
                 -where "c.object_id = ci.item_id and ci.parent_id = [$package_id folder_id] \
	 and r.revision_id = ci.live_revision \
	 and p.page_id = r.revision_id $tree_select_clause $locale_clause \
         and ci.publish_status <> 'production'" \
                 -orderby "publish_date desc" \
                 -limit $max_entries]
    db_foreach [my qn get_pages] $sql {
      if {$title eq ""} {set title $name}
      set itemobj [Object new]
      set prefix  "$formatted_date "
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
}


namespace eval ::xowiki::portlet {
  #############################################################################
  #
  # display recent entries 
  #
  
  Class create recent \
      -superclass ::xowiki::Portlet \
      -parameter {
        {title "Recently Changed Pages"}
        {parameter_declaration {
          {-max_entries:integer 10}
          {-allow_edit:boolean false}
          {-allow_delete:boolean false}
        }}
      }
  
  recent instproc render {} {
    my get_parameters
    ::xowiki::Page requireCSS "/resources/acs-templating/lists.css"
    TableWidget t1 -volatile \
        -set allow_edit $allow_edit \
        -set allow_delete $allow_delete \
        -columns {
          Field date -label "Modification Date"
          if {[[my info parent] set allow_edit]} {
            ImageField_EditIcon edit -label "" -html {style "padding-right: 2px;"}
          }
          AnchorField title -label [::xowiki::Page::slot::title set pretty_name]
          if {[[my info parent] set allow_delete]} {
            ImageField_DeleteIcon delete -label ""
          }
        }
    
    db_foreach [my qn get_pages] \
        [::xo::db::sql select \
             -vars "i.name, r.title, p.page_id, r.publish_date, \
                to_char(r.publish_date,'YYYY-MM-DD HH24:MI:SS') as formatted_date" \
             -from "cr_items i, cr_revisions r, xowiki_page p" \
             -where "i.parent_id = [$package_id folder_id] \
                and r.revision_id = i.live_revision \
                and p.page_id = r.revision_id \
		and i.publish_status <> 'production'" \
             -orderby "publish_date desc" \
             -limit $max_entries ] {

        t1 add \
            -title $title \
            -title.href [$package_id pretty_link $name] \
            -date $formatted_date

        if {$allow_edit} {
          #set page_link [$package_id pretty_link $name]
          #set edit_link [$package_id make_link $page_link edit return_url]
          set p [::xo::db::CrClass get_instance_from_db -item_id 0 -revision_id $page_id]
          $p destroy_on_cleanup
          set page_link [$package_id pretty_link $name]
          set edit_link [$package_id make_link -link $page_link $p edit return_url]
          my log "page_link=$page_link, edit=$edit_link"
          [t1 last_child] set edit.href $edit_link
        }
        if {$allow_delete} {
          if {![info exists p]} {
            set p [::xo::db::CrClass get_instance_from_db -item_id 0 -revision_id $page_id]
            $p destroy_on_cleanup
          }
          set page_link [$package_id pretty_link $name]
          set delete_link [$package_id make_link -link $page_link $p delete return_url]
          [t1 last_child] set delete.href $delete_link
        }
      }
    return [t1 asHTML]
  }
}

namespace eval ::xowiki::portlet {
  #############################################################################
  #
  # display last visited entries 
  #
  
  Class create last-visited \
      -superclass ::xowiki::Portlet \
      -parameter {
        {title "Last Visited Pages"}
        {parameter_declaration {
          {-max_entries:integer 20}
        }}
      }
  
  last-visited instproc render {} {
    my get_parameters
    ::xowiki::Page requireCSS "/resources/acs-templating/lists.css"

    TableWidget t1 -volatile \
        -columns {
          AnchorField title -label [::xowiki::Page::slot::title set pretty_name]
        }

    db_foreach [my qn get_pages] \
       [::xo::db::sql select \
            -vars "r.title,i.name, to_char(time,'YYYY-MM-DD HH24:MI:SS') as visited_date" \
            -from "xowiki_last_visited x, xowiki_page p, cr_items i, cr_revisions r"  \
            -where "x.page_id = i.item_id and i.live_revision = p.page_id  \
	    and r.revision_id = p.page_id and x.user_id = [::xo::cc user_id] \
	    and x.package_id = $package_id  and i.publish_status <> 'production'" \
            -orderby "visited_date desc" \
            -limit $max_entries] \
        {
          t1 add \
              -title $title \
              -title.href [$package_id pretty_link $name] 
        }
    return [t1 asHTML]
  }
}


namespace eval ::xowiki::portlet {
  #############################################################################
  #
  # list the most popular pages
  #

  Class create most-popular \
      -superclass ::xowiki::Portlet \
      -parameter {
        {title "Most Popular Pages"}
        {parameter_declaration {
          {-max_entries:integer "10"}
          {-interval}
        }}
      }
  
  most-popular instproc render {} {
    my get_parameters
    ::xowiki::Page requireCSS "/resources/acs-templating/lists.css"
   
    if {[info exists interval]} {
      # 
      # If we have and interval, we cannot get report the number of visits 
      # for that interval, since we have only the aggregated values in
      # the database.
      #
      my append title " in last $interval"

      TableWidget t1 -volatile \
          -columns {
            AnchorField title -label [::xowiki::Page::slot::title set pretty_name]
            Field users -label Visitors -html { align right }
          }
      set since_condition "and [::xo::db::sql since_interval_condition time $interval]"
      db_foreach [my qn get_pages] \
          [::xo::db::sql select \
               -vars "count(x.user_id) as nr_different_users, x.page_id, r.title,i.name" \
               -from "xowiki_last_visited x, xowiki_page p, cr_items i, cr_revisions r"  \
               -where "x.page_id = i.item_id and i.live_revision = p.page_id  and r.revision_id = p.page_id \
            and x.package_id = $package_id and i.publish_status <> 'production' \
            $since_condition" \
               -groupby "x.page_id, r.title, i.name" \
               -orderby "nr_different_users desc" \
               -limit $max_entries ] {
                 t1 add \
                     -title $title \
                     -title.href [$package_id pretty_link $name] \
                     -users $nr_different_users
               }
    } else {

      TableWidget t1 -volatile \
          -columns {
            AnchorField title -label [::xowiki::Page::slot::title set pretty_name]
            Field count -label Visits -html { align right }
            Field users -label Visitors -html { align right }
          }
      db_foreach [my qn get_pages] \
          [::xo::db::sql select \
               -vars "sum(x.count) as sum, count(x.user_id) as nr_different_users, x.page_id, r.title,i.name"  \
               -from "xowiki_last_visited x, xowiki_page p, cr_items i, cr_revisions r"  \
               -where "x.page_id = i.item_id and i.live_revision = p.page_id  and r.revision_id = p.page_id \
            and x.package_id = $package_id and i.publish_status <> 'production'" \
               -groupby "x.page_id, r.title, i.name" \
               -orderby "sum desc" \
               -limit $max_entries] {
                 t1 add \
                     -title $title \
                     -title.href [$package_id pretty_link $name] \
                     -users $nr_different_users \
                     -count $sum
               }
    }
    return [t1 asHTML]
  }
}

namespace eval ::xowiki::portlet {
  #############################################################################
  #
  # Display unread items
  #
  # Currently moderately useful
  # 
  # TODO: display of unread *revisions* should be included optionally, one has to
  # consider what to do with auto-created stuff (put it into 'production' state?)
  # 

  Class create unread-items \
      -superclass ::xowiki::Portlet \
      -parameter {
        {title "Unread Items"}
        {parameter_declaration {
          {-max_entries:integer 20}
        }}
      }
  
  unread-items instproc render {} {
    my get_parameters
    ::xowiki::Page requireCSS "/resources/acs-templating/lists.css"

    TableWidget t1 -volatile \
        -columns {
          AnchorField title -label [::xowiki::Page::slot::title set pretty_name]
        }

    set or_clause "or i.item_id in (select x.page_id from xowiki_last_visited x, acs_objects o  \
      where x.time < o.last_modified and x.page_id = o.object_id and x.package_id = $package_id)
"

    db_foreach [my qn get_pages] \
       [::xo::db::sql select \
            -vars "a.title, i.name" \
            -from "xowiki_page p, cr_items i, acs_objects a "  \
            -where "(i.item_id not in (select x.page_id from xowiki_last_visited x 
                        where x.user_id = [::xo::cc user_id] and  x.package_id = $package_id) 
                    $or_clause
                    )
                    and i.live_revision = p.page_id 
                    and i.parent_id = [$package_id folder_id] 
                    and i.publish_status <> 'production'
                    and a.object_id = i.item_id" \
            -orderby "a.creation_date desc" \
            -limit $max_entries] \
        {
          t1 add \
              -title $title \
              -title.href [$package_id pretty_link $name] 
        }
    return [t1 asHTML]
  }
}




namespace eval ::xowiki::portlet {
  #############################################################################
  #
  # Show the tags
  #

  Class create tags \
      -superclass ::xowiki::Portlet \
      -parameter {
        {title "Tags"}
        {parameter_declaration {
          {-limit:integer 20}
          {-summary:boolean 0}
          {-popular:boolean 0}
          {-page}
        }}
      }
  
  tags instproc render {} {
    my get_parameters
    ::xowiki::Page requireCSS "/resources/acs-templating/lists.css"

    if {$popular} {
      set label [_ xowiki.popular_tags_label]
      set tag_type ptag
      set sql [::xo::db::sql select \
                   -vars "count(*) as nr,tag" \
                   -from xowiki_tags \
                   -where "package_id=$package_id" \
                   -groupby tag \
                   -orderby tag \
                   -limit $limit]
    } else {
      set label [_ xowiki.your_tags_label]
      set tag_type tag 
      set sql "select count(*) as nr,tag from xowiki_tags where \
        user_id=[::xo::cc user_id] and package_id=$package_id group by tag order by tag"
    }
    set entries [list]

    if {![info exists page]} {set page  [$package_id get_parameter weblog_page]}
    set base_url [$package_id pretty_link $page]

    db_foreach [my qn get_counts] $sql {
      set s [expr {$summary ? "&summary=$summary" : ""}]
      set href $base_url?$tag_type=[ad_urlencode $tag]$s
      lappend entries "$tag <a href='$href'>($nr)</a>"
    }
    return [expr {[llength $entries]  > 0 ? 
                  "<h3>$label</h3> <BLOCKQUOTE>[join $entries {, }]</BLOCKQUOTE>\n" :
                  ""}]
  }

  Class create my-tags \
      -superclass ::xowiki::Portlet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-summary 1}
        }}
        id
      }
  
  my-tags instproc render {} {
    my get_parameters
    my instvar __including_page tags
    ::xowiki::Page requireJS  "/resources/xowiki/get-http-object.js"
    
    set p_link [$package_id pretty_link [$__including_page name]]
    set return_url "[::xo::cc url]?[::xo::cc actual_query]"
    set weblog_page [$package_id get_parameter weblog_page weblog]
    set save_tag_link [$package_id make_link -link $p_link $__including_page \
                           save-tags return_url]
    set popular_tags_link [$package_id make_link -link $p_link $__including_page \
                               popular-tags return_url weblog_page]

    set tags [lsort [::xowiki::Page get_tags -user_id [::xo::cc user_id] \
                         -item_id [$__including_page item_id] -package_id $package_id]]
    set href [$package_id package_url]$weblog_page?summary=$summary

    set entries [list]
    foreach tag $tags {lappend entries "<a href='$href&tag=[ad_urlencode $tag]'>$tag</a>"}
    set tags_with_links [join [lsort $entries] {, }]

    if {![my exists id]} {my set id [::xowiki::Portlet html_id [self]]}
    set content [subst -nobackslashes {
      #xowiki.your_tags_label#: $tags_with_links
      (<a href='#' onclick='document.getElementById("[my id]-edit_tags").style.display="inline";return false;'>#xowiki.edit_link#</a>,
       <a href='#' onclick='get_popular_tags("$popular_tags_link","[my id]");return false;'>#xowiki.popular_tags_link#</a>)
      <span id='[my id]-edit_tags' style='display: none'>
      <FORM action="$save_tag_link" method='POST'>
        <INPUT name='new_tags' type='text' value="$tags">
      </FORM>
      </span>
      <span id='[my id]-popular_tags' style='display: none'></span><br/>
    }]
    return $content
  }

  
  Class create my-categories \
      -superclass ::xowiki::Portlet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-summary 1}
        }}
      }
  
  my-categories instproc render {} {
    my get_parameters
    my instvar __including_page
    set content ""

    set weblog_page [$package_id get_parameter weblog_page weblog]
    set entries [list]
    set href [$package_id package_url]$weblog_page?summary=$summary
    set notification_type ""
    if {[$package_id get_parameter "with_notifications" 1] &&
        [::xo::cc user_id] != 0} { ;# notifications require login
      set notification_type [notification::type::get_type_id -short_name xowiki_notif]
    }
    if {[$package_id exists_query_parameter return_url]} {
      set return_url [$package_id query_parameter return_url]
    }
    foreach cat_id [category::get_mapped_categories [$__including_page set item_id]] {
      foreach {category_id category_name tree_id tree_name} [category::get_data $cat_id] break
      #my log "--cat $cat_id $category_id $category_name $tree_id $tree_name"
      set entry "<a href='$href&category_id=$category_id'>$category_name ($tree_name)</a>"
      if {$notification_type ne ""} {
        set notification_text "Subscribe category $category_name in tree $tree_name"
        set notifications_return_url [expr {[info exists return_url] ? $return_url : [ad_return_url]}]
        set notification_image \
            "<img style='border: 0px;' src='/resources/xowiki/email.png' \
   	     alt='$notification_text' title='$notification_text'>"

        set cat_notif_link [export_vars -base /notifications/request-new \
                                {{return_url $notifications_return_url} \
                                     {pretty_name $notification_text} \
                                     {type_id $notification_type} \
                                     {object_id $category_id}}]
        append entry "<a href='$cat_notif_link'> " \
                         "<img style='border: 0px;' src='/resources/xowiki/email.png' " \
                         "alt='$notification_text' title='$notification_text'>" </a>

      }
      lappend entries $entry
    }
    if {[llength $entries]>0} {
      set content "Categories: [join $entries {, }]"
    }
    return $content
  }

  Class create my-general-comments \
      -superclass ::xowiki::Portlet \
      -parameter {{__decoration none}}
  
  my-general-comments instproc render {} {
    my get_parameters
    my instvar __including_page
    set item_id [$__including_page item_id] 
    set gc_return_url [$package_id url]
    set gc_link     [general_comments_create_link \
                         -object_name [$__including_page title] \
                         $item_id $gc_return_url]
    set gc_comments [general_comments_get_comments $item_id $gc_return_url]
    if {$gc_comments ne ""} {
      return "<p>#general-comments.Comments#<ul>$gc_comments</ul></p><p>$gc_link</p>"
    } else {
      return "<p>#general-comments.lt_No_comments_available#</p><p>$gc_link</p>"
    }
  }
  
  Class create digg \
      -superclass ::xowiki::Portlet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-description ""}
          {-url}
        }}
      }
  
  digg instproc render {} {
    my get_parameters
    my instvar __including_page
    set digg_link [export_vars -base "http://digg.com/submit" {
      {phase 2} 
      {url       $url}
      {title     "[string range [$__including_page title] 0 74]"}
      {body_text "[string range $description 0 349]"}
    }]
    return "<a href='$digg_link'><img src='http://digg.com/img/badges/100x20-digg-button.png' width='100' height='20' alt='Digg!' border='1'/></a>"
  }

  Class create delicious \
      -superclass ::xowiki::Portlet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-description ""}
          {-tags ""}
          {-url}
        }}
      }
  
  delicious instproc render {} {
    my get_parameters
    my instvar __including_page

    # the following opens a window, where a user can edit the posted info.
    # however, it seems not possible to add tags this way automatically.
    # Alternatively, one could use the api as descibed below; this allows
    # tags, but no editing...
    # http://farm.tucows.com/blog/_archives/2005/3/24/462869.html#adding

    set delicious_link [export_vars -base "http://del.icio.us/post" {
      {v 4}
      {url   $url}
      {title "[string range [$__including_page title] 0 79]"}
      {notes "[string range $description 0 199]"}
      tags
    }]
    return "<a href='$delicious_link'><img src='http://i.i.com.com/cnwk.1d/i/ne05/fmwk/delicious_14x14.gif' width='14' height='14' border='0' alt='Add to your del.icio.us' />del.icio.us</a>"
  }


  Class create my-yahoo-publisher \
      -superclass ::xowiki::Portlet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-publisher ""}
          {-rssurl}
        }}
      }
  
  my-yahoo-publisher instproc render {} {
    my get_parameters
    my instvar __including_page

    set publisher [ad_urlencode $publisher]
    set feedname  [ad_urlencode [[$package_id folder_id] title]]
    set rssurl    [ad_urlencode $rssurl]
    set my_yahoo_link "http://us.rd.yahoo.com/my/atm/$publisher/$feedname/*http://add.my.yahoo.com/rss?url=$rssurl"

    return "<a href='$my_yahoo_link'><img src='http://us.i1.yimg.com/us.yimg.com/i/us/my/addtomyyahoo4.gif' width='91' height='17' border='0' align='middle' alt='Add to My Yahoo!'></a>"
  }

  Class create my-references \
      -superclass ::xowiki::Portlet \
      -parameter {{__decoration none}}
  
  my-references instproc render {} {
    my get_parameters
    my instvar __including_page

    set item_id [$__including_page item_id] 
    set refs [list]
    db_foreach [my qn get_references] "SELECT page,ci.name,f.package_id \
        from xowiki_references,cr_items ci,cr_folders f \
        where reference=$item_id and ci.item_id = page and ci.parent_id = f.folder_id" {
          ::xowiki::Package require $package_id
          lappend refs "<a href='[$package_id pretty_link $name]'>$name</a>"
        }
    set references [join $refs ", "]

    array set lang {found "" undefined ""}
    foreach i [$__including_page array names lang_links] {
      set lang($i) [join [$__including_page set lang_links($i)] ", "]
    }
    append references " " $lang(found)
    set result ""
    if {$references ne " "} {
      append result "#xowiki.references_label# $references"
    }
    if {$lang(undefined) ne ""} {
      append result "#xowiki.create_this_page_in_language# $lang(undefined)"
    }
    return $result
  }

}

namespace eval ::xowiki::portlet {
  #############################################################################
  # presence
  #
  Class create presence \
      -superclass ::xowiki::Portlet \
      -parameter {
        {__decoration rightbox}
        {parameter_declaration {
          {-interval "10 minutes"}
          {-max_users:integer 40}
          {-show_anonymous "summary"}
          {-page}
        }}
      }

  # TODO make display style -decoration

  presence instproc render {} {
    my get_parameters

    set summary 0
    if {[::xo::cc user_id] == 0} {
      switch -- $show_anonymous {
        nothing {return ""}
        all     {set summary 0} 
        default {set summary 1} 
      }
    }

    if {[info exists page] && $page eq "this"} {
      my instvar __including_page
      set extra_where_clause "and page_id = [$__including_page item_id] "
      set what " on page [$__including_page title]"
    } else {
      set extra_where_clause ""
      set what " in community [$package_id instance_name]"
    }

    if {!$summary} {
      set select_users "user_id, to_char(max(time),'YYYY-MM-DD HH24:MI:SS') as max_time from xowiki_last_visited "
    }
    set since_condition [::xo::db::sql since_interval_condition time $interval]
    set where_clause "package_id=$package_id and $since_condition $extra_where_clause"
    set when "<br>in last $interval"

    set output ""

    if {$summary} {
      set count [db_string [my qn presence_count_users] \
                     "select count(distinct user_id) from xowiki_last_visited WHERE $where_clause"]
    } else {
      set values [db_list_of_lists [my qn get_users] \
                      [::xo::db::sql select \
                           -vars "user_id, to_char(max(time),'YYYY-MM-DD HH24:MI:SS') as max_time" \
                           -from xowiki_last_visited \
                           -where $where_clause \
                           -groupby user_id \
                           -orderby "max_time desc" \
                           -limit $max_users ]]
      set count [llength $values]
      if {$count == $max_users} {
        # we have to check, whether there were more users...
        set count [db_string [my qn presence_count_users] "$select_count $where_clause"] 
      }
      foreach value  $values {
        foreach {user_id time} $value break
        set seen($user_id) $time
        
        regexp {^([^.]+)[.]} $time _ time
        set pretty_time [util::age_pretty -timestamp_ansi $time \
                             -sysdate_ansi [clock_to_ansi [clock seconds]] \
                             -mode_3_fmt "%d %b %Y, at %X"]
        set name [::xo::get_user_name $user_id]

        append output "<TR><TD class='user'>$name</TD><TD class='timestamp'>$pretty_time</TD></TR>\n"
      }
      if {$output ne ""} {set output "<TABLE>$output</TABLE>\n"}
    }
    set users [expr {$count == 0 ? "No registered users" : 
                     $count == 1 ? "1 registered user" : 
                     "$count registered users"}]
    return "<H1>$users$what$when</H1>$output"
  }
}


namespace eval ::xowiki::portlet {
  #############################################################################
  # portlets based on order
  #
  Class create toc \
      -superclass ::xowiki::Portlet \
      -parameter {
        {__decoration plain}
        {parameter_declaration {
          {-style ""} 
          {-open_page ""}
          {-book_mode false}
          {-ajax true}
          {-expand_all false}
          {-remove_levels 0}
          {-category_id}
          {-locale ""}
          {-source ""}
        }}
        id
      }

#"select page_id,  page_order, name, title, \
#	(select count(*)-1 from xowiki_page_live_revision where page_order <@ p.page_order) as count \
#	from xowiki_page_live_revision p where not page_order is NULL order by page_order asc"

  toc instproc count {} {return [my set navigation(count)]}
  toc instproc current {} {return [my set navigation(current)]}
  toc instproc position {} {return [my set navigation(position)]}
  toc instproc page_name {p} {return [my set page_name($p)]}

  toc proc anchor {name} {
    # try to strip the language prefix from the name
    regexp {^.*:([^:]+)$} $name _ name
    # anchor is used between single quotes
    regsub -all ' $name {\'} anchor
    return $anchor
  }

  toc instproc get_nodes {open_page package_id expand_all remove_levels locale source} {
    my instvar navigation page_name book_mode
    array set navigation {parent "" position 0 current ""}

    set js ""
    set node() root
    set node_cnt 0

    set extra_where_clause ""
    if {[my exists category_id]} {
      foreach {cnames extra_where_clause} [my category_clause [my set category_id]] break
    }
    foreach {locale locale_clause} \
        [::xowiki::Portlet locale_clause -revisions p -items p $package_id $locale] break
    #my msg locale_clause=$locale_clause

    if {$source ne ""} {
      my get_page_order -source $source
      set page_names ('[join [my array names page_order] ',']')
      set page_order_clause "and name in $page_names"
      set page_order_att ""
    } else {
      set page_order_clause "and not page_order is NULL"
      set page_order_att "page_order,"
    }

    set sql [::xo::db::sql select \
                 -vars "page_id, $page_order_att name, title" \
                 -from "xowiki_page_live_revision p" \
                 -where "parent_id=[$package_id folder_id] \
			$page_order_clause \
			$extra_where_clause $locale_clause"]
    set pages [::xowiki::Page instantiate_objects -sql $sql]

    if {$source ne ""} {
      # add the page_order to the objects
      foreach p [$pages children] {
	$p set page_order [my set page_order([$p set name])]
      }
    }

    $pages mixin add ::xo::OrderedComposite::IndexCompare
    $pages orderby page_order

    my set jsobjs ""
    #my log "--book read [llength [$pages children]] pages"

    foreach o [$pages children] {
      $o instvar page_order title page_id name title 

      #my log "o: $page_order"
      set displayed_page_order $page_order
      for {set i 0} {$i < $remove_levels} {incr i} {
	regsub {^[^.]+[.]} $displayed_page_order "" displayed_page_order
      }
      set label "$displayed_page_order $title"
      set id tmpNode[incr node_cnt]
      set node($page_order) $id
      set jsobj [my js_name].objs\[$node_cnt\]

      set page_name($node_cnt) $name
      if {![regexp {^(.*)[.]([^.]+)} $page_order _ parent]} {set parent ""}

      if {$book_mode} {
	set href [$package_id url]#[toc anchor $name]
      } else {
	set href [$package_id pretty_link $name]
      }
      
      if {$expand_all} {
	set expand "true"
      } else {
	set expand [expr {$open_page eq $name} ? "true" : "false"]
	if {$expand} {
	  set navigation(parent) $parent
	  set navigation(position) $node_cnt
	  set navigation(current) $page_order
	  for {set p $parent} {$p ne ""} {} {
	    if {![info exists node($p)]} break
	    append js "$node($p).expand();\n"
	    if {![regexp {^(.*)[.]([^.]+)} $p _ p]} {set p ""}
	  }
	}
      }
      set parent_node [expr {[info exists node($parent)] ? $node($parent) : "root"}]
      set refvar [expr {[my set ajax] ? "ref" : "href"}]
      regsub -all {\"} $label {\"} label
      #my log "$jsobj = {label: \"$label\", id: \"$id\", $refvar: \"$href\",  c: $node_cnt};"
      append js \
	  "$jsobj = {label: \"$label\", id: \"$id\", $refvar: \"$href\",  c: $node_cnt};" \
	  "var $node($page_order) = new YAHOO.widget.TextNode($jsobj, $parent_node, $expand);\n" \
          ""
      my lappend jsobjs $jsobj

    }
    set navigation(count) $node_cnt
    #my log "--COUNT=$node_cnt"
    return $js
  }

  toc instproc ajax_tree {js_tree_cmds} {
    return "<div id='[my id]'>
      <script type = 'text/javascript'>
      var [my js_name] = {

         count: [my set navigation(count)],

         getPage: function(href, c) {
             //  console.log('getPage: ' + href + ' type: ' + typeof href) ;

             if ( typeof c == 'undefined' ) {

                 // no c given, search it from the objects
                 // console.log('search for href <' + href + '>');

                 for (i in this.objs) {
                     if (this.objs\[i\].ref == href) {
                        c = this.objs\[i\].c;
                        // console.log('found href ' + href + ' c=' + c);
                        var node = this.tree.getNodeByIndex(c);
                        if (!node.expanded) {node.expand();}
                        node = node.parent;
                        while (node.index > 1) {
                            if (!node.expanded) {node.expand();}
                            node = node.parent;
                        }
                        break;
                     }
                 }
                 if (typeof c == 'undefined') {
                     // console.warn('c undefined');
                     return false;
                 }
             }
             // console.log('have href ' + href + ' c=' + c);

             var transaction = YAHOO.util.Connect.asyncRequest('GET', \
                 href + '?template_file=view-page&return_url=' + href, 
                {
                  success:function(o) {
                     var bookpage = document.getElementById('book-page');
     		     var fadeOutAnim = new YAHOO.util.Anim(bookpage, { opacity: {to: 0} }, 0.5 );

                     var doFadeIn = function(type, args) {
                        // console.log('fadein starts');
                        var bookpage = document.getElementById('book-page');
                        bookpage.innerHTML = o.responseText;
                        var fadeInAnim = new YAHOO.util.Anim(bookpage, { opacity: {to: 1} }, 0.1 );
                        fadeInAnim.animate();
                     }

                     // console.log(' tree: ' + this.tree + ' count: ' + this.count);
                     // console.info(this);

                     if (this.count > 0) {
                        var percent = (100 * o.argument / this.count).toFixed(2) + '%';
                     } else {
                        var percent = '0.00%';
                     }

                     if (o.argument > 1) {
                        var link = this.objs\[o.argument - 1 \].ref;
                        var src = '/resources/xowiki/previous.png';
                        var onclick = 'return [my js_name].getPage(\"' + link + '\");' ;
                     } else {
                        var link = '#';
                        var onclick = '';
                        var src = '/resources/xowiki/previous-end.png';
                     }

                     // console.log('changing prev href to ' + link);
                     // console.log('changing prev onclick to ' + onclick);

                     document.getElementById('bookNavPrev.img').src = src;
                     document.getElementById('bookNavPrev.a').href = link;
                     document.getElementById('bookNavPrev.a').setAttribute('onclick',onclick);

                     if (o.argument < this.count) {
                        var link = this.objs\[o.argument + 1 \].ref;
                        var src = '/resources/xowiki/next.png';
                        var onclick = 'return [my js_name].getPage(\"' + link + '\");' ;
                     } else {
                        var link = '#';
                        var onclick = '';
                        var src = '/resources/xowiki/next-end.png';
                     }

                     // console.log('changing next href to ' + link);
                     // console.log('changing next onclick to ' + onclick);
                     document.getElementById('bookNavNext.img').src = src;
                     document.getElementById('bookNavNext.a').href = link;

                     document.getElementById('bookNavNext.a').setAttribute('onclick',onclick);
                     document.getElementById('bookNavRelPosText').innerHTML = percent;
                     document.getElementById('bookNavBar').setAttribute('style', 'width: ' + percent + ';');

                     fadeOutAnim.onComplete.subscribe(doFadeIn);
  		     fadeOutAnim.animate();
                  }, 
                  failure:function(o) {
                     // console.error(o);
                     // alert('failure ');
                     return false;
                  },
                  argument: c,
                  scope: [my js_name]
                }, null);

                return false;
            },


         treeInit: function() { 
            [my js_name].tree = new YAHOO.widget.TreeView('[my id]'); 
            root = [my js_name].tree.getRoot(); 
            [my js_name].objs = new Array();
            $js_tree_cmds

            [my js_name].tree.subscribe('labelClick', function(node) {
              [my js_name].getPage(node.data.ref, node.data.c); });
            [my js_name].tree.draw();
         }

      };

     YAHOO.util.Event.addListener(window, 'load', [my js_name].treeInit);
      </script>
    </div>"
  }

  toc instproc tree {js_tree_cmds} {
    return "<div id='[my id]'>
      <script type = 'text/javascript'>
      var [my js_name] = {

         getPage: function(href, c) { return true; },

         treeInit: function() { 
            [my js_name].tree = new YAHOO.widget.TreeView('[my id]'); 
            root = [my js_name].tree.getRoot(); 
            [my js_name].objs = new Array();
            $js_tree_cmds
            [my js_name].tree.draw();
         }
      };
      YAHOO.util.Event.on(window, 'load', [my js_name].treeInit);
      </script>
    </div>"
  }


  toc instproc render {} {
    my get_parameters

    switch -- $style {
      "menu" {set s "menu/"}
      "folders" {set s "folders/"}
      "default" {set s ""}
    }
    ::xowiki::Page requireCSS "/resources/ajaxhelper/yui/treeview/assets/${s}tree.css"
    ::xowiki::Page requireJS "/resources/ajaxhelper/yui/yahoo/yahoo.js"
    ::xowiki::Page requireJS "/resources/ajaxhelper/yui/event/event.js"
    if {$ajax} {
       ::xowiki::Page requireJS "/resources/ajaxhelper/yui/dom/dom.js"             ;# ANIM
       ::xowiki::Page requireJS "/resources/ajaxhelper/yui/connection/connection.js"
       ::xowiki::Page requireJS "/resources/ajaxhelper/yui/animation/animation.js" ;# ANIM
    }  
    ::xowiki::Page requireJS "/resources/ajaxhelper/yui/treeview/treeview.js"

    my set book_mode $book_mode
    if {!$book_mode} {
      ###### my set book_mode [[my set __including_page] exists __is_book_page]
    } elseif $ajax {
      #my log "--warn: cannot use bookmode with ajax, resetting ajax"
      set ajax 0
    }
    my set ajax $ajax
    if {![my exists id]} {my set id [::xowiki::Portlet html_id [self]]}
    if {[info exists category_id]} {my set category_id $category_id}
            
    set js_tree_cmds [my get_nodes $open_page $package_id $expand_all \
                          $remove_levels $locale $source]
    return [expr {$ajax ? [my ajax_tree $js_tree_cmds ] : [my tree $js_tree_cmds ]}]
  }

  #############################################################################
  # Selection
  #
  # TODO: base book (and toc) on selection
  Class create selection \
      -superclass ::xowiki::Portlet \
      -parameter {
        {__decoration plain}
        {parameter_declaration {
          {-edit_links:boolean true}
          {-pages ""}
          {-ordered_pages ""}
          {-source}
          {-menu_buttons edit}
        }}
      }

  selection instproc render {} {
    my instvar page_order
    my get_parameters
    my set package_id $package_id
    my set edit_links $edit_links

    if {[info exists source]} {
      my get_page_order -source $source
    } else {
      my get_page_order -pages $pags -ordered_pages $ordered_pages
    }

    # should check for quotes in names
    set page_names ('[join [array names page_order] ',']')
    set pages [::xowiki::Page instantiate_objects -sql \
                   "select page_id, name, title, item_id \
		from xowiki_page_live_revision p \
		where parent_id = [$package_id folder_id] \
		and name in $page_names \
		[::xowiki::Page container_already_rendered item_id]" ]
    foreach p [$pages children] {
      $p set page_order $page_order([$p set name])
    }
    
    $pages mixin add ::xo::OrderedComposite::IndexCompare
    $pages orderby page_order
    return [my render_children $pages $menu_buttons]
  }

  selection instproc render_children {pages menu_buttons} {
    my instvar package_id edit_links
    foreach o [$pages children] {
      $o instvar page_order title page_id name title
      set level [expr {[regsub {[.]} $page_order . page_order] + 1}] 
      set edit_markup ""
      set p [::xo::db::CrClass get_instance_from_db -item_id 0 -revision_id $page_id]
      $p destroy_on_cleanup
      $p set unresolved_references 0
      
      switch [$p info class] {
        ::xowiki::Form {
          set content [$p render]
        }
        default { 
          set content [$p get_content]
          set content [string map [list "\{\{" "\\\{\{"] $content]
        }
      }

      set menu [list]
      foreach b $menu_buttons {
	if {[info command ::xowiki::portlet::$b] eq ""} {
	  set b $b-item-button
	}
	set html [$p include_portlet [list $b -book_mode true]]
	if {$html ne ""} {lappend menu $html}
      }
      append output "<h$level class='book'>" \
          "<div style='float: right'>" [join $menu "&nbsp;"] "</div>" \
          "<a name='[toc anchor $name]'></a>$page_order $title</h$level>" \
          $content
    }
    return $output
  }

  Class create composite-form \
      -superclass ::xowiki::portlet::selection \
      -parameter {
        {parameter_declaration {
          {-edit_links:boolean false}
          {-pages ""}
          {-ordered_pages}
        }}
      }

  composite-form instproc render {} {
    my get_parameters
    my instvar __including_page
    set inner_html [next]
    #my log "innerhtml=$inner_html"
    regsub -nocase -all "<form " $inner_html "<div class='form' " inner_html
    regsub -nocase -all "<form>" $inner_html "<div class='form'>" inner_html
    regsub -nocase -all "</form *>" $inner_html "</div>" inner_html
    dom parse -simple -html <form>$inner_html</form> doc
    $doc documentElement root

    set fields [$root selectNodes "//div\[@class = 'wiki-menu'\]"]
    foreach field $fields {$field delete}

    set inner_html [$root asHTML]
    set id ID[$__including_page item_id]
    set base [$package_id pretty_link [$__including_page name]]
    #set id ID$item_id
    #$root setAttribute id $id
    set as_att_value [string map [list & "&amp;" < "&lt;" > "&gt;" \" "&quot;" ' "&apos;"] $inner_html]

    set save_form [subst {
      <p>
      <a href='#' onclick='document.getElementById("$id").style.display="inline";return false;'>Create Form from Content</a>
      </p>
      <span id='$id' style='display: none'>
      Form Name: 
      <FORM action="$base?m=create-new" method='POST' style='display: inline'>
         <INPUT name='class' type='hidden' value="::xowiki::Form">
         <INPUT name='content' type='hidden' value="$as_att_value">
         <INPUT name='name' type='text'>
      </FORM>
      </span>
    }]

    return $inner_html$save_form
  }

  #############################################################################
  # book style
  #
  Class create book \
      -superclass ::xowiki::Portlet \
      -parameter {
        {__decoration plain}
        {parameter_declaration {
          {-category_id}
          {-menu_buttons edit}
          {-locale ""}
        }}
      }

  book instproc render {} {
    my get_parameters

    my instvar __including_page
    lappend ::xowiki_page_item_id_rendered [$__including_page item_id]
    $__including_page set __is_book_page 1

    set extra_where_clause ""
    set cnames ""
    if {[info exists category_id]} {
      foreach {cnames extra_where_clause} [my category_clause $category_id] break
    }

    foreach {locale locale_clause} \
        [::xowiki::Portlet locale_clause -revisions p -items p $package_id $locale] break

    set pages [::xowiki::Page instantiate_objects -sql \
        "select page_id, page_order, name, title, item_id \
		from xowiki_page_live_revision p \
		where parent_id = [$package_id folder_id] \
		and not page_order is NULL $extra_where_clause \
		$locale_clause \
		[::xowiki::Page container_already_rendered item_id]" ]
    $pages mixin add ::xo::OrderedComposite::IndexCompare
    $pages orderby page_order

    set output ""
    if {$cnames ne ""} {
      append output "<div class='filter'>Filtered by categories: $cnames</div>"
    }
    set return_url [::xo::cc url]

    foreach o [$pages children] {
      $o instvar page_order title page_id name title 
      set level [expr {[regsub -all {[.]} $page_order . page_order] + 1}]
      set p [::xo::db::CrClass get_instance_from_db -item_id 0 -revision_id $page_id]
      $p destroy_on_cleanup

      $p set unresolved_references 0
      #$p set render_adp 0
      switch [$p info class] {
        ::xowiki::Form {
          set content [$p render]
        }
        default { 
          set content [$p get_content]
          set content [string map [list "\{\{" "\\\{\{"] $content]
        }
      }
      set menu [list]
      foreach b $menu_buttons {
	if {[info command ::xowiki::portlet::$b] eq ""} {
	  set b $b-item-button
	}
	set html [$p include_portlet [list $b -book_mode true]]
	if {$html ne ""} {lappend menu $html}
      }
      set menu [join $menu "&nbsp;"]
      if {$menu ne ""} {
        # <div> not allowed in h*: style='float: right; position: relative; top: -32px
        set menu "<span style='float: right;'>$menu</span>"
      }

      append output \
          "<h$level class='book'>" $menu \
          "<a name='[toc anchor $name]'></a>$page_order $title</h$level>" \
          $content
    }
    return $output
  }
}

namespace eval ::xowiki::portlet {
  Class create item-button \
      -superclass ::xowiki::Portlet \
      -parameter {
        {__decoration none}
      }

  item-button instproc render_button {
    -page 
    -package_id
    -method 
    -src 
    -alt 
    -title 
    -return_url 
    -page_order
    -object_type
    -source_item_id
  } {
    set html ""
    if {![info exists return_url]} {set return_url $p_link}
    if {![info exists alt]} {set alt $method}
    if {![info exists src]} {set src [my set src]}
    if {[$page istype ::xowiki::Package]} {
      set link  [$package_id make_link $package_id edit-new object_type \
		     return_url page_order source_item_id]
    } else {
      set p_link [$package_id pretty_link [$page name]]
      set link [$package_id make_link -link $p_link $page $method \
		    return_url page_order source_item_id]
    }

    if {$link ne ""} {
      set html "<a href=\"$link\"><image src='$src' border='0' alt=\"$alt\" title=\"$title\"></a>"
    }
    return $html
  }

  Class create edit-item-button -superclass ::xowiki::portlet::item-button \
      -parameter {
        {parameter_declaration {
          {-page_id}
          {-title "#xowiki.edit#"}
          {-alt "edit"}
          {-book_mode false}
        }}
      }
  
  edit-item-button instproc render {} {
    my get_parameters
    my instvar __including_page
    set page [expr {[info exists page_id] ? $page_id : $__including_page}]
    if {[$page istype ::xowiki::FormPage]} {
      set template [$page page_template]
      set title "$title [$template title] [$page name]"
    }
    set return_url [::xo::cc url]
    if {$book_mode} {
      append return_url #[toc anchor [$page name]]
    }
    return [my render_button \
		-page $page -method edit -package_id $package_id \
		-title $title -alt $alt -return_url $return_url \
		-src /resources/acs-subsite/Edit16.gif]
  }

  Class create delete-item-button -superclass ::xowiki::portlet::item-button \
      -parameter {
        {__decoration none}
        {src /resources/acs-subsite/Delete16.gif}
        {parameter_declaration {
          {-page_id}
          {-title "#xowiki.delete#"}
          {-alt "delete"}
          {-book_mode false}
        }}
      }

  delete-item-button instproc render {} {
    my get_parameters
    my instvar __including_page
    set page [expr {[info exists page_id] ? $page_id : $__including_page}]
    return [my render_button \
		  -page $page -method delete -package_id $package_id \
		  -title $title -alt $alt \
		  -return_url [::xo::cc url]]
  }

  Class create create-item-button -superclass ::xowiki::portlet::item-button \
      -parameter {
        {__decoration none}
        {src /resources/acs-subsite/Add16.gif}
        {parameter_declaration {
          {-page_id}
          {-alt "new"}
          {-book_mode false}
        }}
      }

  create-item-button instproc render {} {
    my get_parameters
    my instvar __including_page
    set page [expr {[info exists page_id] ? $page_id : $__including_page}]
    set page_order [::xowiki::Portlet incr_page_order [$page page_order]]
    if {[$page istype ::xowiki::FormPage]} {
      set template [$page page_template]
      return [my render_button \
		  -page $template -method create-new -package_id $package_id \
		  -title [_ xowiki.create_new_entry_of_type [list type [$template title]]] \
		  -alt $alt -page_order $page_order \
		  -return_url [::xo::cc url]]
    } else {
      set object_type [$__including_page info class]
      return [my render_button \
		  -page $package_id -method edit_new -package_id $package_id \
		  -title [_ xowiki.create_new_entry_of_type [list type $object_type]] \
		  -alt $alt -page_order $page_order \
		  -return_url [::xo::cc url] \
                  -object_type $object_type]
    }
  }

  Class create copy-item-button -superclass ::xowiki::portlet::item-button \
      -parameter {
        {__decoration none}
        {src /resources/acs-subsite/Copy16.gif}
        {parameter_declaration {
          {-page_id}
          {-alt "copy"}
          {-book_mode false}
        }}
      }

  copy-item-button instproc render {} {
    my get_parameters
    my instvar __including_page
    set page [expr {[info exists page_id] ? $page_id : $__including_page}]

    if {[$page istype ::xowiki::FormPage]} {
      set template [$page page_template]
      return [my render_button \
		  -page $template -method create-new -package_id $package_id \
		  -title [_ xowiki.copy_entry [list type [$template title]]] \
		  -alt $alt -source_item_id [$page item_id] \
		  -return_url [::xo::cc url]]
    } else {
      set object_type [$__including_page info class]
      return [my render_button \
		  -page $package_id -method edit_new -package_id $package_id \
		  -title [_ xowiki.copy_entry [list type $object_type]] \
		  -alt $alt -source_item_id [$page item_id] \
		  -return_url [::xo::cc url] \
                  -object_type $object_type]
    }
  }


}


namespace eval ::xowiki::portlet {

  Class create graph \
      -superclass ::xowiki::Portlet \
      -parameter {{__decoration plain}}

  graph instproc graphHTML {-edges -nodes -max_edges -cutoff -base {-attrib node_id}} {

    ::xowiki::Page requireJS "/resources/ajaxhelper/prototype/prototype.js"
    set user_agent [string tolower [ns_set get [ns_conn headers] User-Agent]]
    if {[string match "*msie *" $user_agent]} {
      # canvas support for MSIE
      ::xowiki::Page requireJS "/resources/xowiki/excanvas.js"
    }
    ::xowiki::Page requireJS "/resources/xowiki/collab-graph.js"
    ::xowiki::Page requireJS "/resources/ajaxhelper/yui/yahoo/yahoo.js"
    ::xowiki::Page requireJS "/resources/ajaxhelper/yui/event/event.js"

    set nodesHTML ""
    array set n $nodes

    foreach {node label} $nodes {
      set link "<a href='$base?$attrib=$node'>$label</a>"
      append nodesHTML "<div id='$node' style='position:relative;'>&nbsp;&nbsp;&nbsp;&nbsp;$link</div>\n"
    }

    set edgesHTML ""; set c 0
    foreach p [lsort -index 1 -decreasing -integer $edges] {
      foreach {edge weight width} $p break
      foreach {a b} [split $edge ,] break
      #my log "--G $a -> $b check $c > $max_edges, $weight < $cutoff"
      if {[incr c]>$max_edges} break
      if {$weight < $cutoff} continue
      append edgesHTML "g.addEdge(\$('$a'), \$('$b'), $weight, 0, $width);\n"
    }
    # [lsort -index 1 -decreasing -integer $edges]<br>[set cutoff] - [set c]<br>

    return [subst -novariables {
<div>
<canvas id="collab" width="500" height="500" style="border: 0px solid black">
</canvas>
[set nodesHTML]
<script type="text/javascript">
function draw() {
  if (typeof(G_vmlCanvasManager) == "object") {
      G_vmlCanvasManager.init_(window.document);
  } 
  
  var g = new Graph();
[set edgesHTML]
  var layouter = new Graph.Layout.Spring(g);
  layouter.layout();

  // IE does not pick up the canvas width or height
  $('collab').width=500;
  $('collab').height=500;

  var renderer = new Graph.Renderer.Basic($('collab'), g);
  renderer.radius = 5;
  renderer.draw();
}
 YAHOO.util.Event.addListener(window, 'load', draw);
//   YAHOO.util.Event.onContentReady('collab', draw); 
</script>
</div>
}]
  }
}

namespace eval ::xowiki::portlet {
  Class create collab-graph \
      -superclass ::xowiki::portlet::graph \
      -parameter {
        {parameter_declaration {
          {-max_edges 70} 
          {-cutoff 0.1} 
          {-show_anonymous "message"}
          -user_id
        }}
      }
  
  collab-graph instproc render {} {
    my get_parameters
    
    if {$show_anonymous ne "all" && [::xo::cc user_id] eq 0} {
      return "You must login to see the [namespace tail [self class]]"
    }
    if {![info exists user_id]} {set user_id [::xo::cc user_id]}

    set folder_id [$package_id folder_id]    
    db_foreach [my qn get_collaborators] {
      select count(revision_id), item_id, creation_user 
      from cr_revisions r, acs_objects o 
      where item_id in 
        (select distinct i.item_id from 
          acs_objects o, acs_objects o2, cr_revisions cr, cr_items i 
          where o.object_id = i.item_id and o2.object_id = cr.revision_id 
          and o2.creation_user = :user_id and i.item_id = cr.item_id 
          and i.parent_id = :folder_id order by item_id
        ) 
      and o.object_id = revision_id 
      and creation_user is not null 
      group by item_id, creation_user} {

      lappend i($item_id) $creation_user $count
      set count_var user_count($creation_user)
      if {![info exists $count_var]} {set $count_var 0}
      incr $count_var $count
      set user($creation_user) "[::xo::get_user_name $creation_user] ([set $count_var])"
      if {![info exists activities($creation_user)]} {set activities($creation_user) 0}
      incr activities($creation_user) $count
    }

    set result "<p>Collaboration Graph for <b>[::xo::get_user_name $user_id]</b> in this wiki" 
    if {[array size i] < 1} {
      append result "</p><p>No collaborations found</p>"
    } else {

      foreach x [array names i] {
        foreach {u1 c1} $i($x) {
          foreach {u2 c2} $i($x) {
            if {$u1 < $u2} {
              set var collab($u1,$u2)
              if {![info exists $var]} {set $var 0} 
              incr $var $c1
              incr $var $c2
            }
          }
        }
      }

      set max 50
      foreach x [array names collab] {
        if {$collab($x) > $max} {set max $collab($x)}
      }
 
      set edges [list]
      foreach x [array names collab] {
        lappend edges [list $x $collab($x) [expr {$collab($x)*5.0/$max}]]
      }

      append result "($activities($user_id) contributions)</p>\n"
      append result [my graphHTML \
                         -nodes [array get user] -edges $edges \
                         -max_edges $max_edges -cutoff $cutoff \
                         -base collab -attrib user_id]
    }
    
    return $result
  }


  Class create activity-graph \
      -superclass ::xowiki::portlet::graph \
      -parameter {
        {parameter_declaration {
          {-max_edges 70} 
          {-cutoff 0.1}
          {-max_activities:integer 100}
          {-show_anonymous "message"}
        }}
      }
  
  activity-graph instproc render {} {
    my get_parameters

    if {$show_anonymous ne "all" && [::xo::cc user_id] eq 0} {
      return "You must login to see the [namespace tail [self class]]"
    }

    set folder_id [$package_id folder_id]    
    
    # there must be a better way to handle temporaray tables safely....
    catch {db_dml [my qn drop_temp_table] {drop table XOWIKI_TEMP_TABLE}}

    set sql "create global temporary table XOWIKI_TEMP_TABLE on commit preserve rows as "
    set subquery [::xo::db::sql select \
                    -vars "i.item_id, revision_id, creation_user" \
                    -from "cr_revisions cr, cr_items i, acs_objects o" \
                    -where "cr.item_id = i.item_id and i.parent_id = $folder_id \
                            and o.object_id = revision_id" \
                    -orderby "revision_id desc" \
                    -limit $max_activities]
    
    # this is currently a rather ugly hack to get the suff quicky working in oracle.
    # TODO: cleanup, different methods for oracle and postgres for handling temporary tables
    if {[catch {db_dml [my qn get_n_most_recent_contributions] $sql$subquery}]} {
       db_dml . "insert into XOWIKI_TEMP_TABLE (item_id,revision_id,creation_user) ($subquery)"
    }

    set total 0
    db_foreach [my qn get_activities] {
      select count(revision_id),item_id, creation_user  
      from XOWIKI_TEMP_TABLE 
      where creation_user is not null 
      group by item_id, creation_user
    } {
      lappend i($item_id) $creation_user $count
      incr total $count
      set count_var user_count($creation_user)
      if {![info exists $count_var]} {set $count_var 0}
      incr $count_var $count
      set user($creation_user) "[::xo::get_user_name $creation_user] ([set $count_var])"
    }

    if {[catch {db_dml [my qn drop_temp_table] {drop table XOWIKI_TEMP_TABLE}} ]} {
      db_dml [my qn trunc_temp_table] {truncate table XOWIKI_TEMP_TABLE }
    }

    if {[array size i] == 0} {
      append result "<p>No activities found</p>"
    } elseif {[array size user] == 1} {
      set user_id [lindex [array names user] 0]
      append result "<p>Last $total activities were done by user " \
          "<a href='collab?$user_id'>[::xo::get_user_name $user_id]</a>."
    } else {
      append result "<p>Collaborations in last $total activities by [array size user] Users in this wiki</p>"

      foreach x [array names i] {
        foreach {u1 c1} $i($x) {
          foreach {u2 c2} $i($x) {
            if {$u1 < $u2} {
              set var collab($u1,$u2)
              if {![info exists $var]} {set $var 0} 
              incr $var $c1
              incr $var $c2
            }
          }
        }
      }

      set max 0
      foreach x [array names collab] {
        if {$collab($x) > $max} {set max $collab($x)}
      }
 
      set edges [list]
      foreach x [array names collab] {
        lappend edges [list $x $collab($x) [expr {$collab($x)*5.0/$max}]]
      }

      append result [my graphHTML \
                         -nodes [array get user] -edges $edges \
                         -max_edges $max_edges -cutoff $cutoff \
                         -base collab -attrib user_id]
    }
    
    return $result
  }

  Class create timeline \
      -superclass ::xowiki::Portlet \
      -parameter {
        {parameter_declaration {
          -user_id 
          {-data timeline-data} 
          {-interval1 DAY} 
          {-interval2 MONTH}
        }}
      }
  
  timeline instproc render {} {
    my get_parameters

   ::xowiki::Page requireJS "/resources/ajaxhelper/yui/yahoo/yahoo.js"
   ::xowiki::Page requireJS "/resources/ajaxhelper/yui/event/event.js"
   ::xowiki::Page requireJS "/resources/xowiki/timeline/api/timeline-api.js"

   set stamp [clock format [clock seconds] -format "%b %d %Y %X %Z" -gmt true]
   if {[info exists user_id]} {append data "?user_id=$user_id"}

   return [subst -nocommands -nobackslashes {
 <div id="my-timeline" style="font-size:70%; height: 350px; border: 1px solid #aaa"></div>
<script type="text/javascript">
var tl;
function onLoad() {
  var eventSource = new Timeline.DefaultEventSource();
  var bandInfos = [
    Timeline.createBandInfo({
        eventSource:    eventSource,
        date:           "$stamp",
        width:          "70%", 
        intervalUnit:   Timeline.DateTime.$interval1, 
        intervalPixels: 100
    }),
    Timeline.createBandInfo({
        eventSource:    eventSource,
        date:           "$stamp",
        width:          "30%", 
        intervalUnit:   Timeline.DateTime.$interval2, 
        intervalPixels: 200
    })
  ];
  //console.info(bandInfos);
  bandInfos[1].syncWith = 0;
  bandInfos[1].highlight = true;

  tl = Timeline.create(document.getElementById("my-timeline"), bandInfos);
  //console.log('create done');
  Timeline.loadXML("$data", function(xml, url) {eventSource.loadXML(xml,url); });
}

var resizeTimerID = null;
function onResize() {
//   console.log('resize');

    if (resizeTimerID == null) {
        resizeTimerID = window.setTimeout(function() {
            resizeTimerID = null;
//   console.log('call layout');
            tl.layout();
        }, 500);
    }
}

YAHOO.util.Event.addListener(window, 'load',   onLoad());
// YAHOO.util.Event.addListener(window, 'resize', onResize());

</script>

  }]
  }

  Class create user-timeline \
      -superclass timeline \
      -parameter {
        {parameter_declaration {
           -user_id 
           {-data timeline-data} 
           {-interval1 DAY} 
           {-interval2 MONTH}
        }}
      }
  
  user-timeline instproc render {} {
    my get_parameters
    if {![info exists user_id]} {set user_id [::xo::cc user_id]]}
    ::xo::cc set_parameter user_id $user_id
    next 
 }

}


namespace eval ::xowiki::portlet {
  #############################################################################
  Class create form-menu \
      -superclass ::xowiki::Portlet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-form_item_id:integer,required}
        }}
      }
  
  form-menu instproc render {} {
    my get_parameters
    # todo return_url
    my instvar __including_page
    set base [$package_id pretty_link [$__including_page name]]
    set new_link [$package_id make_link -link $base $__including_page create-new return_url]
    set answer_link [$package_id make_link -link $base $__including_page list return_url]
    set template [::xo::db::CrClass get_instance_from_db -item_id $form_item_id]
    set count [$template count_usages]
    set links [list]
    foreach l [list new_link answer_link] {
      if {[set $l] ne ""} {
        set label #xowiki.form-menu-$l#
        if {$l eq "answer_link"} {append label " ($count) "}
        lappend links "<a href='[set $l]'>$label</a>"
      }
    }
    return "<div class='wiki-menu'>[join $links { &middot; }]</div>\n"
  }

  #############################################################################
  Class create form-entry-menu \
      -superclass ::xowiki::Portlet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
        }}
      }
  
  form-entry-menu instproc render {} {
    my get_parameters
    my instvar __including_page
    set form [$__including_page page_template]
    set base [$package_id pretty_link [$form name]]
    return "<div class='wiki-menu'><a href='$base'>Form [$form name]</a></div>\n"
  }

  #############################################################################
  Class create form-usages \
      -superclass ::xowiki::Portlet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-form_item_id:integer}
          {-form}
          {-orderby "_last_modified,desc"}
          {-all:boolean false}
          {-field_names}
          {-csv false}
        }}
      }
  
  form-usages instproc render {} {
    my get_parameters
    my instvar __including_page

    ::xowiki::Page requireCSS "/resources/acs-templating/lists.css"
    set return_url [::xo::cc url]?[::xo::cc actual_query]

    if {![info exists form_item_id]} {
      set form_item_id [::xo::db::CrClass lookup -name $form -parent_id $folder_id]
      if {$form_item_id == 0} {error "Cannot lookup page $form"}
    }

    set form_item [::xowiki::Form get_instance_from_db -item_id $form_item_id]
    $form_item destroy_on_cleanup

    if {![info exists field_names]} {
      set fn [::xowiki::PageInstance get_short_spec_from_form_constraints \
                  -name @table \
                  -form_constraints [$form_item form_constraints]]
      set field_names [split $fn ,]
    }
    if {$field_names eq ""} {
      set field_names {_name _last_modified _creation_user}
    }

    set sql_atts [list instance_attributes ci.name]
    foreach att [::xowiki::FormPage array names db_slot] {set __att($att) 1}
    set common_atts [list last_modified creation_user]
    foreach att $common_atts {
      lappend sql_atts p.$att
      set __att($att) 1
    }
    #my msg __att=[array names __att],
    #my msg sql_atts=$sql_atts
    #my msg field_names=$field_names

    set form_constraints [$form_item form_constraints]
    # set cr_field_spec [::xowiki::PageInstance get_short_spec_from_form_constraints \
    #                            -name @cr_fields \
    #                            -form_constraints $form_constraints]
    # if some fields are hidden in the form, there might still be values (creation_user, etc)
    # maybe filter hidden? ignore for the time being.
    set cr_field_spec ""
    #
    set field_spec [::xowiki::PageInstance get_short_spec_from_form_constraints \
			-name @fields \
			-form_constraints $form_constraints]

    foreach spec_name $field_names {
      set short_spec [::xowiki::PageInstance get_short_spec_from_form_constraints \
                          -name $spec_name \
                          -form_constraints $form_constraints]

      switch -glob -- $spec_name {
        __* {error not_allowed}
        _* {
          set varname [string range $spec_name 1 end]
          if {![info exists __att($varname)]} {
            error "unknown attribute $spec_name"
          }
          set f [$form_item create_form_field \
                     -name $spec_name \
                     -slot [$form_item find_slot $varname] \
                     -spec $cr_field_spec,$short_spec]
	  if {$spec_name eq "_text"} {
	    lappend sql_atts "cr.content as text"
	  } elseif {$spec_name ne "_name"} {
	    lappend sql_atts p.$varname
	  }
        }
        default {
          set f [$form_item create_form_field \
                     -name $spec_name \
                     -slot "" \
                     -spec $field_spec,$short_spec]
        }
      }
      lappend form_fields $f
      set __ff($spec_name) $f
    }
    #my msg ff=[array names __ff]
    #$form_item show_fields $form_fields

    if {[info exists __ff(_creation_user)]} {$__ff(_creation_user) label "By User"}

    set cols ""
    append cols {ImageField_EditIcon edit -label "" -html {style "padding: 2px;"}} \n
    foreach fn $field_names {
      append cols [list AnchorField $fn \
		       -label [$__ff($fn) label] \
		       -richtext [$__ff($fn) istype ::xowiki::FormField::richtext] \
		       -orderby $fn] \n
    }
    append cols [list ImageField_DeleteIcon delete -label ""    ] \n

    TableWidget t1 -volatile -columns $cols

    #
    # Sorting is done for the time being in tcl. This has the advantage
    # that page_orders can be sorted with the special mixin and that
    # instance attributes can be used for sorting as well.
    #
    foreach {att order} [split $orderby ,] break
    if {$att eq "_page_order"} {
      t1 mixin add ::xo::OrderedComposite::IndexCompare
    }
    t1 orderby -order [expr {$order eq "asc" ? "increasing" : "decreasing"}] $att

    #
    # build SQL query and iterate over the results
    # maybe this could be slightly faster by using instantiate_objects
    # 
    set publish_status_clause [expr {$all ? "" : " and ci.publish_status <> 'production' "}]
    set items [::xowiki::FormPage get_instances_from_db \
                   -select_attributes $sql_atts \
                   -from_clause ", xowiki_form_pagei p" \
                   -with_subtypes false \
                   -where_clause " p.page_template = $form_item_id \
			and p.xowiki_form_page_id = cr.revision_id \
                        $publish_status_clause" \
                   -folder_id [$package_id folder_id]]
    $items destroy_on_cleanup

    foreach p [$items children] {
      $p set package_id $package_id

      array set __ia [$p set instance_attributes]
      set page_link [$package_id pretty_link [$p name]]

      t1 add \
          -delete delete \
          -delete.href [$package_id make_link -link $page_link $p delete return_url] \
          -edit edit \
	  -edit.href [$package_id make_link -link $page_link $p edit return_url] 
      
      set __c [t1 last_child]
      $__c set _name.href $page_link

      # set always last_modified for default sorting
      $__c set _last_modified [$p set last_modified]

      foreach __fn $field_names {
        switch -glob -- $__fn {
          __* {error not_allowed}
          _*  {set __value [$p set [string range $__fn 1 end]]}
          default {
            if {[info exists __ia($__fn)]} {
              set __value $__ia($__fn)
            } else {
              # the field was added after the current entry was created
              set __value ""
            }
          }
        }
        $__c set $__fn [$__ff($__fn) pretty_value $__value]
      }
    }

    if {$csv} {
      return [t1 write_csv]
    }

    set base [$package_id pretty_link [$__including_page name]]
    set label [$__including_page name]
    append html [_ xowiki.entries_using_form [list form "<a href='$base'>$label</a></p>"]]
    append html [t1 asHTML]
    append html "<a href='[::xo::cc url]?[::xo::cc actual_query]&csv=1'>csv</a>"
    return $html
  }
}
 