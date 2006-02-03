ad_page_contract {
  view a wiki item

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Oct 23, 2005
  @cvs-id $Id$
  
  @param item_id Item to be viewed
  @param revision_id optional revision of the item
  @param object_type the source class providing the data source

} -query {
  {item_id:integer 0}
  {revision_id:integer 0}
  {folder_id:optional}
  {object_type:optional}
  {master 1}
}

::xowiki::Page set recursion_count 0
set page [::Generic::CrItem instantiate \
	      -item_id $item_id \
	      -revision_id $revision_id]

set content [$page render]
set references [$page references]

# export title, text, and description to current scope
$page instvar title text description lang_links
if {$master} {
  set context [list $title]
  set base [apm_package_url_from_id [ad_conn package_id]]
  set rev_link  [export_vars -base ${base}revisions {{page_id $item_id} title}]
  set edit_link [export_vars -base ${base}edit {item_id}]
  set new_link  [export_vars -base ${base}edit {object_type}]
  set index_link  [export_vars -base ${base} {}]

  set return_url  [export_vars -base [ad_conn url] item_id]
  set gc_link     [general_comments_create_link $item_id $return_url]
  set gc_comments [general_comments_get_comments $item_id $return_url]
} else {
  ns_return 200 text/html $content
  ad_script_abort
}
