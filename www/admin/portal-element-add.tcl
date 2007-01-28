::xowiki::Package initialize -ad_doc {
  Add an element to a given portal

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Oct 23, 2005
  @cvs-id $Id$

  @param object_type show objects of this class and its subclasses
} -parameter {
  {-portal_id}
  {-page_name}
  {-referer .}
}


set page_id [$package_id resolve_request -path $page_name]
set page_id [::Generic::CrItem lookup -name $page_name -parent_id [$package_id folder_id]]

ns_log notice "we have page=$page_id\n::Generic::CrItem lookup -name $page_name -parent_id [$package_id folder_id]"
db_transaction {
ns_log notice "portal::add_element \
		      -portal_id $portal_id \
		      -portlet_name [xowiki_portlet::get_my_name] \
		      -pretty_name [$page_id title] \
		      -force_region [parameter::get_from_package_key \
					 -parameter xowiki_portal_content_force_region \
					 -package_key xowiki-portlet]"

  set element_id [portal::add_element \
		      -portal_id $portal_id \
		      -portlet_name [xowiki_portlet::get_my_name] \
		      -pretty_name [$page_id title] \
		      -force_region [parameter::get_from_package_key \
					 -parameter "xowiki_portal_content_force_region" \
					 -package_key "xowiki-portlet"]
                                                                                 ]
  portal::set_element_param $element_id package_id $package_id
  portal::set_element_param $element_id page_name [$page_id name]
}

ad_returnredirect $referer
ad_script_abort

