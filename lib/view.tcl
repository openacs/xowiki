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

set package_id [ad_conn package_id]
permission::require_permission -object_id $package_id -privilege "read"
set write_p [permission::permission_p -object_id $package_id -privilege "write"]
set admin_p [permission::permission_p -object_id $package_id -privilege "admin"]

::xowiki::Page set recursion_count 0
set page [::Generic::CrItem instantiate \
	      -item_id $item_id \
	      -revision_id $revision_id]

if {![info exists folder_id]} {set folder_id [$page set parent_id]}
::xowiki::Page require_folder_object -folder_id $folder_id -package_id $package_id

set content [$page render]

if {[ad_parameter "user_tracking" -package_id $package_id] } {
  $page record_last_visited
}
set references [$page references]
set header_stuff [::xowiki::Page header_stuff]
#ns_log notice "--HEADER-Stuff = <$header_stuff>"

if {[$page exists master] && $master == 1} {set master [$page set master]}

# export title, text, and lang_links to current scope
$page instvar title name text lang_links
if {$master} {
  set context [list $title]

  set base [apm_package_url_from_id $package_id]
  set rev_link    [export_vars -base ${base}revisions {{page_id $item_id} name}]
  set edit_link   [export_vars -base ${base}edit {item_id}]
  set delete_link [export_vars -base ${base}delete {item_id}]
  set new_link    [export_vars -base ${base}edit {object_type}]
  set admin_link  [export_vars -base ${base}admin/ {}]
  set index_link  [export_vars -base ${base} {}]

  set return_url  [::xowiki::Page pretty_link $name]
  set gc_link     [general_comments_create_link $item_id $return_url]
  set gc_comments [general_comments_get_comments $item_id $return_url]

  set template [$folder_id get_payload template]
  if {$template ne ""} {
    set __including_page $page
    set template_code [template::adp_compile -string $template]
    if {[catch {set content [template::adp_eval template_code]} errmsg]} {
      set content "Error in Page $name: $errmsg<br>$content"
    } else {
      ns_return 200 text/html $content
    }
  } else {
    # use adp file
    set template_file [$folder_id get_payload template_file]
    if {$template_file ne ""} {template::set_file "[file dir $__adp_stub]/$template_file"}
  }
} else {
  ns_return 200 text/html $content
  ad_script_abort
}
