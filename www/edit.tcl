ad_page_contract {
  This is the edit page for notes.

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Oct 23, 2005
  @cvs-id $Id$

  @param item_id If present, item to be edited
  @param title Name of the item
  @param object_type the source class providing the data source for filling the form
} -query {
  item_id:integer,optional
  title:optional
  last_page_id:integer,optional
  folder_id:integer,optional
  {object_type:optional ::xowiki::Page}
  page_template:integer,optional
}

#ns_log notice "-- [ad_conn url]/'[ns_conn query]' \
#	[info exists item_id] && [ns_set get [ns_getform] __new_p]"

set package_id [ad_conn package_id]
# if we have the item_id, we get the folder and object_type from the CR
if {[info exists item_id] && [ns_set get [ns_getform] __new_p] ne "1"} {
  set page [CrItem instantiate -item_id $item_id]     ;# no revision_id yet
  set folder_id   [$page set parent_id]
  set object_type [$page info class]
  if {$object_type eq "::xowiki::Object" && [$page set title] eq "::$folder_id"} {
    # if we edit the folder object, we have to do some extra magic here, since 
    # the folder object has slightly different naming conventions.
    if {[info command ::$folder_id] eq ""} {
      ns_cache flush xotcl_object_cache $page
      $page move ::$folder_id
    }
    set page ::$folder_id
    $page set package_id [ad_conn package_id]
  } else {
    $page volatile
    ::xowiki::Page require_folder_object -folder_id $folder_id -package_id [ad_conn package_id]
  }
} else {
  set page [$object_type new -volatile]
  set folder_id [::xowiki::Page require_folder -name xowiki]
  $page set parent_id $folder_id
}

#
# setting up file selector fs
#
set fs_folder_id ""
if {[info commands dotlrn_fs::get_community_shared_folder] ne ""} {
  set fs_folder_id [dotlrn_fs::get_community_shared_folder \
			-community_id [dotlrn_community::get_community_id]]
}
if {$fs_folder_id ne ""} {
  set folderspec "folder_id $fs_folder_id"
} else {
  set folderspec ""
}

set form_class [$object_type getFormClass]
$form_class create ::xowiki::f1 -volatile \
    -data $page \
    -folderspec $folderspec
#ns_log notice "-- form f1 has class [::xowiki::f1 info class]"

::xowiki::f1 generate
::xowiki::f1 instvar edit_form_page_title context formTemplate

if {[info exists item_id]} {
  set rev_link [export_vars -base revisions {{page_id $item_id} title}]
}
set view_link  [export_vars -base view {item_id}]
if {[info exists last_page_id]} {
  set back_link [export_vars -base view {{item_id $last_page_id} title}]
}
