::xo::library doc {

  Basic classes for Menues (context menu, menu bar, menu item).  The
  design is influenced by the YUI2 classes, but we tried to keep the
  implmentation generic. The original version was developed by Michael
  Aram in his Master Thesis. Over the time it was simplified,
  downstripped and refactored by Gustaf Neumann. The currently
  prefered interface is the class

  @author Michael Aram
  @author Gustaf Neumann
}

namespace eval ::xowiki {

  #
  # MenuComponent
  #
  ::xo::tdom::Class create MenuComponent \
      -superclass ::xo::tdom::Object

  MenuComponent instproc js_name {} {
    return [::xowiki::Includelet js_name [self]]
  }
  MenuComponent instproc html_id {} {
    return [::xowiki::Includelet html_id [self]]
  }

  #
  # Menu
  #
  ::xo::tdom::Class create Menu \
      -superclass MenuComponent \
      -parameter {
        {id "[my html_id]"}
        CSSclass
      }
  
  Menu ad_instproc render {} {doku} {
    html::ul [my get_attributes id {CSSclass class}] {
      foreach menuitem [my children] {$menuitem render}
    }
  }

  #
  # MenuItem
  #
  ::xo::tdom::Class create MenuItem \
      -superclass MenuComponent \
      -parameter {
        text
        href
        title
        {id "[my html_id]"}
        CSSclass
        style
        linkclass
        target
	{group ""}
      }
  
  
  MenuItem ad_instproc init args {doku} {
    next
    # Use computed default values when not specified
    if {![my exists title]} {
      # set the mouseover-title to the "MenuItem-Label"
      # TODO: Do we really want "text" to be required ?
      my title [my text]
    }
    if {![my exists CSSclass]} {
      # set the CSS class to e.g. "yuimenuitem"
      my CSSclass [string tolower [namespace tail [my info class]]]
    }

    if {![my exists href] || [my href] eq ""} {
      my append CSSclass [string tolower [namespace tail [my info class]]]-disabled
    }
    if {![my exists linkclass]} {
      # set the CSS class to e.g. "yuimenuitemlabel"
      my set linkclass [string tolower [namespace tail [my info class]]]label
    }
  }
  
  MenuItem ad_instproc render {} {doku} {
    html::li [my get_attributes id {CSSclass class}] {
      html::a [my get_attributes title href target] {
        html::t [my text]
      }
    }
  }
  
  
  ::xo::tdom::Class YUIMenuItemList \
      -superclass Menu \
      -parameter {
        header
      }
  
  YUIMenuItemList ad_instproc render {} {} {
    if {[my exists header]} {
      html::h6 {
        html::t [my header]
      }
    }
    next
  }
  
  ###################################################
  #
  # YUIMenu
  #  
  ::xo::tdom::Class create YUIMenu \
      -superclass Menu \
      -parameter {
        header
        footer
        shadow
        {configuration {{}}}
      }
  
  YUIMenu instproc init {} {
    ::xowiki::Includelet require_YUI_CSS -ajaxhelper 1 "menu/assets/skins/sam/menu.css"
    ::xowiki::Includelet require_YUI_JS  -ajaxhelper 1 "yahoo-dom-event/yahoo-dom-event.js"
    ::xowiki::Includelet require_YUI_JS  -ajaxhelper 1 "container/container_core-min.js"
    ::xowiki::Includelet require_YUI_JS  -ajaxhelper 1 "menu/menu-min.js"
    next
  }

  YUIMenu instproc split_menu_groups {list} {
    #
    # split the list of entries into groups, which will be separated
    # with lines in the rendering
    #
    set result [list]
    if {[llength $list] < 1} {return $result}
    set group_name [[lindex $list 0] group]
    set group_list [list]
    foreach e $list {
      set gn [$e group]
      if {$gn ne $group_name} {
	lappend result $group_list
	set group_name $gn
	set group_list [list]
      }
      lappend group_list $e
    }
    lappend result $group_list
    return $result
  }

  YUIMenu ad_instproc render {} {
    http://developer.yahoo.com/yui/menu/
  } {
    my append CSSclass " yuimenu"
    
    # I want the menu to show up when JS is disabled
    # This gets overridden by JS, so its only relevant for the non-JS version
    #my set style "visibility: visible; position: relative;"
    
    html::div [my get_attributes {CSSclass class} id style] {
      # Header
      html::t \n
      if {[my exists header]} {
        html::div -class "hd" {
          html::t [my header]
        }
      }
      # Body
      html::t \n
      html::div -class "bd" {
	foreach group [my split_menu_groups [my children]] {
	  html::ul {
	    foreach menuitemlist $group {$menuitemlist render}
	  }
	}
      }
      # Footer
      if {[my exists footer]} {
        html::div -class "ft" {
          html::t [my footer]
        }
      }
      # Shadow
      if {[my exists shadow]} {
        html::div -class "yui-menu-shadow" {}
      }
      # JavaScript
      # only "root-level" menus need JS
      # TODO: is this parent-check sufficient / future-safe?
      if {![my exists __parent]} {
        html::script -type "text/javascript" {
          html::t "var [my js_name] = new YAHOO.widget.Menu(\"[my id]\", [my set configuration]);"
          html::t "
                        [my js_name].render();
                        [my js_name].show();
                    "
        }
      }
    }
  }

