::xo::library doc {
  yui procs: provide some support for yui library

  @creation-date 2014-04-14
  @author Michael Aram
  @author Gustaf Neumann
  @cvs-id $Id$
}

::xo::library require menu-procs

namespace eval ::xowiki {

  ::xo::tdom::Class create YUIMenuItemList \
      -superclass Menu \
      -parameter {
        header
      }

  YUIMenuItemList instproc render {} {
    if {[info exists :header]} {
      html::h6 {
        html::t [:header]
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
    append :CSSclass " yuimenu"
    set :extrajs ""

    # I want the menu to show up when JS is disabled
    # This gets overridden by JS, so its only relevant for the non-JS version
    #set :style "visibility: visible; position: relative;"

    html::div [:get_attributes {CSSclass class} id style] {
      # Header
      html::t \n
      if {[info exists :header]} {
        html::div -class "hd" {
          html::t [:header]
        }
      }
      # Body
      html::t \n
      html::div -class "bd" {
        foreach group [:split_menu_groups [:children]] {
          html::ul -class yuiml {
            foreach menuitemlist $group {$menuitemlist render}
          }
        }
      }
      # Footer
      if {[info exists :footer]} {
        html::div -class "ft" {
          html::t [:footer]
        }
      }
      # Shadow
      if {[info exists :shadow]} {
        html::div -class "yui-menu-shadow" {}
      }
      # JavaScript
      # only "root-level" menus need JS
      # TODO: is this parent-check sufficient / future-safe?
      if {[info exists :__parent]} {
        #
        # propagate extrajs from rendering
        #
        #ns_log notice "### propagate extrajs <${:extrajs}> from [:info class] to [${:__parent} info class]"
        ${:__parent} append extrajs ${:extrajs}
      } else {
        html::script -nonce [security::csp::nonce] -type "text/javascript" {
          html::t "var [:js_name] = new YAHOO.widget.Menu(\"[:id]\", ${:configuration});"
          html::t "
                        [:js_name].render();
                        [:js_name].show();
                        ${:extrajs}
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
    html::li [:get_attributes id {CSSclass class} style] {
      # if we have no href, mark entry as disabled
      if {![info exists :href] || [:href] eq ""} {append :linkclass " disabled"}
      if {[info exists :listener] && ${:listener} ne ""} {
        #ns_log notice "menuitem has id [:id] listener [:listener] parent ${:__parent} [${:__parent} info class]"
        lassign [:listener] type body
        ${:__parent} append extrajs [subst {
          document.getElementById('[:id]').addEventListener('$type', function (event) {
            $body;
          }, false);
        }]
      }
      html::a [:get_attributes target href {linkclass class} title] {
        html::t [:text]
        if {[info exists :helptext]} {
          html::em {
            html::t [:helptext]
          }
        }
      }
      foreach menu [:children] {$menu render}
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
    append :CSSclass " yuimenubar"
    set :extrajs ""
    if {[:navbar]} {append :CSSclass " yuimenubarnav"}
    html::div [:get_attributes id {CSSclass class}] {
      html::div -class "bd" {
        html::t \n
        html::ul -class "first-of-type" {
          foreach li [:children] {$li render}
        }
        html::t \n
      }
      html::t \n
      ::xo::Page set_property body class "yui-skin-sam"
      ::xo::Page requireJS "YAHOO.util.Event.onDOMReady(function () {
            var [:js_name] = new YAHOO.widget.MenuBar('[:id]', ${:configuration});
            [:js_name].render();
            ${:extrajs}
      });"
    }
  }

  #
  # YUIMenuBarItem
  #
  ::xo::tdom::Class create YUIMenuBarItem \
      -superclass YUIMenuItem

  YUIMenuBarItem instproc init {} {
    #goto YUIMenuItem and set all those nice defaults
    next
    append :CSSclass " first-of-type"
    if {![info exists :href]} {
      # If not set to #, the title of the menu bar items won't expand the submenu (only the arrow)
      set :href "#"
    }
  }

  YUIMenuBarItem instproc render {} {
    set :extrajs ""
    set result [next]
    if {[info exists :__parent]} {
      #
      # propagate extrajs from rendering
      #
      #ns_log notice "### propagate extrajs <${:extrajs}> from [:info class] to [${:__parent} info class]"
      ${:__parent} append extrajs ${:extrajs}
    }
  }
  
  #
  # YUIContextMenu
  #

  # TODO: Support for Multiple Element IDs/Refs as Trigger

  ::xo::tdom::Class create YUIContextMenu \
      -superclass YUIMenu \
      -parameter {
        {trigger "document"}
        {triggertype "reference"}
      }

  YUIContextMenu ad_instproc render {} {
    http://developer.yahoo.com/yui/menu/#contextmenu
  } {
    append :CSSclass " yuimenu"
    html::div [:get_attributes id {CSSclass class}] {
      html::div -class "bd" {
        html::ul -class yuicm {
          foreach li [:children] {$li render}
        }
      }
      html::script -nonce [security::csp::nonce] -type "text/javascript" {
        html::t "var [:js_name] = new YAHOO.widget.ContextMenu('[:id]', { trigger: '${:trigger}' } );"
        html::t "[:js_name].render(document.body);"
      }
    }
  }

  #
  # YUIContextMenuItem
  #
  ::xo::tdom::Class create YUIContextMenuItem \
      -superclass YUIMenuItem

  ::xowiki::MenuBar instproc render-yui {} {
    set dict [:content]
    set mb [::xowiki::YUIMenuBar -id [:get_prop $dict id] -configuration {
      {autosubmenudisplay: false, keepopen: true, lazyload: false}
    } {
      foreach {menu_att menu} $dict {
        if {$menu_att eq "id"} continue
        set kind [:get_prop $menu kind]
        #ns_log notice "entry: kind $kind <$menu_att> <$menu>"
        
        if {$kind ne "MenuButton"} continue
        ::xowiki::YUIMenuBarItem -text [:get_prop $menu label] {
          ::xowiki::YUIMenu {
            foreach {item_att item} $menu {
              if {[string match {[a-z]*} $item_att]} continue
              ::xowiki::YUIMenuItem \
                  -text [:get_prop $item label] \
                  -href [:get_prop $item url] \
                  -group [:get_prop $item group] \
                  -listener [:get_prop $item listener] {}
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
    Note that this is not implemented yet.
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
    switch -- [string tolower $module] {

      utilities {
        # utilities.js: The utilities.js aggregate combines the Yahoo Global Object,
        # Dom Collection, Event Utility, Element Utility, Connection Manager,
        # Drag & Drop Utility, Animation Utility, YUI Loader and the Get Utility.
        # Use this file to reduce HTTP requests whenever you are including more
        # than three of its constituent components.
        ::xo::Page requireJS urn:ad:js:yui2:yahoo-dom-event/yahoo-dom-event
        ::xo::Page requireJS urn:ad:js:yui2:utilities/utilities
      }
      menubar {
        #
        # We should not have two different versions of the YUI
        # library on one page, because YUI2 (afaik) doesn't support
        # "sandboxing". If we use e.g. the yui-hosted utilities.js file here
        # we may end up with two YAHOO object definitions, because e.g.
        # the tree-procs uses the local yahoo-dom-event.

        # In future, the YUI loader object should be capable of
        # resolving such conflicts. For now, the simple fix is to stick to
        # the local versions, because then the requireJS function takes care
        # of duplicates.
        #
        :require -module "utilities"
        # todo : this is more than necessary
        foreach jsFile {
          container/container-min
          treeview/treeview-min
          button/button-min
          menu/menu-min
          datasource/datasource-min
          autocomplete/autocomplete-min
          datatable/datatable-min
          selector/selector-min
        } {
          ::xo::Page requireJS urn:ad:js:yui2:$jsFile
        }

        :require -module "reset-fonts-grids"
        :require -module "base"

        foreach cssFile {
          container/assets/container
          datatable/assets/skins/sam/datatable
          button/assets/skins/sam/button
          assets/skins/sam/skin
          menu/assets/skins/sam/menu
          treeview/assets/folders/tree
        } {
          ::xo::Page requireCSS urn:ad:css:yui2:$cssFile
        }
      }
      datatable {
        # see comment above
        :require -module "utilities"
        # todo : this is more than necessary
        foreach jsFile {
          container/container-min
          treeview/treeview-min
          button/button-min
          menu/menu-min
          datasource/datasource-min
          autocomplete/autocomplete-min
          datatable/datatable-min
          selector/selector-min
        } {
          ::xo::Page requireJS urn:ad:js:yui2:$jsFile
        }

        :require -module "reset-fonts-grids"
        :require -module "base"

        foreach cssFile {
          container/assets/container
          datatable/assets/skins/sam/datatable
          button/assets/skins/sam/button
          assets/skins/sam/skin
          menu/assets/skins/sam/menu
        } {
          ::xo::Page requireCSS urn:ad:css:yui2:$cssFile
        }
      }
      reset {
        ::xo::Page requireCSS urn:ad:css:yui2:reset/reset
      }
      fonts {
        ::xo::Page requireCSS urn:ad:css:yui2:fonts/fonts-min
      }
      grids {
        ::xo::Page requireCSS urn:ad:css:yui2:grids/grids
      }
      base {
        ::xo::Page requireCSS urn:ad:css:yui2:base/base
      }
      "reset-fonts-grids" {
        ::xo::Page requireCSS urn:ad:css:yui2:reset-fonts-grids/reset-fonts-grids
      }
    }
  }


  Class create AnchorField \
      -superclass ::xo::Table::AnchorField \
      -ad_doc "
            In addition to the standard TableWidget's AnchorField, we also allow the attributes
            <ul>
                <li>onclick
                <li>target
            </ul>
        " \
      -instproc get-slots {} {
        set slots [list -[:name]]
        foreach subfield {href title CSSclass target onclick} {
          lappend slots [list -[:name].$subfield ""]
        }
        return $slots
      }
}

###############################################################################
#   YUI table
###############################################################################

# TODO Allow renderers from other namespaces in 30-widget-procs

namespace eval ::xo::Table {

  Class create ::xowiki::YUIDataTable \
      -superclass ::xo::Table \
      -parameter {
        {skin "yui-skin-sam"}
      }

  ::xowiki::YUIDataTable instproc init {} {
    set trn_mixin [expr {[lang::util::translator_mode_p] ?"::xo::TRN-Mode" : ""}]
    :render_with YUIDataTableRenderer $trn_mixin
    next
  }

  Class create YUIDataTableRenderer \
      -superclass TABLE3 \
      -instproc init_renderer {} {
        next
        set :css.table-class list-table
        set :css.tr.even-class even
        set :css.tr.odd-class odd
        set :id [::xowiki::Includelet js_name [::xowiki::Includelet html_id [self]]]
      }

  YUIDataTableRenderer ad_instproc -private render_yui_js {} {
    Generates the JavaScript fragment, that is put below and
    (progressively enhances) the HTML table.
  } {
    set container   ${:id}_container
    set datasource  ${:id}_datasource
    set datatable   ${:id}_datatable
    set coldef      ${:id}_coldef
    set finaljs     ""
    set js      "var $datasource = new YAHOO.util.DataSource(YAHOO.util.Dom.get('${:id}')); \n"
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
        set subid [::xowiki::Includelet html_id $field]
        set label "<input type='checkbox' id='$subid'></input>"
        if {[info exists ::__csrf_token]} {
          append label "<input type='hidden' name='__csrf_token' value='$::__csrf_token'>"
        }
        set sortable false
        append finaljs [subst {
          document.getElementById('$subid').addEventListener('click', function (event) {
            acs_ListCheckAll('objects', this.checked);
          }, false);
        }]
      } else {
        set label [lang::util::localize [$field label]]
        set sortable [expr {[$field exists sortable] ? [$field set sortable] : true}]
      }
      lappend js_fields "    \{ key: \"[$field set name]\" , sortable: $sortable, label: \"$label\" \}"
    }
    append js  [join $js_fields ", "] "\];\n"
    append js  "var $datatable = new YAHOO.widget.DataTable('$container', $coldef, $datasource);\n"
    append js $finaljs
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
    set children [:children]
    html::tbody {
      foreach line [:children] {
        html::tr -class [expr {[incr :__rowcount]%2 ? ${:css.tr.odd-class} : ${:css.tr.even-class} }] {
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
    if {![:isobject [self]::__actions]} {:actions {}}
    if {![:isobject [self]::__bulkactions]} {:__bulkactions {}}
    set bulkactions [[self]::__bulkactions children]
    if {[llength $bulkactions]>0} {
      set name [[self]::__bulkactions set __identifier]
    } else {
      set name [::xowiki::Includelet js_name [self]]
    }
    # TODO: maybe use skin everywhere? When to use style/CSSclass or skin?
    set skin [expr {[info exists :skin] ? ${:skin} : ""}]
    html::div -id ${:id}_wrapper -class $skin {
      html::form -name $name -id $name -method POST { 
        html::div -id ${:id}_container {
          html::table -id ${:id} -class ${:css.table-class} {
            # TODO do i need that?
            my render-actions
            my render-body
          }
          if {[llength $bulkactions]>0} { :render-bulkactions }
        }
      }
      ::xo::Page requireJS "YAHOO.util.Event.onDOMReady(function () {\n[:render_yui_js]});"
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
        set __name [:name]
        if {[$line exists $__name.href] &&
            [set href [$line set $__name.href]] ne ""} {
          # use the CSS class rather from the Field than not the line
          set CSSclass ${:CSSclass}
          $line instvar   [list $__name.title title] \
              [list $__name.target target] \
              [list $__name.onclick onclick] 
          html::a [:get_local_attributes href title {CSSclass class} target onclick] {
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
