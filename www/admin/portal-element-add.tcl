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


set page_id [$package_id resolve_request -path $page_name method]
set page_id [::Generic::CrItem lookup -name $page_name -parent_id [$package_id folder_id]]
set page_title [$page_id title]

# for the time being, we add the portlet on the first page (page 0)
set portal_page_id [portal::get_page_id -portal_id $portal_id -sort_key 0]

if {[db_string check_unique_name_on_page {
  select 1 from portal_element_map
  where portal_id   = :portal_page_id 
  and   pretty_name = :page_title
}] eq "1"} {
  ad_return_error [_ xowiki.portlet_title_exists_error_short] [_ xowiki.portlet_title_exists_error_long]
} else {
  db_transaction {
    set element_id [portal::add_element \
                        -portal_id $portal_id \
                        -portlet_name [xowiki_portlet::get_my_name] \
                        -pretty_name $page_title \
                        -force_region [parameter::get_from_package_key \
                                           -parameter "xowiki_portal_content_force_region" \
                                           -package_key "xowiki-portlet"]
                   ]
    portal::set_element_param $element_id package_id $package_id
    portal::set_element_param $element_id page_name [$page_id name]
  }
  ad_returnredirect $referer
}
ad_script_abort

