::xowiki::Package initialize -ad_doc {
  Security management for xowiki pages

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Aug 16, 2006
  @cvs-id $Id$

} -parameter {
  {-item_id:optional}
}

if {[info exists item_id]} {
  set page [::Generic::CrItem instantiate -item_id $item_id]
  $page volatile
  set object_id  $item_id
  set page_title "Manage Permissions for Page: [$page name]"
  set return_url [$package_id query_parameter return_url [$package_id package_url]admin/list]
} else {
  set object_id  $package_id
  set page_title "Manage Permissions for Package [apm_instance_name_from_id $package_id]"
  set return_url [$package_id query_parameter return_url [$package_id package_url]admin]
}

set context [list $page_title]


