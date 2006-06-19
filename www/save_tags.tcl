ad_page_contract {
  save tags for a page
  
  @author gustaf neumann
  @cvs-id $Id$
  
  @param item_id The item_id for which the tags should be saved
  @param tags The tags to be saved
  @param query The query for redisplay
} -query {
  item_id:integer
  tags
  {query "."}
}
::xowiki::Page save_tags -user_id [ad_conn user_id] -item_id $item_id -package_id [ad_conn package_id] $tags
ns_log notice "--Q query=$query"
ad_returnredirect $query

