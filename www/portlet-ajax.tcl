# like portlet, except with background loading via ajax
# gustaf neumann, fecit may 2006
::xowiki::Page requireJS  "/resources/xowiki/get-http-object.js"
if {![string match "/*" $portlet]} {
  set folder_id [$__including_page set parent_id]
  set package_id [$folder_id set package_id]
  set portlet [site_node::get_url_from_object_id -object_id $package_id]portlets/$portlet
}
