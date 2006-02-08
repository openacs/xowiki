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

set context   [list [list admin Administration] index]
set supertype ::xowiki::Page
set query     .?[ns_conn query]

if {![info exists folder_id] && ![info exists object_type]} {
  set folder_id [$supertype require_folder -name xowiki]
  set index_page [$folder_id get_payload index_page]
  if {$index_page ne ""} {
    set item_id [Generic::CrItem lookup -title $index_page -parent_id $folder_id]
    if {$item_id != 0} {
      rp_form_put item_id $item_id
      rp_form_put folder_id $folder_id
      rp_internal_redirect "/packages/xowiki/www/view"
      ad_script_abort
    }
  }
}

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
	  [site_node::get_package_url -package_key categories]cadmin/one-object \
			  { { object_id $package_id } }]

set actions ""
foreach type $object_types {
  append actions [subst {
    Action new \
	-label "[_ xotcl-core.add [list type [$type pretty_name]]]" \
	-url [export_vars -base edit {{object_type $type} folder_id}] \
	-tooltip  "[_ xotcl-core.add_long [list type [$type pretty_name]]]"
  }]
}

TableWidget t1 -volatile \
    -actions $actions \
    -columns {
      ImageField_EditIcon edit -label "" 
      AnchorField title -label [_ xowiki.page_title]
      Field object_type -label [_ xowiki.page_type]
      ImageField_DeleteIcon delete -label ""
    }

set order_clause "order by cr.title"
# -page_size 10
# -page_number 1
db_foreach instance_select \
    [$object_type instance_select_query \
	 -folder_id $folder_id \
	 -select_attributes title \
	 -with_subtypes $with_subtypes \
	 -order_clause $order_clause \
	 ] {
	   if {[regexp {^(..):(.*)$} $title _ lang name]} {
	     set link pages/$lang/[ad_urlencode $name]
	   } else {
	     set link pages/[ad_urlencode $title]
	   }
	   t1 add \
	       -title $title \
	       -object_type $object_type \
	       -title.href $link \
	       -edit.href [export_vars -base edit {item_id}] \
	       -delete.href [export_vars -base delete {item_id query}]
  	 }

set t1 [t1 asHTML]