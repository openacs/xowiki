
if {[info exists url]} {
  # new style, the url is sufficient
  regexp {^(/[^/]+)/?(.*)$} $url _ instance path
  array set node_info [site_node::get -url $instance]
  ns_log notice "--package_id = $node_info(package_id) instance=$instance path=$path"
  set package_id $node_info(package_id)
  set Package [::xowiki::Package create ::$package_id -folder_id 0 -use_ns_conn false]
  $Package set_url -url $url
} else {
  # old style, use item_id
  set m view
  set page [::xowiki::Package instantiate_page_from_id -item_id $item_id]
  $page instvar package_id
  set Package ::$package_id
}
::xowiki::Package process_query \
    -defaults [list m view \
		   edit_return_url [ns_conn url] \
		   template_file "view-links" \
		   folder_id 0 \
		   package_id $package_id]

set html [$Package invoke -method $m]

set fn [get_server_root]/packages/xowiki/www/resources/xowiki.css
set F [open $fn]; set css [read $F]; close $F
set css "<style type='text/css'>$css</style>"
set html $css$html

