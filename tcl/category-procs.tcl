namespace eval ::xowiki {
  #
  # ::xowiki::CatTree  (category tree)
  #

  Class CatTree -superclass ::xo::OrderedComposite -parameter {{name ""}}
  # 
  # Class methods
  #
  CatTree proc renderer {style} {
    set renderer CategoryRenderer=$style
    if {![my isclass $renderer]} {
      error "No such renderer $renderer (avalialble [info cmd ::xowiki::CategoryRenderer=*]"
    }
    return $renderer
  }

  CatTree proc include_head_entries {{-style mktree}} {
    [my renderer $style] include_head_entries
  }

  #
  # Instance methods
  #
  CatTree instproc add_to_category {
    -category
    -orderby
    -itemobj
    {-increasing:boolean true} 
    {-open_item:boolean false}
  } {
    set items ${category}::items
    if {![my isobject $items]} { 
      ::xo::OrderedComposite create $items
      if {[info exists orderby]} {
        if {$orderby eq "page_order"} {
          $items mixin add ::xo::OrderedComposite::IndexCompare
        }
        set direction [expr {$increasing ? "increasing" : "decreasing"}]
        $items orderby -order $direction $orderby
      }
    }
    $items add $itemobj
    if {$open_item} {
      $category open_tree
      $itemobj set open_item 1
    }
  }
  CatTree instproc open_tree {} {;}
  CatTree instproc render {{-style mktree}} {
    set renderer [[self class] renderer $style]
    Category instmixin $renderer
    set content [$renderer render [self]]
    Category instmixin ""

    return $content
  }

  #
  # ::xowiki::Category 
  #
  
  Class Category -superclass ::xo::OrderedComposite -parameter {
    package_id level label pos category_id {open_requests 0} count {href ""}
  }
  #Category instproc destroy {} {my log --; next}
  Category instproc open_tree {} {
    my set open_requests 1
    if {[my exists __parent]} {[my set __parent] open_tree}
  }

  Category instproc some_child_has_items {} {
    foreach i [my children] {
      if {[my isobject ${i}::items]} {return 1}
      if {[$i some_child_has_items]} {return 1}
    }
    return 0
  }

  Category instproc render {} {
    set content ""
    if {[my isobject [self]::items]} {
      foreach i [[self]::items children] {
        $i instvar name title prefix suffix
        set entry "$prefix<a href='[::[my package_id] pretty_link $name]'>$title</a>$suffix"
        append cat_content [my render_item -highlight [$i exists open_item] $entry]
      }
      foreach c [my children] {append cat_content [$c render] \n}
      append content [my render_category -open [expr {[my set open_requests]>0}] $cat_content]
    } elseif {[my open_requests]>0 || [my some_child_has_items]} {
      set cat_content ""
      foreach c [my children] {append cat_content [$c render] \n}
      append content [my render_category -open true $cat_content]

    }
    return $content
  }

  #
  # Define a meta class for the category renderers with the common
  # behavior.
  #
  Class create CategoryRenderer -superclass Class
  CategoryRenderer instproc include_head_entries {} {
    # to be overloaded
  }
  CategoryRenderer instproc render {cattree} {
    set content ""
    foreach c [$cattree children] {append content [$c render] \n}
    return $content
  }

  #
  # These are the list-specific rendering functions
  #
  CategoryRenderer create CategoryRenderer=mktree 
  CategoryRenderer=mktree proc include_head_entries {} {
    ::xo::Page requireCSS  "/resources/xowiki/cattree.css"
    ::xo::Page requireJS  "/resources/acs-templating/mktree.js"
  }
  CategoryRenderer=mktree proc render {cattree} {
    return "<ul class='mktree' id='[$cattree name]'>[next]</ul>"
  }
  CategoryRenderer=mktree instproc render_item {{-highlight:boolean false} item} {
    if {$highlight} {
      return "<li class='liItem'><b>$item</b></li>\n"
    } else {
      return "<li class='liItem'>$item</li>\n"
    }
  }
  CategoryRenderer=mktree instproc render_category {{-open:boolean false} cat_content} {
    set open_state [expr {[my set open_requests]>0?"class='liOpen'" : "class='liClosed'"}]
    set c [expr {[my exists count] ? "<a href='[my href]'>([my count])</a>" : ""}]
    return "<li $open_state>[my label] $c\n <ul>$cat_content</ul>\n"
  }

  #
  # These are the section-specific rendering functions
  #

  CategoryRenderer create CategoryRenderer=sections
  CategoryRenderer=sections instproc render_item {{-highlight:boolean false} item} {
    if {$highlight} {
      return "<b>$item</b><br/>\n"
    } else {
      return "$item<br/>\n"
    }
  }
  CategoryRenderer=sections instproc render_category {{-open:boolean false} cat_content} {
    set section [expr {[my level] + 2}]
    return "<H$section>[my label]</H$section>\n<p>\
        <blockquote style='margin-left: 2em; margin-right:0px;'>$cat_content</blockquote>\n"
  }

  #
  # Commonly used code for categories
  # 
  Category proc get_mapped_trees {
                  -object_id
                 {-locale ""} 
                 {-names ""} 
                 {-output {tree_id tree_name subtree_category_id assign_single_p require_category_p}} 
               } {
    # Return matched category trees matching the specified names (or all)

    # provide compatibility with earlier versions of categories
    set have_locale [expr {[lsearch [info args category_tree::get_mapped_trees] locale] > -1}]
    set mapped_trees [expr {$have_locale ?
                            [category_tree::get_mapped_trees $object_id $locale] :
                            [category_tree::get_mapped_trees $object_id]}]
    set trees [list]
    foreach tree $mapped_trees {
      foreach {tree_id my_tree_name ...} $tree {break}

      # "names" is a list of category names
      if {$names ne ""} {
        # Check, if the current name matches any of the given
        # names. If the name contains wild-cards, perform a string
        # match, otherwise a string equal.
        set match 0
        foreach n $names {
          if {[string first * $n] > -1} {
            if {![string match $n $my_tree_name]} {
              set match 1
              break
            }
          } elseif {$n eq $my_tree_name} {
            set match 1
            break
          }
        }
        if {!$match} continue
      }
      # Get the values from info in "tree" into separate variables given by output.
      # Note, that the order matters!
      foreach $output $tree break
      set l [list]
      foreach __var $output {lappend l [set $__var]}
      lappend trees $l
    }
    return $trees
  }

  Category proc get_category_infos {{-all false} {-subtree_id ""} {-locale ""} -tree_id} {
    #
    # provide a common interface to older versions of categories
    #
    # provide compatibility with earlier versions of categories
    set have_locale [expr {[lsearch [info args category_tree::get_tree] locale] > -1}]
    set all_arg [expr {$all ? "-all" : ""}]
    return [expr {$have_locale ?
                  [eval category_tree::get_tree $all_arg -subtree_id [list $subtree_id] $tree_id $locale] :
                  [eval category_tree::get_tree $all_arg -subtree_id [list $subtree_id] $tree_id]}]
  }
}

