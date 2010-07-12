::xowiki::Package initialize -ad_doc {
  Add an element to a given portal

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Oct 23, 2005
  @cvs-id $Id$

  @param object_type show objects of this class and its subclasses
} -parameter {
  {-portal_id:required}
  {-page_name:required}
  {-referer .}
}

set page [my get_page_from_item_ref $page_name]

if {$page eq ""} {
  #
  # If a page with the given name does not exist, return an error.
  #
  ad_return_error \
      [_ xowiki.portlet_page_does_not_exist_error_short] \
      [_ xowiki.portlet_page_does_not_exist_error_long $page_name]

} else {
  #
  # The page exists, get the title of the page...
  #
  set page_title [$page title]

  # for the time being, we add the portlet on the first page (page 0)
  set portal_page_id [portal::get_page_id -portal_id $portal_id -sort_key 0]
  
  if {[db_string check_unique_name_on_page {
    select 1 from portal_element_map
    where page_id     = :portal_page_id 
    and   pretty_name = :page_title
  } -default 0]} {
    #
    # The name of the portal element is not unique.
    #
    ad_return_error \
	[_ xowiki.portlet_title_exists_error_short] \
	[_ xowiki.portlet_title_exists_error_long $page_title]
  } else {
    #
    # everything ok, add the portal element
    #
    db_transaction {
      set element_id [portal::add_element \
			  -portal_id $portal_id \
			  -portlet_name [xowiki_portlet name] \
			  -pretty_name $page_title \
			  -force_region [parameter::get_from_package_key \
					     -parameter "xowiki_portal_content_force_region" \
					     -package_key "xowiki-portlet"]
		     ]
      portal::set_element_param $element_id package_id $package_id
      # in case, someone wants language-specific includelets
      #regexp {^..:(.*)$} $page_name _ page_name
      portal::set_element_param $element_id page_name $page_name
    }
    ad_returnredirect $referer
  }
}
ad_script_abort

