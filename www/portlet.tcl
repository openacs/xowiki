ad_page_contract {
  Display portlet
} {
  portlet:path,notnull
}

if {![string match "/*" $portlet]} {
  set portlet /packages/xowiki/www/portlets/$portlet
}

# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
