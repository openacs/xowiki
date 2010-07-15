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

  Class Tree \
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
    if {![my isclass $renderer]} {
      error "No such renderer $renderer (avalialble [info commands ::xowiki::TreeRenderer=*]"
    }
    return $renderer
  }

  Tree proc include_head_entries {{-renderer mktree} args} {
    eval [my renderer $renderer] include_head_entries $args
  }

  #
  # Instance methods
  #
  Tree instproc init {} {
    # If there is no id specified, use the name as id.
    if {![my exists id]} {my id [my name]}
  }

  Tree instproc add_item {
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
  Tree instproc open_tree {} {;}
  Tree instproc render {{-style mktree} {-js ""} {-context ""}} {
    set renderer [[self class] renderer $style]
    $renderer set context $context
    $renderer set js $js
    TreeNode instmixin $renderer
    set content [$renderer render [self]]
    TreeNode instmixin ""
    if {[$renderer set js] ne ""} {
      append content "\n<script type='text/javascript'>[$renderer set js]</script>\n"
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
    my instvar package_id
    set tree(-1) [self]
    my set open_node($tree(-1)) 1
    set pos 0
    foreach o [$pages children] {
      $o instvar page_order title name
      if {![regexp {^(.*)[.]([^.]+)} $page_order _ parent]} {set parent ""}
      set page_number [$owner page_number $page_order $remove_levels]

      set level [regsub -all {[.]} [$o set page_order] _ page_order_js]
      if {$full || [my exists open_node($parent)] || [my exists open_node($page_order)]} {
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
  Class TreeNode -superclass Tree -parameter {
    level label pos {open_requests 0} count {href ""} 
    object owner li_id ul_id ul_class
    {prefix ""} {expanded false} {highlight false}
  }

  TreeNode instproc open_tree {} {
    my open_requests 1
    my expanded true
    if {[my exists __parent]} {[my set __parent] open_tree}
  }

  TreeNode instproc some_child_has_items {} {
    foreach i [my children] {
      if {[my isobject ${i}::items]} {return 1}
      if {[$i some_child_has_items]} {return 1}
    }
    return 0
  }

  TreeNode instproc render {} {
    set content ""
    if {[my isobject [self]::items]} {
      foreach i [[self]::items children] {
        append cat_content [my render_item -highlight [$i exists open_item] $i ]
      }
      foreach c [my children] {append cat_content [$c render] \n}
      append content [my render_node -open [expr {[my open_requests]>0}] $cat_content]
    } elseif {[my open_requests]>0 || [my some_child_has_items]} {
      set cat_content ""
      foreach c [my children] {append cat_content [$c render] \n}
      append content [my render_node -open true $cat_content]

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
    # specialied renderes will provide their head entries.
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
	$prefix "<a href='$href'>" [::xowiki::Includelet html_encode $title] "</a>" $suffix
    if {$highlight} {
      return "<li class='liItem'><b>$entry</b></li>\n"
    } else {
      return "<li class='liItem'>$entry</li>\n"
    }
  }
  TreeRenderer=list instproc render_node {{-open:boolean false} cat_content} {
    #my msg "[my label] [my expanded]"
    set cl [lindex [my info precedence] 0]
    set o_atts [lindex [$cl li_expanded_atts] [expr {[my expanded] ? 0 : 1}]]
    set h_atts [lindex [$cl highlight_atts] [expr {[my highlight] ? 0 : 1}]]
    set u_atts ""

    if {[my exists li_id]} {append o_atts " id='[my set li_id]'"}
    if {[my exists ul_id]} {append u_atts " id='[my set ul_id]'"}
    if {[my exists ul_class]} {append u_atts " class='[my set ul_class]'"}

    set label [::xowiki::Includelet html_encode [my label]]
    if {[my exists count]} {
      set entry "$label <a href='[my href]'>([my count])</a>"
    } else {
      if {[my href] ne ""} {
	set entry "<a href='[my href]'>$label</a>"
      } else {
	set entry [my label]
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
    return "<li $o_atts><span $h_atts>[my prefix] $entry</span>$content"
  }
  
  #
  # List-specific renderer based on mktree
  #
  TreeRenderer create TreeRenderer=mktree \
      -superclass TreeRenderer=list \
      -li_expanded_atts [list "class='liOpen'" "class='liClosed'"]

  TreeRenderer=mktree proc include_head_entries {args} {
    ::xo::Page requireCSS  "/resources/xowiki/cattree.css"
    ::xo::Page requireJS  "/resources/acs-templating/mktree.js"
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
    set ajaxhelper 1
    ::xowiki::Includelet require_YUI_CSS -ajaxhelper $ajaxhelper "fonts/fonts-min.css"
    ::xowiki::Includelet require_YUI_CSS -ajaxhelper $ajaxhelper \
	"treeview/assets/skins/sam/treeview.css"
    if {$style ne ""} {
      ::xo::Page requireCSS "/resources/ajaxhelper/yui/treeview/assets/$style/tree.css"
    }

    ::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper "yahoo-dom-event/yahoo-dom-event.js"

    if {$ajax} {
      ::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper "connection/connection-min.js"
      ::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper "animation/animation-min.js"   ;# ANIM
    }
    ::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper "treeview/treeview-min.js"
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
    ::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper "utilities/utilities.js"
    ::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper "selector/selector-min.js"
    ::xo::Page requireJS  "/resources/xowiki/yui-page-order-region.js"
  }
  TreeRenderer=listdnd proc render {tree} {
    array set "" [my set context]
    if {[info exists (min_level)] && $(min_level) == 1} {
      set css_class "page_order_region" 
    } else {
      set css_class "page_order_region_no_target"
    }
    return "<div id='[$tree id]'><ul class='$css_class'>\n[next]</ul></div>"
  }
  TreeRenderer=listdnd instproc render_node {{-open:boolean false} cat_content} {
    #set open_state [expr {[my open_requests]>0?"class='liOpen'" : "class='liClosed'"}]
    #set cl [lindex [my info precedence] 0]
    set obj [my object]
    set o [my owner]
    $obj instvar page_order
    my set li_id [::xowiki::Includelet js_name [$o set id]_$page_order]
    my set ul_id [::xowiki::Includelet js_name [$o set id]__l[my level]_$page_order]

    set cl [self class]
    $cl append js "\nYAHOO.xo_page_order_region.DDApp.cd\['[my set li_id]'\] = '$page_order';"

    array set "" [$cl set context]
    my set ul_class [expr {[info exists (min_level)] && [my level] >= $(min_level) ?
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
	$prefix "<a href='$href'>" [::xowiki::Includelet html_encode $title] "</a>" $suffix
    if {$highlight} {
      return "<b>$entry</b><br>\n"
    } else {
      return "$entry<br>\n"
    }
  }
  TreeRenderer=sections instproc render_node {{-open:boolean false} cat_content} {
    set section [expr {[my level] + 2}]
    set label [::xowiki::Includelet html_encode [my label]]
    return "<h$section>$label</h$section>\n<p>\
       <div style='margin-left: 2em; margin-right:0px;'>$cat_content</div>\n"
  }

}
::xo::library source_dependent 

