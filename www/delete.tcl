ad_page_contract {
  This deletes a page
  
  @author gustaf neumann
  @cvs-id $Id$
  
  @param item_id The item_id of the note to delete
  @param object_type the source class providing the data source for filling the form
} -query {
  item_id:integer
  {query "."}
}

permission::require_permission -object_id $item_id -privilege admin
::Generic::CrItem delete -item_id $item_id 
ns_cache flush xotcl_object_cache ::$item_id
ad_returnredirect $query

