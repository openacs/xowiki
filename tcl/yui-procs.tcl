::xo::library doc {
  yui procs: provide some support for yui library

  @creation-date 2014-04-14
  @author Gustaf Neumann
  @cvs-id $Id$
}

::xo::library require menu-procs

namespace eval ::xowiki {

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
	{autorender false}
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
	{href "#"}
        helptext
      }

  YUIMenuItem ad_instproc render {} {doku} {
    html::li [my get_attributes id {CSSclass class} style] {
      # if we have no href, mark entry as disabled
      if {![my exists href] || [my href] eq ""} {my append linkclass " disabled"}
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
	html::ul {
	  foreach li [my children] {$li render}
	}
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



  ::xowiki::MenuBar instproc render-yui {} {
    set M [my content]
    set mb [::xowiki::YUIMenuBar -id [my get_prop $M id] -configuration {
      {autosubmenudisplay: false, keepopen: true, lazyload: false}
    } {
      foreach {menu_att menu} $M {
        if {$menu_att eq "id"} continue
        if {[llength $menu_att] > 1} {
          # We expect a dict as second list element.. but ignore here for the time being
          lassign $menu_att menu_att props
        }
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

  namespace export YUIMenuBar YUIMenuBarItem
  namespace export YUIMenu YUIMenuItem YUIMenuItemList
  namespace export YUIContextMenu YUIContextMenuItem
}


###############################################################################
#   YUI loader       
###############################################################################

namespace eval ::YUI {

  Object loader -ad_doc {
    The YUI Library comes with a "Loader" module, that resolves YUI-module
    dependencies. Also, it combines numerous files into one single file to
    increase page loading performance.
    This works only for the "hosted" YUI library. This Loader module should
    basically do the same (in future). For two simple calls like e.g. 
    "::YUI::loader require menu" and "::YUI::loader require datatable"
    it should take care of selecting all the files needed and assemble them
    into one single resource, that may be delivered.
    Note, that this is not implemented yet.
  }

  loader set ajaxhelper 1

  # TODO: Make "::YUI::loader require -module XYZ" work everywhere "out-of-the-box"
  #       Now, as we use "::xo:Page require_JS" we have to include the generated
  #       header_stuff "manually" (e.g. in tcl-adp pairs),  whereas ::template::head...
  #       includes it directly, which is nice.

  loader ad_proc require {
    -module
    {-version "2.7.0b"}
  } {
    This is the key function of the loader, that will be used by other packages.
    @param module 
    The YUI Module to be loaded
  } {
    my instvar ajaxhelper
    switch -- [string tolower $module] {

      utilities {
        # utilities.js: The utilities.js aggregate combines the Yahoo Global Object,
        # Dom Collection, Event Utility, Element Utility, Connection Manager,
        # Drag & Drop Utility, Animation Utility, YUI Loader and the Get Utility.
        # Use this file to reduce HTTP requests whenever you are including more
        # than three of its constituent components.
        ::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper "yahoo-dom-event/yahoo-dom-event.js"
        ::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper "utilities/utilities.js"
      }
      menubar {
        #
        # We should not have two different versions of the YUI
        # library on one page, because YUI2 (afaik) doesnt support
        # "sandboxing". If we use e.g. the yui-hosted utilities.js file here
        # we may end up with two YAHOO object definitions, because e.g.
        # the tree-procs uses the local yahoo-dom-event.

        # In future, the YUI loader object should be capable of
        # resolving such conflicts. for now, the simple fix is to stick to
        # the local versions, because then the requireJS function takes care
        # of duplicates.
        #
        my require -module "utilities"
        # todo : this is more than necessary
        foreach jsFile {
          "container/container-min.js"
          "treeview/treeview-min.js"
          "button/button-min.js"
          "menu/menu-min.js"
          "datasource/datasource-min.js"
          "autocomplete/autocomplete-min.js"
          "datatable/datatable-min.js"
          "selector/selector-min.js"
        } {
          ::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper $jsFile
        }

        my require -module "reset-fonts-grids"
        my require -module "base"

        foreach cssFile {
          "container/assets/container.css"
          "datatable/assets/skins/sam/datatable.css"
          "button/assets/skins/sam/button.css"
          "assets/skins/sam/skin.css"
          "menu/assets/skins/sam/menu.css"
        } {
          ::xowiki::Includelet require_YUI_CSS -ajaxhelper $ajaxhelper $cssFile
        }
        ::xowiki::Includelet require_YUI_CSS -ajaxhelper 1 "treeview/assets/folders/tree.css"
      }
      datatable {
        # see comment above
        my require -module "utilities"
        # todo : this is more than necessary
        foreach jsFile {
          "container/container-min.js"
          "treeview/treeview-min.js"
          "button/button-min.js"
          "menu/menu-min.js"
          "datasource/datasource-min.js"
          "autocomplete/autocomplete-min.js"
          "datatable/datatable-min.js"
          "selector/selector-min.js"
        } {
          ::xowiki::Includelet require_YUI_JS -version "2.7.0b" -ajaxhelper $ajaxhelper $jsFile
        }

        my require -module "reset-fonts-grids"
        my require -module "base"

        foreach cssFile {
          "container/assets/container.css"
          "datatable/assets/skins/sam/datatable.css"
          "button/assets/skins/sam/button.css"
          "assets/skins/sam/skin.css"
          "menu/assets/skins/sam/menu.css"
        } {
          ::xowiki::Includelet require_YUI_CSS -ajaxhelper $ajaxhelper $cssFile
        }
        #::xowiki::Includelet require_YUI_CSS -ajaxhelper 1 "treeview/assets/skins/sam/treeview.css"
        #::xowiki::Includelet require_YUI_CSS -ajaxhelper 1 "treeview/assets/folders/tree.css"
      }
      reset {
        ::xowiki::Includelet require_YUI_CSS -ajaxhelper $ajaxhelper "reset/reset.css"
      }
      fonts {
        ::xowiki::Includelet require_YUI_CSS -ajaxhelper $ajaxhelper "fonts/fonts.css"
      }
      grids {
        ::xowiki::Includelet require_YUI_CSS -ajaxhelper $ajaxhelper "grids/grids.css"
      }
      base {
        ::xowiki::Includelet require_YUI_CSS -ajaxhelper $ajaxhelper "base/base.css"
      }
      "reset-fonts-grids" {
        ::xowiki::Includelet require_YUI_CSS -ajaxhelper $ajaxhelper "reset-fonts-grids/reset-fonts-grids.css"
      }
    }
  }


  Class AnchorField \
      -superclass ::xo::Table::AnchorField \
      -ad_doc "
            In addition to the standard TableWidget's AnchorField, we also allow the attributes
            <ul>
                <li>onclick
                <li>target
            </ul>
        " \
      -instproc get-slots {} {
        set slots [list -[my name]]
        foreach subfield {href title CSSclass target onclick} {
          lappend slots [list -[my name].$subfield ""]
        }
        return $slots
      }
}

###############################################################################
#   YUI table
###############################################################################

# TODO Allow renderers from other namespaces in 30-widget-procs

namespace eval ::xo::Table {

  Class ::xowiki::YUIDataTable \
      -superclass ::xo::Table \
      -parameter {
        {skin "yui-skin-sam"}
      }

  ::xowiki::YUIDataTable instproc init {} {
    set trn_mixin [expr {[lang::util::translator_mode_p] ?"::xo::TRN-Mode" : ""}]
    my render_with YUIDataTableRenderer $trn_mixin
    next
  }

  Class create YUIDataTableRenderer \
      -superclass TABLE3 \
      -instproc init_renderer {} {
        next
        my set css.table-class list-table
        my set css.tr.even-class even
        my set css.tr.odd-class odd
        my set id [::xowiki::Includelet js_name [::xowiki::Includelet html_id [self]]]
      }

  YUIDataTableRenderer ad_instproc -private render_yui_js {} {
    Generates the JavaScript fragment, that is put below and
    (progressively enhances) the HTML table.
  } {
    my instvar id
    set container   ${id}_container
    set datasource  ${id}_datasource
    set datatable   ${id}_datatable
    set coldef      ${id}_coldef

    set js      "var $datasource = new YAHOO.util.DataSource(YAHOO.util.Dom.get('$id')); \n"
    append js   "$datasource.responseType = YAHOO.util.DataSource.TYPE_HTMLTABLE; \n"
    append js   "$datasource.responseSchema = \{ \n"
    append js   "   fields: \[ \n"
    set js_fields [list]
    foreach field [[self]::__columns children] {
      if {[$field hide]} continue
      lappend js_fields "       \{ key: \"[$field set name]\" \}"
    }
    append js [join $js_fields ", "] "   \] \n\};\n"
    append js "var $coldef = \[\n"
    set js_fields [list]
    foreach field [[self]::__columns children] {
      if {[$field hide]} continue
      if {[$field istype HiddenField]} continue
      if {[$field istype BulkAction]} {
        set label "<input type='checkbox' onclick='acs_ListCheckAll(\\\"objects\\\",this.checked)'></input>"
        set sortable false
      } else {
        set label [$field label]
        set sortable [expr {[$field exists sortable] ? [$field set sortable] : true}]
      }
      lappend js_fields "    \{ key: \"[$field set name]\" , sortable: $sortable, label: \"$label\" \}"
    }
    append js  [join $js_fields ", "] "\];\n"
    append js  "var $datatable = new YAHOO.widget.DataTable('$container', $coldef, $datasource);\n"
    return $js
  }

  YUIDataTableRenderer instproc render-body {} {
    html::thead {
      html::tr -class list-header {
        foreach o [[self]::__columns children] {
          if {[$o hide]} continue
          $o render
        }
      }
    }
    set children [my children]
    html::tbody {
      foreach line [my children] {
        html::tr -class [expr {[my incr __rowcount]%2 ? [my set css.tr.odd-class] : [my set css.tr.even-class] }] {
          foreach field [[self]::__columns children] {
            if {[$field hide]} continue
            html::td  [concat [list class list] [$field html]] { 
              $field render-data $line
            }
          }
        }
      }
    }
  }

  YUIDataTableRenderer instproc render {} {
    ::YUI::loader require -module "datatable"
    if {![my isobject [self]::__actions]} {my actions {}}
    if {![my isobject [self]::__bulkactions]} {my __bulkactions {}}
    set bulkactions [[self]::__bulkactions children]
    if {[llength $bulkactions]>0} {
      set name [[self]::__bulkactions set __identifier]
    } else {
      set name [::xowiki::Includelet js_name [self]]
    }
    # TODO: maybe use skin everywhere? hen to use style/CSSclass or skin?
    set skin [expr {[my exists skin] ? [my set skin] : ""}]
    html::div -id [my set id]_wrapper -class $skin {
      html::form -name $name -id $name -method POST { 
        html::div -id [my set id]_container {
          html::table -id [my set id] -class [my set css.table-class] {
            # TODO do i need that?
            my render-actions
            my render-body
          }
          if {[llength $bulkactions]>0} { my render-bulkactions }
        }
      }
      ::xo::Page requireJS "YAHOO.util.Event.onDOMReady(function () {\n[my render_yui_js]});"
    }
  }


  #Class create YUIDataTableRenderer::AnchorField -superclass TABLE::AnchorField

  Class create YUIDataTableRenderer::AnchorField \
      -superclass TABLE::Field \
      -ad_doc "
            In addition to the standard TableWidget's AnchorField, we also allow the attributes
            <ul>
                <li>onclick
                <li>target
            </ul>
        " \
      -instproc render-data {line} {
        set __name [my name]
        if {[$line exists $__name.href] &&
            [set href [$line set $__name.href]] ne ""} {
          # use the CSS class rather from the Field than not the line
          my instvar CSSclass
          $line instvar   [list $__name.title title] \
              [list $__name.target target] \
              [list $__name.onclick onclick] 
          html::a [my get_local_attributes href title {CSSclass class} target onclick] {
            return "[next]"
          }
        }
        next
      }

  Class create YUIDataTableRenderer::Action -superclass TABLE::Action
  Class create YUIDataTableRenderer::Field -superclass TABLE::Field
  Class create YUIDataTableRenderer::HiddenField -superclass TABLE::HiddenField
  Class create YUIDataTableRenderer::ImageField -superclass TABLE::ImageField
  Class create YUIDataTableRenderer::ImageAnchorField -superclass TABLE::ImageAnchorField
  Class create YUIDataTableRenderer::BulkAction -superclass TABLE::BulkAction
}

::xo::library source_dependent

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
