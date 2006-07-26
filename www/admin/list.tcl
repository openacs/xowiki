ad_page_contract {
  This is the admin page for the package.  It displays all entries
  provides links to create, edit and delete these

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Oct 23, 2005
  @cvs-id $Id$

  @param object_type show objects of this class and its subclasses
} -query {
  object_type:optional
  {orderby:optional "last_modified,desc"}
}

set package_id [ad_conn package_id]
set Package    [::xowiki::Package create ::$package_id]
$Package instvar folder_id

set context   [list index]

# if object_type is specified, only list entries of this type;
# otherwise show types and subtypes of $supertype
if {![info exists object_type]} {
  set per_type 0
  set supertype ::xowiki::Page
  set object_types [$supertype object_types]
  set title "List of all kind of [$supertype set pretty_plural]"
  set with_subtypes true
  set object_type $supertype
} else {
  set per_type 1
  set object_types [list $object_type]
  set title "Index of [$object_type set pretty_plural]"
  set with_subtypes false
}
#ns_log notice "-- folder_id = $folder_id"

# set up categories
set category_map_url [export_vars -base \
	  [site_node::get_package_url -package_key categories]cadmin/one-object \
			  { { object_id $package_id } }]

set actions ""
foreach type $object_types {
  append actions [subst {
    Action new \
	-label "[_ xotcl-core.add [list type [$type pretty_name]]]" \
	-url [export_vars -base [$Package package_url] {{edit-new 1} {object_type $type}}] \
	-tooltip  "[_ xotcl-core.add_long [list type [$type pretty_name]]]"
  }]
}

TableWidget t1 -volatile \
    -actions $actions \
    -columns {
      ImageField_EditIcon edit -label "" 
      AnchorField name -label [_ xowiki.name] -orderby name
      Field object_type -label [_ xowiki.page_type] -orderby object_type
      Field last_modified -label "Last Modified" -orderby last_modified
      ImageField_DeleteIcon delete -label "" ;#-html {onClick "return(confirm('Confirm delete?'));"}
    }

foreach {att order} [split $orderby ,] break
t1 orderby -order [expr {$order eq "asc" ? "increasing" : "decreasing"}] $att

set order_clause "order by ci.name"
# -page_size 10
# -page_number 1
db_foreach instance_select \
    [$object_type instance_select_query \
	 -folder_id $folder_id \
	 -with_subtypes $with_subtypes \
	 -select_attributes [list "to_char(last_modified,'YYYY-MM-DD HH24:MI:SS') as last_modified"] \
	 -order_clause $order_clause \
	 ] {
	   set page_link [::xowiki::Page pretty_link $name]
	   set return_url [expr {$per_type ? [export_vars -base [$Package url] object_type] :
			   [$Package url]}]
	   t1 add \
	       -name $name \
	       -object_type $object_type \
	       -name.href $page_link \
	       -last_modified $last_modified \
	       -edit.href [export_vars -base $page_link {{m edit}}] \
	       -delete.href [export_vars -base $page_link {{m delete} return_url}]
  	 }

set t1 [t1 asHTML]
