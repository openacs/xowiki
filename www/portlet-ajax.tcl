# like portlet, except with background loading via ajax
# gustaf neumann, fecit may 2006

::xo::Page requireJS urn:ad:js:get-http-object

if {![string match "/*" $portlet]} {
  set folder_id [$__including_page set parent_id]
  set package_id [$folder_id set package_id]
  set portlet [lindex [site_node::get_url_from_object_id -object_id $package_id] 0]portlets/$portlet
}

# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
