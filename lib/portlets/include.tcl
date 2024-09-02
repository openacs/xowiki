ad_include_contract {
  Portlet include
} {
  __including_page
  portlet
}

#ns_log notice "--including_page= $__including_page, portlet=$portlet"

set content [$__including_page include $portlet]
template::set_file [ad_file dirname $__adp_stub]/plain-include

# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
