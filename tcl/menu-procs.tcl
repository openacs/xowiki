::xo::library doc {

  Basic classes for Menues (context menu, menu bar, menu item).  The
  design is influenced by the YUI2 classes, but we tried to keep the
  implmentation generic. The original version was developed by Michael
  Aram in his Master Thesis. Over the time it was simplified,
  downstripped and refactored by Gustaf Neumann. The currently
  preferred interface is the class.

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
        {listener}
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
      my append CSSclass " " [string tolower [namespace tail [my info class]]]-disabled
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
  #             -item [list label t #xowiki.index# url $index_link]
  #
  #   4) After all updates are performed, use "render-preferred" to obtain
  #      the HTML rendering of the menu.
  #
  # Follow the following nameing conventions:
  #  1) All menu names must start with a capital letter
  #  2) All menu entry names must start with a capital letter
  #  3) All menu entry names should be named after the menu name
  #
  # Notice: the current implementation uses interally dicts. Since the
  # code should as well work with Tcl 8.4 instances, we provide a
  # compatibility layer. Maybe it would be better to base the code on
  # an ordered composite. Ideally, the interface should stay mostly
  # compatible.
  #
  # Gustaf Neumann, May 31, 2010

  Class create ::xowiki::MenuBar -parameter {
    id
    {dropzone:boolean true}
    {parent_id ""}
  }

  if {[info commands ::dict] ne ""} {
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
    if {$name in $Menues} {
      error "menu $name exists already"
    }
    if {[string match {[a-z]*} $name]} {
      error "names must start with uppercase, provided name '$name'"
    }
    my lappend Menues $name
    if {$label eq ""} {set label $name}
    my set Menu($name) [list label $label]
    #my log "menues: $Menues"
  }

  ::xowiki::MenuBar instproc additional_sub_menu {-kind:required -pages:required -owner:required} {
    my set submenu_pages($kind) $pages
    my set submenu_owner($kind) $owner
  }

  ::xowiki::MenuBar instproc clear_menu {-menu:required} {
    array set "" [my set Menu($menu)]
    my set Menu($menu) [list label $(label)]
  }

  ::xowiki::MenuBar instproc current_folder {} {
    if {${:parent_id} ne ""} {
      return ${:parent_id}
    } else {
      #
      # If the current object is the package, use the root folder as
      # current_folder; else use the parent of the current object.
      #
      set object [::xo::cc invoke_object]
      if {[$object is_folder_page]} {
        return $object
      } else {
        return [$object parent_id]
      }
    }
  }

  ::xowiki::MenuBar instproc add_menu_item {
    -name:required
    -item:required
  } {
    #
    # The provided items are of the form of attribute-value pairs
    # containing at least attributes "label" and "url"
    #   (e.g. "label .... url ....").
    #
    my instvar Menues
    set full_name $name
    if {![regexp {^([^.]+)[.](.+)$} $name _ menu name]} {
      error "menu item name '$name' not of the form Menu.Name"
    }
    if {$menu ni $Menues} {
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
    array set "" [list label "#xowiki.menu-$full_name#" group $group_name]
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

  ::xowiki::MenuBar instproc add_extra_item {
    -name:required
    -type:required
    -item:required
  } {
    if {$type ni {"DropZone" "ModeButton"}} {
      error "unknown extra item type: $type"
    }
    my set ${type}($name) $item
  }


  ::xowiki::MenuBar instproc update_items {
    -package_id:required -nls_language:required -parent_id:required
    -return_url  -autoname -template_file items
  } {
    # A folder page can contain extra menu entries (sample
    # below). Iterate of the extra_menu property and add according
    # menu entries. Sample:
    #
    # {clear_menu -menu New}
    # {entry -name New.Page -label #xowiki.new# -form en:page.form}
    # {entry -name New.File -label File -object_type ::xowiki::File}
    # {dropzone -name DropZone -label DropZone -uploader File}
    # {modebutton -name Admin -label admin -button admin}

   
    my set parent_id $parent_id

    foreach me $items {
      array unset ""
      set kind [lindex $me 0]
      if {[string index $kind 0] eq "#"} continue
      set properties [lrange $me 1 end]

      switch $kind {
        
        clear_menu {
          my clear_menu -menu [dict get $properties -menu]
        }
        
        form_link -
        entry {
          # sample entry: entry -name New.YouTubeLink -label YouTube -form en:YouTube.form
          if {$kind eq "form_link"} {
            ad_log warning "$me, name 'form_link' is deprecated, use 'entry' instead"
          }
          if {[dict exists $properties -form]} {
            set link [$package_id make_form_link \
                          -form [dict get $properties -form] \
                          -parent_id $parent_id \
                          -nls_language $nls_language -return_url $return_url]
          } elseif {[dict exists $properties -object_type]} {
            set link [$package_id make_link \
                          $package_id edit-new \
                          [list object_type [dict get $properties -object_type]] \
                          parent_id return_url autoname template_file]
          } else {
            my log "Warning: no link specified"
            set link ""
          }
          set item [list url $link]
          if {[dict exists $properties -label]} {
            lappend item label [dict get $properties -label]
          }
          my add_menu_item -name [dict get $properties -name] -item $item
        }
        
        "dropzone" {
          foreach {var default} {
            name dropzone
            uploader File
            label DropZone
          } {
            set $var $default
            if {[dict exists $properties -$var]} {
              set $var [dict get $properties -$var]
            }
          }

          set link [$package_id make_link $parent_id file-upload]
          my add_extra_item -name $name -type DropZone \
              -item [list url $link uploader $uploader label $label]
        }

        "modebutton" {
          foreach {var default} {
            name modebutton
            button admin
            label ""
          } {
            set $var $default
            if {[dict exists $properties -$var]} {
              set $var [dict get $properties -$var]
            }
          }
          if {$label eq ""} {set label $button}
          set state [::xowiki::mode::$button get]
          set link [$package_id make_link $parent_id toggle-modebutton]
          my add_extra_item -name $name -type ModeButton \
              -item [list url $link on $state label $label]
        }

        default {
          error "unknown kind of menu entry: $kind"
        }
      }
    }
  }

  ::xowiki::MenuBar instproc content {} {
    set result [list id [my id]]
    foreach e [my set Menues] {
      lappend result $e [concat kind MenuButton [my set Menu($e)]]
    }
    
    foreach e [my array name ModeButton] {
      lappend result $e [concat kind ModeButton [my set ModeButton($e)]]
    }

    foreach e [my array name DropZone] {
      lappend result $e [concat kind DropZone [my set DropZone($e)]]
    }

    return $result
  }

  ::xowiki::MenuBar instproc render-preferred {} {
    switch [parameter::get_global_value -package_key xowiki -parameter PreferredCSSToolkit -default bootstrap] {
      bootstrap {set menuBarRenderer render-bootstrap}
      default   {set menuBarRenderer render-yui}
    }
    my $menuBarRenderer
  }


  
  # ::xo::tdom::Class create MenuDropZone \
  #     -superclass MenuComponent \
  #     -parameter {
  #       text
  #       href
  #       title
  #       {id "[my html_id]"}
  #       CSSclass
  #     }


  # MenuDropZone instproc init args {
  #   next
  #   # Use computed default values when not specified
  #   if {![my exists title]} {
  #     # set the mouseover-title to the "MenuItem-Label"
  #     # TODO: Do we really want "text" to be required ?
  #     my title [my text]
  #   }

  #   if {![my exists href] || [my href] eq ""} {
  #     my append CSSclass " " [string tolower [namespace tail [my info class]]]-disabled
  #   }
  # }

  # MenuDropZone instproc render {} {
  #   html::li [my get_attributes id {CSSclass class}] {
  #     html::a [my get_attributes title href target] {
  #       html::t [my text]
  #     }
  #   }
  # }


  namespace export Menu
  # end of namespace
}
::xo::library source_dependent

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
