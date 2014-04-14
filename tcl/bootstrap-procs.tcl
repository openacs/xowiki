::xo::library doc {
  bootstrap procs: provide some (initial) support for bootstrap library

  @creation-date 2014-04-14
  @author Günter Ernst
  @author Gustaf Neumann
  @cvs-id $Id$
}

::xo::library require menu-procs

namespace eval ::xowiki {
  # minimal implementation of Bootstrap "navbar"
  # currently only "dropdown" elements are supported within the navbar
  # TODO: add support to include: 
  # - forms 
  # - buttons
  # - text
  # - Non-nav links
  # - component alignment
  # - navbar positioning
  # - navbar inverting

  ::xo::tdom::Class create BootstrapNavbar \
      -superclass Menu \
      -parameter {
        {autorender false}
        {containerClass "container"}
        {navbarClass "navbar navbar-default navbar-static-top"}
      }
  
  BootstrapNavbar instproc init {} {
    ::xo::Page requireCSS "//netdna.bootstrapcdn.com/bootstrap/3.1.1/css/bootstrap.min.css"
    ::xo::Page requireJS "/resources/xowiki/jquery/jquery.min.js"
    ::xo::Page requireJS "//netdna.bootstrapcdn.com/bootstrap/3.1.1/js/bootstrap.min.js"
    next
  }
  
  BootstrapNavbar ad_instproc render {} {
    http://getbootstrap.com/components/#navbar
  } {
    html::nav -class [my navbarClass] -role "navigation" {
      html::div -class [my containerClass] {
        foreach dropdownmenu [my children] {
          $dropdownmenu render
        }
      }            
    }
  }              
  

  #
  # BootstrapNavbarDropdownMenu
  #  
  ::xo::tdom::Class create BootstrapNavbarDropdownMenu \
      -superclass Menu \
      -parameter {
        text
        header
        {brand false}
      }    

  BootstrapNavbarDropdownMenu ad_instproc render {} {doku} {
    # TODO: Add support for group-headers
    # get group header
    set group 1
    
    html::ul -class "nav navbar-nav" {
      html::li -class "dropdown" {
        set class "dropdown-toggle"
        if {[my brand]} {lappend class "navbar-brand"}
        html::a -href "\#" -class $class -data-toggle "dropdown" {
          html::t [my text] 
          html::b -class "caret"
        }
        html::ul -class "dropdown-menu" {
          foreach dropdownmenuitem [my children] {
            if {[$dropdownmenuitem set group] ne "" && [$dropdownmenuitem set group] ne $group } {
              html::li -class "divider"
              set group [$dropdownmenuitem set group]
            }
            $dropdownmenuitem render
          }
        }
      }
    }
  }   
  #
  # BootstrapNavbarDropdownMenuItem
  #  
  ::xo::tdom::Class create BootstrapNavbarDropdownMenuItem \
      -superclass MenuItem \
      -parameter {
        {href "#"}
        helptext
      }        
  
  BootstrapNavbarDropdownMenuItem ad_instproc render {} {doku} {
    
    html::li -class [expr {[my set href] eq "" ? "disabled": ""}] {
      html::a [my get_attributes target href title] {
        html::t [my text]
      }
    }
  }    
  
  # --------------------------------------------------------------------------
  # render it
  # --------------------------------------------------------------------------
  ::xowiki::MenuBar instproc render-bootstrap {} {
    set M [my content]
    set mb [::xowiki::BootstrapNavbar \
                -id [my get_prop $M id] {
                  foreach {menu_att menu} $M {
                    if {$menu_att eq "id"} continue
                    #
                    # set default properties and 
                    #
                    set props {brand false}
                    if {[llength $menu_att] > 1} {
                      # we expect a dict as second list element
                      lassign $menu_att menu_att props1
                      lappend props {*}$props1
                    }
                    # currently we render erverthing as a dropdown
                    ::xowiki::BootstrapNavbarDropdownMenu \
                        -brand [dict get $props brand] \
                        -text [my get_prop $menu text] {
                      #ns_log notice "... dropdown menu_att $menu_att menu $menu"
                      foreach {item_att item} $menu {
                        if {[string match {[a-z]*} $item_att]} continue
                        set text [my get_prop $item text]
                        set url [my get_prop $item url]
                        set group [my get_prop $item group]
                        ::xowiki::BootstrapNavbarDropdownMenuItem -text $text -href $url -group $group {}
                      }
                    }
                  }
                }]
    ns_log notice call-mb-asHTML
    return [$mb asHTML]
  }
}


# TODO Allow renderers from other namespaces in 30-widget-procs

namespace eval ::xo::Table {

  Class ::xowiki::BootstrapTable \
      -superclass ::xo::Table \
      -parameter {
        skin
      }

  ::xowiki::BootstrapTable instproc init {} {
    ns_log notice "init"
    set trn_mixin [expr {[lang::util::translator_mode_p] ?"::xo::TRN-Mode" : ""}]
    ns_log notice "call render_with ::xo::Table::BootstrapTableRenderer $trn_mixin"
    my render_with BootstrapTableRenderer $trn_mixin
    ns_log notice "init-next"
    next
    ns_log notice "init-next DONE"
  }
  
  Class create BootstrapTableRenderer \
      -superclass TABLE3 \
      -instproc init_renderer {} {
        next
        my set css.table-class "table table-striped"
        my set css.tr.even-class even
        my set css.tr.odd-class odd
        my set id [::xowiki::Includelet js_name [::xowiki::Includelet html_id [self]]]
      }

  BootstrapTableRenderer instproc render-body {} {
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
            if {[$field istype HiddenField]} continue
            html::td  [concat [list class list] [$field html]] { 
              $field render-data $line
            }
          }
        }
      }
    }
  }

  BootstrapTableRenderer instproc render {} {
    ::xo::Page requireCSS "//netdna.bootstrapcdn.com/bootstrap/3.1.1/css/bootstrap.min.css"
    if {![my isobject [self]::__actions]} {my actions {}}
    if {![my isobject [self]::__bulkactions]} {my __bulkactions {}}
    set bulkactions [[self]::__bulkactions children]
    if {[llength $bulkactions]>0} {
      set name [[self]::__bulkactions set __identifier]
    } else {
      set name [::xowiki::Includelet js_name [self]]
    }

    html::div -id [my set id]_wrapper -class "table-responsive" {
      html::form -name $name -id $name -method POST { 
        html::div -id [my set id]_container {
          html::table -id [my set id] -class [my set css.table-class] {
            my render-actions
            my render-body
          }
          if {[llength $bulkactions]>0} { my render-bulkactions }
        }
      }
    }
  }


  #Class create BootstrapTableRenderer::AnchorField -superclass TABLE::AnchorField

  Class create BootstrapTableRenderer::AnchorField \
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

  Class create BootstrapTableRenderer::Action -superclass TABLE::Action
  Class create BootstrapTableRenderer::Field -superclass TABLE::Field
  Class create BootstrapTableRenderer::HiddenField -superclass TABLE::HiddenField
  Class create BootstrapTableRenderer::ImageField -superclass TABLE::ImageField
  Class create BootstrapTableRenderer::ImageAnchorField -superclass TABLE::ImageAnchorField
  Class create BootstrapTableRenderer::BulkAction -superclass TABLE::BulkAction
}




#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
