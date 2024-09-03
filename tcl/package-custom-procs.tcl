::xo::library doc {

  Custom package procs.

  In case a website needs customistion of the methods of
  xowiki::Package, this would be a possible place (at least better
  than xowiki/tcl/package-procs.tcl.

}

::xo::library require -package xowiki package-procs

namespace eval ::xowiki:: {
  #
  # Sample customization
  #
  # Package instproc process_init_parameter {init_parameter} {
  #   # ns_log notice "process_init_parameter called with <$init_parameter>"
  #   if {$init_parameter eq "swa-only"} {
  #     if {[ns_conn isconnected]
  #         && ![acs_user::site_wide_admin_p -user_id [xo::cc user_id]]
  #       } {
  #       :reply_to_user [:error_msg \
  #                           -template_file "error-template" \
  #                           -title "Restricted Access" \
  #                           "This page is restricted to Site Admins only"]
  #       ad_script_abort
  #     }
  #   }
  # }

}
::xo::library source_dependent
#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
