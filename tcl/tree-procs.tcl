::xo::library doc {
  Classes for creating, manageing and rendering trees

  @creation-date 2009-05-29
  @author Gustaf Neumann
  @cvs-id $Id$
}

namespace eval ::xowiki {
  #
  # ::xowiki::Tree
  #
  # This class manages the creation and rendering of the nodes of the
  # tree. It provides a name and id for rending in HTML.

  Class create Tree \
      -superclass ::xo::OrderedComposite \
      -parameter {
        {name ""} 
        id
      }

  # 
  # Class methods
  #
  Tree proc renderer {style} {
    set renderer TreeRenderer=$style
    if {![:isclass $renderer]} {
      error "No such renderer $renderer (avalialble [info commands ::xowiki::TreeRenderer=*]"
    }
    return $renderer
  }

  Tree proc include_head_entries {{-renderer mktree} args} {
    [:renderer $renderer] include_head_entries {*}$args
  }

  #
  # Instance methods
  #
  Tree instproc init {} {
    # If there is no id specified, use the name as id.
    if {![info exists :id]} {my id [:name]}
  }

  Tree instproc add_item {
    -category
    -orderby
    -itemobj
    {-increasing:boolean true} 
    {-open_item:boolean false}
  } {
    set items ${category}::items
    if {![:isobject $items]} { 
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
  Tree instproc open_tree {} {;}
  Tree instproc render {{-style mktree} {-js ""} {-context ""}} {
    set renderer [[self class] renderer $style]
    $renderer set context $context
    $renderer set js $js
    TreeNode instmixin $renderer
    set content [$renderer render [self]]
    TreeNode instmixin ""
    if {[$renderer set js] ne ""} {
      template::add_body_script -script [$renderer set js]
    }
    return $content
  }

  Tree instproc add_pages {
    {-full false} 
    {-remove_levels 0} 
    {-book_mode false} 
    {-open_page ""} 
    {-expand_all false}
    -owner
    pages
  } {
    set tree(-1) [self]
    set :open_node($tree(-1)) 1
    set pos 0
    foreach o [$pages children] {
      $o instvar page_order title name
      if {![regexp {^(.*)[.]([^.]+)} $page_order _ parent]} {set parent ""}
      set page_number [$owner page_number $page_order $remove_levels]

      set level [regsub -all {[.]} [$o set page_order] _ page_order_js]
      if {$full || [info exists :open_node($parent)] || [info exists :open_node($page_order)]} {
        set href [$owner href $book_mode $name]
        set is_current [expr {$open_page eq $name}]
        set is_open [expr {$is_current || $expand_all}]
        set c [::xowiki::TreeNode new -orderby pos -pos [incr pos] -level $level \
                   -object $o -owner [self] \
                   -label $title -prefix $page_number -href $href \
                   -highlight $is_current \
                   -expanded $is_open \
                   -open_requests 1]
        set tree($level) $c
        for {set l [expr {$level - 1}]} {![info exists tree($l)]} {incr l -1} {}
        $tree($l) add $c
        if {$is_open} {$c open_tree}
      }
    }
    return $tree(-1)
  }

  #
  # ::xowiki::TreeNode 
  #
  # The TreeNode represents an n-ary node storing its child nodes in
  # an ordered composite.  In addition to its children, every node may
  # have items associated. For example, a tree of categories can have
  # associated categorized items, which can be added via the method
  # "add_item".
  #
  Class create TreeNode -superclass Tree -parameter {
    level label pos {open_requests 0} count {href ""} 
    object owner li_id ul_id ul_class
    {prefix ""} {expanded false} {highlight false}
  }

  TreeNode instproc open_tree {} {
    :open_requests 1
    :expanded true
    if {[info exists :__parent]} {${:__parent} open_tree}
  }

  TreeNode instproc some_child_has_items {} {
    foreach i [:children] {
      if {[:isobject ${i}::items]} {return 1}
      if {[$i some_child_has_items]} {return 1}
    }
    return 0
  }

  TreeNode instproc render {} {
    set content ""
    if {[:isobject [self]::items]} {
      foreach i [[self]::items children] {
        append cat_content [:render_item -highlight [$i exists open_item] $i ]
      }
      foreach c [:children] {append cat_content [$c render] \n}
      append content [:render_node -open [expr {[:open_requests]>0}] $cat_content]
    } elseif {[:open_requests]>0 || [:some_child_has_items]} {
      set cat_content ""
      foreach c [:children] {append cat_content [$c render] \n}
      append content [:render_node -open true $cat_content]

    }
    return $content
  }

  #
  # The rendering of trees is performed via rendering classes.  All
  # renderers are created and configured via the meta-class
  # TreeRenderer. This meta-class defines the common attributes and
  # behavior of all TreeRenders. 
  #
  # In particular, the TreeRenders are defined to work with xowiki's
  # page fragment caching. Via page fragment caching, the result of
  # the rendering of includedlets is cached. However, the renderer
  # might require additional CSS or JavaScript code, which has to be
  # included for the cached HTML fragment as well. Therefore, the
  # method "include_head_entries" is provided, which is called
  # independently from HTML generation.
  #
  #

  Class create TreeRenderer -superclass Class \
      -parameter {
        {subtree_wrapper_class}
        {li_expanded_atts ""}
        {highlight_atts {"style = 'font-weight:bold;'"}}
      }
  TreeRenderer instproc include_head_entries {args} {
    # to be overloaded
  }
  TreeRenderer instproc render {tree} {
    set content ""
    foreach c [$tree children] {append content [$c render] \n}
    return $content
  }

  #
  # The renderers should provide the following methods as procs
  #
  #   - include_head_entries {args}
  #   - render {tree}
  #
  # (both are optional) and the following methods as instprocs
  # 
  #   - render_node {{-open:boolean false} cat_content}
  #   - render_item {{-highlight:boolean false} item}
  #
  # The last two methods are required.

  # Below are the currently defined tree renderers. We use as naming
  # convention TreeRenderer=<style>.
  #
  # List-specific renderer
  # 
  # This is a very common render that maps the tree structure into an
  # unordered HTML list. The rendered is specialized by e.g. the
  # mktree an yuitree render below.
  #
  TreeRenderer create TreeRenderer=list 
  TreeRenderer=list proc include_head_entries {args} {
    # In the general case, we have nothing to include.  more
    # specialized renders will provide their head entries.
  }
  TreeRenderer=list proc render {tree} {
    return "<ul id='[$tree id]'>[next]</ul>"
  }
  TreeRenderer=list instproc render_item {{-highlight:boolean false} item} {
    $item instvar title href
    set prefix [$item set prefix]
    set suffix [$item set suffix]
    if {![$item exists encoded(prefix)]} {set prefix [::xowiki::Includelet html_encode $prefix]}
    if {![$item exists encoded(suffix)]} {set suffix [::xowiki::Includelet html_encode $suffix]}
    append entry \
        $prefix "<a href='[ns_quotehtml $href]'>" [::xowiki::Includelet html_encode $title] "</a>" $suffix
    if {$highlight} {
      return "<li class='liItem'><b>$entry</b></li>\n"
    } else {
      return "<li class='liItem'>$entry</li>\n"
    }
  }
  TreeRenderer=list instproc render_node {{-open:boolean false} cat_content} {
    #my msg "[:label] [:expanded]"
    set cl [lindex [:info precedence] 0]
    set o_atts [lindex [$cl li_expanded_atts] [expr {[:expanded] ? 0 : 1}]]
    set h_atts [lindex [$cl highlight_atts] [expr {[:highlight] ? 0 : 1}]]
    set u_atts ""

    if {[info exists :li_id]} {append o_atts " id='${:li_id}'"}
    if {[info exists :ul_id]} {append u_atts " id='${:ul_id}'"}
    if {[info exists :ul_class]} {append u_atts " class='${:ul_class}'"}

    set label [::xowiki::Includelet html_encode [:label]]
    if {[info exists :count]} {
      set entry "$label <a href='[ns_quotehtml [:href]]'>([:count])</a>"
    } else {
      if {[:href] ne ""} {
        set entry "<a href='[ns_quotehtml [:href]]'>[ns_quotehtml $label]</a>"
      } else {
        set entry [:label]
      }
    }
    if {$cat_content ne ""} {
      set content "\n<ul $u_atts>\n$cat_content</ul>"
      if {[$cl exists subtree_wrapper_class]} {
        set content "\n<div class='[$cl subtree_wrapper_class]'>$content</div>\n"
      }
    } else {
      set content ""
    }
    return "<li $o_atts><span $h_atts>[:prefix] $entry</span>$content"
  }
  
  #
  # List-specific renderer based on mktree
  #
  TreeRenderer create TreeRenderer=mktree \
      -superclass TreeRenderer=list \
      -li_expanded_atts [list "class='liOpen'" "class='liClosed'"]

  TreeRenderer=mktree proc include_head_entries {args} {
    ::xo::Page requireCSS  "/resources/xowiki/cattree.css"
    #::xo::Page requireJS  "/resources/acs-templating/mktree.js"
    template::add_body_script -src "/resources/acs-templating/mktree.js"
  }
  TreeRenderer=mktree proc render {tree} {
    return "<ul class='mktree' id='[$tree id]'>[next]</ul>"
  }

  #
  # List-specific renderer based for some menus
  #
  TreeRenderer create TreeRenderer=samplemenu \
      -superclass TreeRenderer=list \
      -li_expanded_atts [list "class='menu-open'" "class='menu-closed'"] \
      -subtree_wrapper_class "submenu"

  TreeRenderer=samplemenu proc include_head_entries {args} {
    # add your CSS here...
  }
  TreeRenderer=samplemenu proc render {tree} {
    return "<ul class='menu' id='[$tree id]'>[next]</ul>"
  }

  #
  # List-specific renderer based on yuitree
  #

  TreeRenderer create TreeRenderer=yuitree \
      -superclass TreeRenderer=list \
      -li_expanded_atts [list "class='expanded'" ""]

  TreeRenderer=yuitree proc include_head_entries {{-style ""} {-ajax 1} args} {
    ::xo::Page requireCSS urn:ad:css:yui2:fonts/fonts-min
    ::xo::Page requireCSS urn:ad:css:yui2:treeview/assets/skins/sam/treeview
    if {$style ne ""} {
      # yuitree default css style files are in the assets directory
      if {$style eq "yuitree"} {
        ::xo::Page requireCSS urn:ad:css:yui2:treeview/assets/tree
      } else {
        ::xo::Page requireCSS urn:ad:css:yui2:treeview/assets/$style/tree
      }
    }
    ::xo::Page requireJS urn:ad:js:yui2:yahoo-dom-event/yahoo-dom-event

    if {$ajax} {
      ::xo::Page requireJS urn:ad:js:yui2:connection/connection-min
      ::xo::Page requireJS urn:ad:js:yui2:animation/animation-min
    }
    ::xo::Page requireJS urn:ad:js:yui2:treeview/treeview-min
  }
  TreeRenderer=yuitree proc render {tree} {
    return "<div id='[$tree id]'><ul>[next]</ul></div>"
  }


  #
  # list-specific render with YUI drag and drop functionality
  #

  TreeRenderer create TreeRenderer=listdnd \
      -superclass TreeRenderer=list \
      -li_expanded_atts [list "" ""]

  TreeRenderer=listdnd proc include_head_entries {args} {
    set ajaxhelper 0
    ::xo::Page requireJS urn:ad:js:yui2:utilities/utilities
    ::xo::Page requireJS urn:ad:js:yui2:selector/selector-min
    ::xo::Page requireJS "/resources/xowiki/yui-page-order-region.js"
  }
  TreeRenderer=listdnd proc render {tree} {
    array set "" ${:context}
    if {[info exists (min_level)] && $(min_level) == 1} {
      set css_class "page_order_region" 
    } else {
      set css_class "page_order_region_no_target"
    }
    return "<div id='[$tree id]'><ul class='$css_class'>\n[next]</ul></div>"
  }
  TreeRenderer=listdnd instproc render_node {{-open:boolean false} cat_content} {
    #set open_state [expr {[:open_requests]>0?"class='liOpen'" : "class='liClosed'"}]
    #set cl [lindex [:info precedence] 0]
    set obj [:object]
    set o [:owner]
    $obj instvar page_order
    set :li_id [::xowiki::Includelet js_name [$o set id]_$page_order]
    set :ul_id [::xowiki::Includelet js_name [$o set id]__l[:level]_$page_order]

    set cl [self class]
    $cl append js "\nYAHOO.xo_page_order_region.DDApp.cd\['${:li_id}'\] = '$page_order';"

    array set "" [$cl set context]
    set :ul_class [expr {[info exists (min_level)] && [:level] >= $(min_level) ?
                           "page_order_region" : "page_order_region_no_target"}]
    return [next]
  }

  #
  # a tree rendere based on a section structure
  #
  TreeRenderer create TreeRenderer=sections \
      -superclass TreeRenderer=list 
  TreeRenderer=sections instproc render_item {{-highlight:boolean false} item} {
    $item instvar title href
    set prefix [$item set prefix]
    set suffix [$item set suffix]
    if {![$item exists encoded(prefix)]} {set prefix [::xowiki::Includelet html_encode $prefix]}
    if {![$item exists encoded(suffix)]} {set suffix [::xowiki::Includelet html_encode $suffix]}
    append entry \
        $prefix "<a href='[ns_quotehtml $href]'>" [::xowiki::Includelet html_encode $title] "</a>" $suffix
    if {$highlight} {
      return "<b>$entry</b><br>\n"
    } else {
      return "$entry<br>\n"
    }
  }
  TreeRenderer=sections instproc render_node {{-open:boolean false} cat_content} {
    set section [expr {[:level] + 2}]
    set label [::xowiki::Includelet html_encode [:label]]
    return "<h$section>$label</h$section>\n<p>\
       <div style='margin-left: 2em; margin-right:0px;'>$cat_content</div>\n"
  }

}
::xo::library source_dependent 

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
