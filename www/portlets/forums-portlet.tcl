
set portal_id [dotlrn::get_portal_id -user_id [ad_conn user_id]]
set config(shaded_p) f
set config(package_id) [db_list get_forum_ids "
  select value from portal_pages, portal_element_map, portal_element_parameters 
  where portal_id = $portal_id and portal_pages.page_id = portal_element_map.page_id 
  and portal_element_parameters.element_id = portal_element_map.element_id 
  and portal_element_map.name = 'forums_portlet' 
  and key = 'package_id'"]
set cf [array get config]
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
