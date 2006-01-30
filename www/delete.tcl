ad_page_contract {
  This deletes a note
  
  @author Your Name (you@example.com)
  @cvs-id $Id$
  
  @param item_id The item_id of the note to delete
  @param object_type the source class providing the data source for filling the form
} -query {
  item_id:integer
  {query "."}
}

permission::require_write_permission -object_id $item_id
::Generic::CrItem delete -item_id $item_id 
ad_returnredirect $query

