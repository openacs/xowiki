::xo::library doc {

  XoWiki - Mode procs

  @creation-date 2016-03-22
  @author Gustaf Neumann
  @cvs-id $Id$
}

namespace eval ::xowiki {

  nx::Class create ::xowiki::Mode {

    #
    # Mode handler to set for the current session some application
    # specific mode (like e.g. admin-mode, developer-mode,
    # student-mode, training-mode, ...)
    #
    # Interface:
    #   - method get: obtain the current value (maybe default)
    #   - method set: force the mode to the provided value
    #   - method toggle: toggle current value

    :method mode_name {} {
      return "mode-[::xo::cc package_id]-[self]"
    }

    :public method get {} {
      #
      # Get the current mode, which might be set by the user or which
      # might be obtained from the default method.
      #
      set default [:default]
      set mode_name [:mode_name]
      if {![ns_conn isconnected]} {
        return $default
      }
      if {[ad_get_client_property -cache_only t xowiki $mode_name] eq ""} {
        ad_set_client_property -persistent f xowiki $mode_name $default
      }
      return [ad_get_client_property -cache_only t xowiki $mode_name]
    }

    :public method toggle {} {
      set oldState [:get]
      :set [expr {!$oldState}]
    }
    
    :public method set {value:boolean} {
      #
      # Set the mode to the specified value
      #
      set mode_name [:mode_name]
      ad_set_client_property -persistent f xowiki $mode_name $value
    }
  }

  namespace eval ::xowiki::mode {}
  #
  # Create a sample "admin" mode handler.
  #
  ::xowiki::Mode create ::xowiki::mode::admin {
    :public object method default {} {
      # Admins are per default in admin-mode
      return [::xo::cc permission -object_id [xo::cc package_id] -privilege admin -party_id [xo::cc user_id]]
    }
  }
  #
  # one might create more such mode handler e.g. in an -init.tcl file.
  #
}

::xo::library source_dependent
#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
