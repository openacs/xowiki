ad_page_contract {
  This is the admin page for the package.  It displays all of the types 
  of wiki pages provides links to delete them

  @author Gustaf Neumann neumann@wu-wien.ac.at
  @cvs-id $Id$
} -query {
  object_type:optional
}

set package_id [ad_conn package_id]
set Package    [::xowiki::Package create ::$package_id]
$Package instvar folder_id

set context [list]
set supertype ::xowiki::Page
set title "Administer all kind of [$supertype set pretty_plural]"

set object_type_key [$supertype set object_type_key]
set object_types    [$supertype object_types]

TableWidget t1 -volatile \
    -actions [subst {
      Action new -label all -url list
      Action new -label export -url export
      Action new -label import -url import
      Action new -label permissions -url /admin/applications/permissions?package_id=$package_id
    }] \
    -columns {
      Field object_type -label [_ xowiki.page_type]
      AnchorField instances -label Instances -html {align center}
      ImageField_AddIcon edit -label "Add" -html {align center}
      ImageField_DeleteIcon delete -label "Delete All" \
	  -html {align center onClick "return(confirm('Delete really all?'));"}
    }

set base [$Package package_url]
db_foreach type_select \
    "select object_type from acs_object_types where 
        tree_sortkey between :object_type_key and tree_right(:object_type_key)
    " {

      set return_url [export_vars -base ${base}admin {object_type}]
      t1 add \
	  -object_type $object_type \
	  -instances [db_list count [$object_type instance_select_query \
				 -folder_id $folder_id -count 1 -with_subtypes false]] \
	  -instances.href [export_vars -base ./list {object_type}] \
	  -edit.href   [export_vars -base $base {{edit-new 1} object_type return_url}] \
	  -delete.href [export_vars -base delete-type {object_type}] \
	  -edit.title  [_ xotcl-core.add [list type [$object_type pretty_name]]] \
	  -delete.title  "Delete all [$object_type pretty_plural] of this instance"
    }

set t1 [t1 asHTML]

# set up categories
set category_map_url [export_vars -base \
	  [site_node::get_package_url -package_key categories]cadmin/one-object \
			  { { object_id $package_id } }]