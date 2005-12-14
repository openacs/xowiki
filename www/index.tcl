ad_page_contract {
  This is the main page for the package.  It displays all entries
  provides links to create, edit and delete these

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Oct 23, 2005
  @cvs-id $Id$

  @param object_type show objects of this class and its subclasses
} -query {
  object_type:optional
  folder_id:optional
}

set context [list]
#set supertype CrWikiPage
set supertype ::xowiki::Page

# if object_type is specified, only list entries of this type;
# otherwise show types and subtypes of $supertype
if {![info exists object_type]} {
  set object_types [$supertype object_types]
  set page_title "List of all kind of [$supertype set pretty_plural]"
  set with_subtypes true
  set object_type $supertype
} else {
  set object_types [list $object_type]
  set page_title "Index of [$object_type set pretty_plural]"
  set with_subtypes false
}
if {![info exists folder_id]} {
  set folder_id [$object_type require_folder -name xowiki]
}
#ns_log notice "-- folder_id = $folder_id"

# set up categories
set package_id [ad_conn package_id]
set category_map_url [export_vars -base \
    "[site_node::get_package_url -package_key categories]cadmin/one-object" \
        { { object_id $package_id } }]

::Generic::List index \
    -object_type $object_type \
    -folder_id $folder_id \
    -with_subtypes $with_subtypes \
    -object_types $object_types \
    -fields {
      EDIT {}
      VIEW {}
      title {label "Name"}
      object_type {label "Object Type"}
      DELETE {}
    }

index generate -order_by cr.title

