ad_page_contract {
 delete a revision of the content repository
  
  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Oct 23, 2005
  @cvs-id $Id$
} {
  page_id:integer,notnull
  revision_id:integer,notnull
  name
}

db_exec_plsql delete_revision {
  select content_revision__del(:revision_id)
}
ns_cache flush xotcl_object_cache ::$page_id
ad_returnredirect [export_vars -base revisions {page_id name}]