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
  reindex:optional
  rss:optional
}

set context   [list [list admin Administration] index]
set supertype ::xowiki::Page
set query     .?[ns_conn query]

if {[info exists reindex]} {
  # rebuild fts index and rss content
  ::xowiki::Page reindex -package_id [ad_conn package_id]
}
if {[info exists rss]} {
  ns_log notice "-- rss=$rss"
  set cmd [list ::xowiki::Page rss -package_id [ad_conn package_id]]
  if {[regexp {[^0-9]*([0-9]+)d} $rss _ days]} {lappend cmd -days $days}
  eval $cmd
  ad_script_abort
}

set folder_id [$supertype require_folder -name xowiki]

if {![info exists object_type]} {
  set index_page [$folder_id get_payload index_page]
  if {$index_page ne ""} {
    set item_id [Generic::CrItem lookup -name $index_page -parent_id $folder_id]
    if {$item_id != 0} {
      if {[ns_queryget item_id] eq ""} {rp_form_put item_id $item_id}
      if {[ns_queryget folder_id] eq ""} {rp_form_put folder_id $folder_id}
      rp_internal_redirect "/packages/xowiki/www/view"
      ad_script_abort
    }
  }
}

# if object_type is specified, only list entries of this type;
# otherwise show types and subtypes of $supertype
if {![info exists object_type]} {
  set object_types [$supertype object_types]
  set title "List of all kind of [$supertype set pretty_plural]"
  set with_subtypes true
  set object_type $supertype
} else {
  set object_types [list $object_type]
  set title "Index of [$object_type set pretty_plural]"
  set with_subtypes false
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
      AnchorField name -label [_ xowiki.name]
      Field object_type -label [_ xowiki.page_type]
      #Field last_modified -label "Last Modified" -orderby last_modified
      ImageField_DeleteIcon delete -label "" ;#-html {onClick "return(confirm('Confirm delete?'));"}
    }

set order_clause "order by ci.name"
# -page_size 10
# -page_number 1
db_foreach instance_select \
    [$object_type instance_select_query \
	 -folder_id $folder_id \
	 -with_subtypes $with_subtypes \
	 -select_attributes last_modified \
	 -order_clause $order_clause \
	 ] {

	   t1 add \
	       -name $name \
	       -object_type $object_type \
	       -name.href [::xowiki::Page pretty_link $name] \
	       -edit.href [export_vars -base edit {item_id}] \
	       -delete.href [export_vars -base delete {item_id query}]
  	 }

set t1 [t1 asHTML]