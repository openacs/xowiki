ad_page_contract {
  make file_id of content repository to current revision
  
  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Oct 23, 2005
  @cvs-id $Id$
} {
  file_id:integer,notnull
  revision_id:integer,notnull
  title
}

db_exec_plsql make_live {
  select content_item__set_live_revision(:revision_id)
}
ad_returnredirect [export_vars -base file {file_id title}]