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
        {owner}
        {verbose 0}
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
    if {![info exists :id]} {
      set :id ${:name}
    }
  }

  Tree instproc add_item {
    -category
    -orderby
    -itemobj
    {-increasing:boolean true}
    {-open_item:boolean false}
  } {
    set items ${category}::items
    if {![nsf::is object $items]} {
      ::xo::OrderedComposite create $items
      if {[info exists orderby]} {
        set direction [expr {$increasing ? "increasing" : "decreasing"}]
        $items orderby \
            -order $direction \
            -type [ad_decode $orderby page_order index dictionary] \
            $orderby
      }
    }
    $items add $itemobj
    if {$open_item} {
      $category open_tree
      $itemobj set open_item 1
    }
  }
  Tree instproc open_tree {} {;}

  Tree instproc render {
    {-style mktree}
    {-js ""}
    {-context ""}
    {-properties ""}
  } {
    set renderer [[self class] renderer $style]
    $renderer set context $context
    $renderer set js $js
    TreeNode instmixin $renderer
    set content [$renderer render -properties $properties [self]]
    TreeNode instmixin ""
    if {[$renderer set js] ne ""} {
      template::add_body_script -script [$renderer set js]
    }
    return $content
  }

  Tree instproc add_pages {
    {-full:boolean false}
    {-remove_levels:integer 0}
    {-book_mode:boolean false}
    {-open_page ""}
    {-expand_all false}
    {-properties ""}
    -owner:object
    pages:object
  } {
    #
    # Add the pages of the ordered composite to the tree.  Note that
    # it is intended to preserve the order criterion of the provided
    # ordered composite in "pages". If you want to change the order
    # set it already for the passed-in ordered composite via the
    # method "orderby" of the OrderedComposite.
    #
    set tree(-1) [self]
    set :open_node($tree(-1)) 1
    set pos 0
    if {${:verbose}} {
      :log "add_pages want to add [llength [$pages children]] pages"
    }
    set ul_class [expr {[dict exists $properties CSSclass_ul] ?
                        [dict get $properties CSSclass_ul] : ""}]
    foreach o [$pages children] {
      $o instvar page_order title name
      if {![regexp {^(.*)[.]([^.]+)} $page_order _ parent]} {
        set parent ""
      }
      set page_number [$owner page_number $page_order $remove_levels]

      set level [regsub -all -- {[.]} [$o set page_order] _ page_order_js]
      if {${:verbose}} {
        :log "... work on [$o set page_order] level $level full $full"
      }
      if {$full || [info exists :open_node($parent)] || [info exists :open_node($page_order)]} {
        set href [$owner href $book_mode $name]
        set is_current [expr {$open_page eq $name}]
        set is_open [expr {$is_current || $expand_all}]
        set c [::xowiki::TreeNode new \
                   -level $level \
                   -object $o \
                   -owner [self] \
                   -label $title \
                   -prefix $page_number \
                   -href $href \
                   -highlight $is_current \
                   -expanded $is_open \
                   -open_requests 1 \
                   -verbose ${:verbose} \
                   -ul_class $ul_class]
        set tree($level) $c
        for {set l [expr {$level - 1}]} {![info exists tree($l)]} {incr l -1} {}
        $tree($l) add $c
        if {$is_open} {
          $c open_tree
        }
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
    level label pos
    {open_requests 0}
    count
    {href ""}
    object owner li_id ul_id ul_class
    {prefix ""}
    {expanded false}
    {highlight false}
  }

  TreeNode instproc open_tree {} {
    :open_requests 1
    :expanded true
    if {[info exists :__parent]} {${:__parent} open_tree}
  }

  TreeNode instproc some_child_has_items {} {
    foreach i [:children] {
      if {[nsf::is object ${i}::items]} {return 1}
      if {[$i some_child_has_items]} {return 1}
    }
    return 0
  }

  TreeNode instproc render {} {
    set content ""
    if {[nsf::is object [self]::items]} {
      foreach i [[self]::items children] {
        append cat_content [:render_item -highlight [$i exists open_item] $i ]
      }
      foreach c [:children] {append cat_content [$c render] \n}
      append content [:render_node -open [expr {[:open_requests]>0}] $cat_content]
    } elseif {${:open_requests} > 0 || [:some_child_has_items]} {
      set cat_content ""
      foreach c [:children] {append cat_content [$c render] \n}
      append content [:render_node -open true $cat_content]

    }
    if {${:verbose}} {
      :log "TreeNode items [nsf::is object [self]::items] render open_requests ${:open_requests} -> $content"
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
  # the rendering of includelets is cached. However, the renderer
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
  TreeRenderer instproc render {{-properties ""} tree} {
    set content ""
    foreach c [$tree children] {append content [$c render] \n}
    return $content
  }
  TreeRenderer instproc get_property {properties property {default ""}} {
    set value $default
    if {[dict exists $properties $property]} {
      set value [dict get $properties $property]
    }
    return $value
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
  # The last two methods are required.  Below are the currently
  # defined tree renderers. We use as naming convention
  # TreeRenderer=<style>.

  #--------------------------------------------------------------------------------
  # List-specific renderer
  #
  # This is a very common render that maps the tree structure into an
  # unordered HTML list. The rendered is specialized by e.g. the
  # mktree a yuitree render below.
  #--------------------------------------------------------------------------------

  TreeRenderer create TreeRenderer=list
  TreeRenderer=list proc include_head_entries {args} {
    # In the general case, we have nothing to include.  More
    # specialized renders could provide their head entries.
  }
  TreeRenderer=list proc render {{-properties ""} tree} {
    set CSSclass [:get_property $properties CSSclass_ul \
                      [:get_property $properties CSSclass_top_ul]]
    set my_ul_class [expr {$CSSclass ne "" ? "class='$CSSclass' " : ""}]
    return "<ul ${my_ul_class}id='[$tree id]'>[next]</ul>"
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
    #:msg "[:label] [:expanded]"
    set cl [lindex [:info precedence] 0]
    set o_atts [lindex [$cl li_expanded_atts] [expr {${:expanded} ? 0 : 1}]]
    set h_atts [lindex [$cl highlight_atts] [expr {${:highlight} ? 0 : 1}]]
    set u_atts ""

    if {[info exists :li_id]}    {append o_atts " id='${:li_id}'"}
    if {[info exists :li_atts]}  {append o_atts " ${:li_atts}"}
    if {[info exists :ul_id]}    {append u_atts " id='${:ul_id}'"}
    if {[info exists :ul_atts]}  {append u_atts " ${:ul_atts}"}
    if {[info exists :ul_class]} {append u_atts " class='${:ul_class}'"}

    set label [::xowiki::Includelet html_encode [:label]]
    if {[info exists :count]} {
      set entry "$label <a href='[ns_quotehtml [:href]]'>([:count])</a>"
    } else {
      if {${:href} ne ""} {
        set entry "<a href='[ns_quotehtml [:href]]'>[ns_quotehtml $label]</a>"
      } else {
        set entry ${:label}
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
    return "<li $o_atts><span $h_atts>${:prefix} $entry</span>$content</li>"
  }

  #--------------------------------------------------------------------------------
  # List-specific renderer based on mktree
  #--------------------------------------------------------------------------------
  TreeRenderer create TreeRenderer=mktree \
      -superclass TreeRenderer=list \
      -li_expanded_atts [list "class='liOpen'" "class='liClosed'"]

  TreeRenderer=mktree proc include_head_entries {args} {
    ::xo::Page requireCSS  "/resources/xowiki/cattree.css"
    #::xo::Page requireJS  "/resources/acs-templating/mktree.js"
    template::add_body_script -src "/resources/acs-templating/mktree.js"
  }
  TreeRenderer=mktree proc render {{-properties ""} tree} {
    return "<ul class='mktree' id='[$tree id]'>[next]</ul>"
  }

  #--------------------------------------------------------------------------------
  # List-specific renderer based for some menus
  #--------------------------------------------------------------------------------
  TreeRenderer create TreeRenderer=samplemenu \
      -superclass TreeRenderer=list \
      -li_expanded_atts [list "class='menu-open'" "class='menu-closed'"] \
      -subtree_wrapper_class "submenu"

  TreeRenderer=samplemenu proc include_head_entries {args} {
    # add your CSS here...
  }
  TreeRenderer=samplemenu proc render {{-properties ""} tree} {
    return "<ul class='menu' id='[$tree id]'>[next]</ul>"
  }

  #--------------------------------------------------------------------------------
  # List-specific renderer based for bootstrap3 horizontal menu
  #
  # This tree renderer does not support the fancy options like
  # counting, or attached items etc, but could be certainly extended
  # to do so, if there is some application need. Also highlighting
  # should be possible via the "open" parameter as in "list", but
  # depends on the generator of the tree.
  # --------------------------------------------------------------------------------
  TreeRenderer create TreeRenderer=bootstrap3horizontal \
      -superclass TreeRenderer=list

  TreeRenderer=bootstrap3horizontal instproc render_node {{-open:boolean false} cat_content} {
    set label [::xowiki::Includelet html_encode ${:label}]

    if {${:level} == 0} {
      #
      # Top level entry: build menu-button and wrapper for dropdown menu
      #
      append entry \
          "<a class='dropdown-toggle' data-toggle='dropdown' href='#'>" \
          [ns_quotehtml $label] \
          "</a>"
      set o_atts "class='dropdown'"
      set u_atts "class='dropdown-menu'"

    } else {
      #
      # Lower level entry: build dropdown menu entries
      #
      # Probably, entries on a deeper level than 1 should be ignored
      # or differently handled.
      #
      append entry \
          "<a href='[ns_quotehtml ${:href}]'>" \
          [ns_quotehtml $label] \
          </a>
      set o_atts ""
      set u_atts ""
    }
    if {$cat_content ne ""} {
      set content "\n<ul $u_atts>\n$cat_content</ul>"
    } else {
      set content ""
    }
    return "<li $o_atts>$entry $content"
  }

  TreeRenderer=bootstrap3horizontal proc render {{-properties ""} tree} {
    set name [$tree name]
    if {$name ne ""} {
      set navbarLabel [subst {
        <div class="navbar-header">
        <a class="navbar-brand" href="#">[ns_quotehtml $name]</a>
        </div>
      }]
    } else {
      set navbarLabel ""
    }

    return [subst {
      <nav class="navbar navbar-inverse">
      <div class="container-fluid">[ns_quotehtml $navbarLabel]
      <ul class="nav navbar-nav">
      [next]
      </ul>
      </div>
      </nav>
    }]
  }


  #--------------------------------------------------------------------------------
  # List-specific renderer based on yuitree
  #--------------------------------------------------------------------------------
  TreeRenderer create TreeRenderer=yuitree \
      -superclass TreeRenderer=list \
      -li_expanded_atts [list "class='expanded'" ""]

  TreeRenderer=yuitree proc include_head_entries {{-style ""} {-ajax:boolean 1} args} {
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
    ::xo::Page requireJS urn:ad:js:yui2:yahoo/yahoo-min
    ::xo::Page requireJS urn:ad:js:yui2:yahoo-dom-event/yahoo-dom-event

    if {$ajax} {
      ::xo::Page requireJS urn:ad:js:yui2:event/event-min
      ::xo::Page requireJS urn:ad:js:yui2:connection/connection-min
      ::xo::Page requireJS urn:ad:js:yui2:animation/animation-min
    }
    ::xo::Page requireJS urn:ad:js:yui2:treeview/treeview-min
  }
  TreeRenderer=yuitree proc render {{-properties ""} tree} {
    return "<div id='[$tree id]'><ul>[next]</ul></div>"
  }


  #--------------------------------------------------------------------------------
  # list-specific render with drag and drop functionality
  #--------------------------------------------------------------------------------
  TreeRenderer create TreeRenderer=listdnd \
      -superclass TreeRenderer=list \
      -li_expanded_atts [list "" ""]

  TreeRenderer=listdnd proc include_head_entries {args} {
    ::xo::Page requireJS "/resources/xowiki/listdnd.js"
  }
  TreeRenderer=listdnd proc min_level {} {
    if {[dict exists ${:context} min_level]} {
      return [dict get ${:context} min_level]
    }
    return ""
  }
  TreeRenderer=listdnd proc add_handler {-id -event} {
    template::add_event_listener \
        -id $id \
        -event $event \
        -preventdefault=false \
        -script "listdnd_${event}_handler(event);"
  }

  TreeRenderer=listdnd proc render {{-properties ""} tree} {
    #:log "=== TreeRenderer=listdnd render $tree"
    #
    # Do we allow reorder on the top-level?
    #
    set id [$tree id]-topul
    if {[:min_level] == -1} {
      set css_class "page_order_region"
      foreach event {drop dragover dragleave} {
        :add_handler -id $id -event $event
      }
    } else {
      set css_class "page_order_region_no_target"
    }
    #:log "=== TreeRenderer=listdnd render $tree min_level <[:min_level]>"
    if {[$tree exists owner]} {
      #
      # assume, the "owner" is an includelet.
      set owner [$tree set owner]
      set page [$owner set __including_page]
      set package_url [::[$page package_id] package_url]
      set package_url_data " data-package_url='$package_url' data-folder_id='[$page parent_id]'"
    } else {
      set package_url_data ""
    }

    return [subst {<div id='[$tree id]' $package_url_data>
      <ul id='$id' class='$css_class'>[next]
      </ul></div>
    }]
  }
  TreeRenderer=listdnd instproc render_node {{-open:boolean false} cat_content} {
    #:log "=== TreeRenderer=listdnd render_node $cat_content"
    #set open_state [expr {${:open_requests} > 0 ?"class='liOpen'" : "class='liClosed'"}]
    ${:object} instvar page_order

    set :li_id [::xowiki::Includelet js_name [${:owner} set id]_$page_order]
    set :ul_id [::xowiki::Includelet js_name [${:owner} set id]__l${:level}_$page_order]

    set min_level [[self class] min_level]
    set reorder_child [expr {$min_level ne "" && ${:level} >= $min_level}]
    set reorder_self [expr {$min_level ne "" && ${:level} > $min_level}]
    #:log "=== render_node $page_order min_level $min_level level ${:level} reorder_child $reorder_child reorder_self $reorder_self"

    if {$reorder_child} {
      foreach event {drop dragover dragleave} {
        [self class] add_handler -id ${:ul_id} -event $event
      }
      set :ul_class "page_order_region"
    } else {
      set :ul_class "page_order_region_no_target"
    }
    if {$reorder_self} {
      set :li_atts [subst {data-value='$page_order' draggable='true'}]
      [self class] add_handler -id ${:li_id} -event dragstart
    }
    set :ul_id [::xowiki::Includelet js_name [${:owner} set id]__l${:level}_$page_order]

    return [next]
  }

  #--------------------------------------------------------------------------------
  # Tree renderer based on a section structure
  #--------------------------------------------------------------------------------
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
    set section [expr {${:level} + 2}]
    set label [::xowiki::Includelet html_encode ${:label}]
    return "<h$section>$label</h$section>\n<p>\
       <div style='margin-left: 2em; margin-right:0px;'>$cat_content</div>\n"
  }

  #--------------------------------------------------------------------------------
  # Bootstrap tree renderer based on
  # http://jonmiles.github.io/bootstrap-treeview/
  #--------------------------------------------------------------------------------

  TreeRenderer create TreeRenderer=bootstrap3
  TreeRenderer=bootstrap3 proc include_head_entries {args} {
    ::xo::Page requireJS urn:ad:js:jquery
    ::xo::Page requireCSS urn:ad:css:bootstrap3-treeview
    ::xo::Page requireJS  urn:ad:js:bootstrap3-treeview
    security::csp::require style-src cdnjs.cloudflare.com
    security::csp::require script-src cdnjs.cloudflare.com
  }

  TreeRenderer=bootstrap3 proc render {{-properties ""} tree} {
    set jsTree [string trimright [next] ", \n"]
    set id [$tree id]
    set options ""
    lappend options \
        "enableLinks: true"
    template::add_body_script -script "\n\$('#$id').treeview({data: \[$jsTree\], [join $options ,] });"
    return "<div id='$id'></div>"
  }
  TreeRenderer=bootstrap3 instproc render_href {href} {
    if {${:href} ne ""} {
      set jsHref "href: '[::xowiki::Includelet js_encode $href]',"
    } else {
      set jsHref ""
    }
    return $jsHref
  }
  TreeRenderer=bootstrap3 instproc render_item {{-highlight:boolean false} item} {
    :log "======UNTESTED============ highlight $highlight item $item"
    $item instvar title href prefix suffix
    set label  [::xowiki::Includelet js_encode "$prefix$title$suffix"]
    set jsHref [:render_href $href]
    set selected [expr {$highlight ? "true" : "false"}]
    return "\n{text: '$label', $jsHref state: {selected: $selected}},"
  }
  TreeRenderer=bootstrap3 instproc render_node {{-open:boolean false} cat_content} {
    if {${:verbose}} {:log "======bootstrap3==render_node========== ${:label}"}
    if {${:verbose}} {:log "open $open cat_content $cat_content"}

    if {[info exists :count]} {
      set jsTags "tags: \['${:count}'\],"
    } else {
      set jsTags ""
    }
    set jsHref [:render_href ${:href}]
    if {$cat_content ne ""} {
      set cat_content [string trimright $cat_content ", \n"]
      set content ", \nnodes: \[$cat_content\]\n"
    } else {
      set content ""
    }
    set label [::xowiki::Includelet js_encode ${:label}]
    set expanded [expr {${:expanded} ? "true" : "false"}]
    set selected [expr {${:highlight} ? "true" : "false"}]
    return "\n{text: '${label}', $jsTags $jsHref state: {expanded: $expanded, selected: $selected} $content},"
  }

  #--------------------------------------------------------------------------------
  # Bootstrap3 tree renderer with folder structure
  #--------------------------------------------------------------------------------
  TreeRenderer create TreeRenderer=bootstrap3-folders -superclass TreeRenderer=bootstrap3
  TreeRenderer=bootstrap3-folders proc render {{-properties ""} tree} {
    set jsTree [string trimright [next] ", \n"]
    set id [$tree id]
    set options [list "enableLinks: true"]
    # see list of possible icons: https://github.com/jonmiles/bootstrap-treeview
    if {[::template::CSS toolkit] eq "bootstrap5"} {
      lappend options \
          "expandIcon: 'glyphicon glyphicon-none'" \
          "collapseIcon: 'bi bi-folder2-open'"
      #"expandIcon: 'bi bi-folder'"
    } else {
      lappend options \
          "expandIcon: 'glyphicon glyphicon-none'" \
          "collapseIcon: 'glyphicon glyphicon-folder-open'"
    }
    template::add_body_script -script "\n\$('#$id').treeview({data: \[$jsTree\], [join $options ,] });"
    return "<div id='$id'></div>"
  }

}
::xo::library source_dependent

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