  #
  # YUIMenuItem
  #  
  ::xo::tdom::Class create YUIMenuItem \
      -superclass MenuItem \
      -parameter {
        helptext
      }
  
  YUIMenuItem ad_instproc render {} {doku} {
    html::li [my get_attributes id {CSSclass class} style] {
      # if we have no href, mark entry as disabled
      if {[my href] eq ""} {my append linkclass " disabled"}
      html::a [my get_attributes target href {linkclass class} title] {
        html::t [my text]
        if {[my exists helptext]} {
          html::em {
            html::t [my helptext]
          }
        }
      }
      foreach menu [my children] {$menu render}
    }
    html::t \n
  }
  
  
  #
  # YUIMenuBar
  #    
  ::xo::tdom::Class create YUIMenuBar \
      -superclass YUIMenu \
      -parameter {
        {navbar true}
      }
  
  YUIMenuBar ad_instproc render {} {
    http://developer.yahoo.com/yui/menu/#menubar
    MenuBar looks best without a header and with one MenuItemList only
  } {
    my append CSSclass " yuimenubar"
    if {[my navbar]} {my append CSSclass " yuimenubarnav"}
    html::div [my get_attributes id {CSSclass class}] {
      html::div -class "bd" {
        html::t \n
        html::ul -class "first-of-type" {
          foreach li [my children] {$li render}
        }
        html::t \n
      }
      html::t \n
      ::xo::Page set_property body class "yui-skin-sam"
      ::xo::Page requireJS "YAHOO.util.Event.onDOMReady(function () {
            var [my js_name] = new YAHOO.widget.MenuBar('[my id]', [my set configuration]);
            [my js_name].render();
      });"
    }
  }
  
  #
  # YUIMenuBarItem
  # 
  ::xo::tdom::Class create YUIMenuBarItem \
      -superclass YUIMenuItem
  
  YUIMenuBarItem ad_instproc init {} {} {
    #goto YUIMenuItem and set all those nice defaults
    next
    my append CSSclass " first-of-type"
    if {![my exists href]} {
      # If not set to #, the title of the menubaritems wont expand the submenu (only the arrow)
      my set href "#"
    }
  }

  
  #
  # YUIContextMenu
  # 

  # TODO: Support for Multiple Element IDs/Refs as Trigger

  ::xo::tdom::Class YUIContextMenu \
      -superclass YUIMenu \
      -parameter {
        {trigger "document"}
        {triggertype "reference"}
      }
  
  YUIContextMenu ad_instproc render {} {
    http://developer.yahoo.com/yui/menu/#contextmenu
  } {
    my append CSSclass " yuimenu"
    html::div [my get_attributes id {CSSclass class}] {
      html::div -class "bd" {
        foreach li [my children] {$li render}
      }
      html::script -type "text/javascript" {
        html::t "var [my js_name] = new YAHOO.widget.ContextMenu('[my id]', { trigger: '[my set trigger]' } );"
        html::t "[my js_name].render(document.body);"
      }
    }
  }
  
  #
  # YUIContextMenuItem
  # 
  ::xo::tdom::Class YUIContextMenuItem \
      -superclass YUIMenuItem
  

  #
  # Simple Generic MenuBar
  # 
  # Class for creating and updating Menubars in an incremental
  # fashion. Menu handling works as following:
  #
  #   1) Create an ::xowiki::MenuBar instance
  #
  #   2) Create menus via the "add_menu" method.  The order of the
  #      creation commands determine the order of the menu buttons.
  #
  #   3) Add/update menuentries via the "add_menu_item" method.  The
  #      provided name determines the menu to which the entry is
  #      added. The following example adds a menu entry "StartPage" to
  #      the menu "Package":
  #      
  #        $mb add_menu_item -name Package.Startpage \
  #             -item [list text #xowiki.index# url $index_link]
  #
  #   4) After all updates are performed, use "render-yui" to obtain
  #      the HTML rendering of the menu.
  #
  # Follow the following nameing conventions:
  #  1) All menu names must start with a capital letter
  #  2) All menu entry names must start with a capital letter
  #  3) All menu entry names should be named after the menu name
  #
  # Notice: the current implementation uses interally dicts. Since the
  # code should as well work with tcl 8.4 instances, we provide a
  # compatibility layer. Maybe it would be better to base the code on
  # an ordered composite. Ideally, the interface should stay mostly
  # compatible.
  #
  # Gustaf Neumann, May 31, 2010

  Class create ::xowiki::MenuBar -parameter {
    id
  }

  if {[info command ::dict] ne ""} {
     ::xowiki::MenuBar instproc get_prop {dict key {default ""}} {
      if {![dict exists $dict $key]} {
	return $default
      } 
      return [dict get $dict $key]
    }
  } else {
     ::xowiki::MenuBar instproc get_prop {dict key {default ""}} {
      array set "" $dict
      if {![info exists ($key)]} {
	return $default
      } 
      return [set ($key)]
    }
  }

  ::xowiki::MenuBar instproc init {} {
    my set Menues [list]
    my destroy_on_cleanup
  }
  
  ::xowiki::MenuBar instproc add_menu {-name {-label ""}} {
    my instvar Menues
    if {[lsearch -exact $Menues $name] > -1} {
      error "menu $name exists already"
    }
    if {[string match {[a-z]*} $name]} {
      error "names must start with uppercase, provided name '$name'"
    }
    my lappend Menues $name
    if {$label eq ""} {set label $name}
    my set Menu($name) [list text $label]
    #my log "menues: $Menues"
  }

  ::xowiki::MenuBar instproc additional_sub_menu {-kind:required -pages:required -owner:required} {
    my set submenu_pages($kind) $pages
    my set submenu_owner($kind) $owner
  }

  ::xowiki::MenuBar instproc clear_menu {-menu:required} {
    array set "" [my set Menu($menu)]
    my set Menu($menu) [list text $(text)]
  }

  ::xowiki::MenuBar instproc add_menu_item {-name:required -item:required} {
    #
    # The provided items are of the form of attribute-value pairs
    # containing at least attributes "text" and "url"
    #   (e.g. "text .... url ....").
    #
    my instvar Menues
    set full_name $name
    if {![regexp {^([^.]+)[.](.+)$} $name _ menu name]} {
      error "menu item name '$name' not of the form Menu.Name"
    }
    if {[lsearch -exact $Menues $menu] == -1} {
      error "menu $menu does not exist"
    }
    if {[string match {[a-z]*} $name]} {
      error "names must start with uppercase, provided name '$name'"
    }

    #
    # get group name (syntax: Menu.Group.Item)
    #
    set group_name ""
    regexp {^[^.]+[.]([^.]+)[.].*} $full_name _ group_name
    #
    # provide a default label
    #
    regsub -all {[.]} $full_name - full_name
    array set "" [list text "#xowiki.menu-$full_name#" group $group_name]
    array set "" $item
    set item [array get ""]

    #
    # If an entry with the given name exists, update it. Otherwise add
    # such an entry.
    #
    set updated 0
    set newitems [list]
    foreach {n i} [my set Menu($menu)] {
      if {$n eq $name} {
        lappend newitems $name $item
        set updated 1
      } else {
        lappend newitems $n $i
      }
    }
    if {$updated} {
      my set Menu($menu) $newitems
    } else {
      my lappend Menu($menu) $name $item
    }
  }

  ::xowiki::MenuBar instproc content {} {
    set result [list id [my id]]
    foreach m [my set Menues] {
      lappend result $m [my set Menu($m)]
    }
    return $result
  }

  ::xowiki::MenuBar instproc render-yui {} {
    set M [my content]
    set mb [::xowiki::YUIMenuBar -id [my get_prop $M id] -autorender false -configuration {
      {autosubmenudisplay: false, keepopen: true, lazyload: false}
    } {
      foreach {menu_att menu} $M {
        if {$menu_att eq "id"} continue
        ::xowiki::YUIMenuBarItem -text [my get_prop $menu text] {
          ::xowiki::YUIMenu {
            foreach {item_att item} $menu {
              if {[string match {[a-z]*} $item_att]} continue
              set text [my get_prop $item text]
              set url [my get_prop $item url]
	      set group [my get_prop $item group]
	      #my msg "ia=$item_att group '$group' // t=$text item=$item"
              ::xowiki::YUIMenuItem -text $text -href $url -group $group {} 
            }
          }
        }
      }
    }]
    return [$mb asHTML]
  }

  namespace export Menu 
  namespace export YUIMenuBar YUIMenuBarItem 
  namespace export YUIMenu YUIMenuItem YUIMenuItemList
  namespace export YUIContextMenu YUIContextMenuItem
# end of namespace
}
::xo::library source_dependent 

