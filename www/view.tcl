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
  page:optional
}

set package_id [ad_conn package_id]
permission::require_permission -object_id $package_id -privilege "read"
set write_p [permission::permission_p -object_id $package_id -privilege "write"]
set admin_p [permission::permission_p -object_id $package_id -privilege "admin"]

::xowiki::Page set recursion_count 0
if {![info exists page]} {
  set static_page 0
  set page [::Generic::CrItem instantiate \
		-item_id $item_id \
		-revision_id $revision_id]
} else {
  set static_page 1
}

if {![info exists folder_id]} {set folder_id [$page set parent_id]}
::xowiki::Page require_folder_object -folder_id $folder_id -package_id $package_id

set content [$page render]

if {!$static_page} {
  if {[ad_parameter "user_tracking" -package_id $package_id]} {
    $page record_last_visited
  }
  set references [$page references]
} else {
  set references ""
}

# only activate tags when the user is logged in
set no_tags [expr {[ad_conn user_id] == 0}]
set tags ""
if {!$no_tags} {
  ::xowiki::Page requireJS  "/resources/xowiki/get-http-object.js"
  set entries [list]
  set tags [lsort [::xowiki::Page get_tags -user_id [ad_conn user_id] \
		       -item_id $item_id -package_id $package_id]]
  set href [site_node::get_url_from_object_id -object_id $package_id]weblog?summary=1
  foreach tag $tags {lappend entries "<a href='$href&tag=[ad_urlencode $tag]'>$tag</a>"}
  set tags_with_links [join $entries {, }]
}

set header_stuff [::xowiki::Page header_stuff]
if {[$page exists master] && $master == 1} {set master [$page set master]}

# export title, text, and lang_links to current scope
$page instvar title name text lang_links
if {$master} {
  set context [list $title]

  set return_url  [::xowiki::Page pretty_link $name]

  set base [apm_package_url_from_id $package_id]
  set rev_link    [export_vars -base ${base}revisions {{page_id $item_id} name}]
  set edit_link   [export_vars -base ${base}edit {item_id}]
  set delete_link [export_vars -base ${base}delete {item_id}]
  set new_link    [export_vars -base ${base}edit {object_type}]
  set admin_link  [export_vars -base ${base}admin/ {}]
  set index_link  [export_vars -base ${base} {}]
  set save_tag_link [export_vars -base ${base}save_tags {}]
  set popular_tags_link [export_vars -base ${base}popular_tags {item_id}]
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
