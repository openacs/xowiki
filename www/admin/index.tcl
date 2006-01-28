ad_page_contract {
  This is the admin page for the package.  It displays all of the types 
  of wiki pages provides links to delete them

  @author Gustaf Neumann neumann@wu-wien.ac.at
  @cvs-id $Id$
} -query {
  object_type:optional
}

set context [list]
set supertype ::xowiki::Page
set page_title "Administer all kind of [$supertype set pretty_plural]"

set object_type_key [$supertype set object_type_key]
set folder_id       [$supertype require_folder -name xowiki]
set object_types    [$supertype object_types]

TableWidget t1 -volatile \
    -actions {
      Action new -label export -url export
      Action new -label import -url import
    } \
    -columns {
      Field object_type -label [_ xowiki.page_type]
      AnchorField instances -label Instances -html {align center}
      ImageField_AddIcon edit -label "Add" -html {align center}
      ImageField_DeleteIcon delete -label "Delete" -html {align center}
    }

db_foreach type_select \
    "select object_type from acs_object_types where 
        tree_sortkey between :object_type_key and tree_right(:object_type_key)
    " {
      t1 add \
	  -object_type $object_type \
	  -instances [db_list count [$object_type instance_select_query \
					 -folder_id $folder_id -count 1 -with_subtypes false]] \
	  -instances.href [export_vars -base ../index {object_type}] \
	  -edit.href   [export_vars -base ../edit {object_type folder_id}] \
	  -delete.href [export_vars -base delete-type {object_type}] \
	  -edit.title  [_ xotcl-core.add [list type [$object_type pretty_name]]] \
	  -delete.title  "Delete Type [$object_type pretty_name]"
    }

set t1 [t1 asHTML]
