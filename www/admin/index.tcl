::xowiki::Package initialize -ad_doc {

  This is the admin page for the package.  It displays all of the types 
  of wiki pages provides links to delete them

  @author Gustaf Neumann neumann@wu-wien.ac.at
  @cvs-id $Id$

} -parameter {
  {-object_type ::xowiki::Page}
}

set context [list]
set title "Administer all kind of [$object_type set pretty_plural]"

set object_type_key [$object_type set object_type_key]
set object_types    [$object_type object_types]
set return_url      [ns_conn url]

TableWidget t1 -volatile \
    -actions [subst {
      Action new -label "all pages" -url list
      Action new -label parameters -url \
          [export_vars -base /shared/parameters {package_id return_url}]
      Action new -label export -url export
      Action new -label import -url import
      Action new -label permissions -url [export_vars -base permissions {package_id}]
    }] \
    -columns {
      Field object_type -label [_ xowiki.page_type]
      AnchorField instances -label Instances -html {align center}
      ImageField_AddIcon edit -label "Add" -html {align center}
      ImageField_DeleteIcon delete -label "Delete All" \
          -html {align center onClick "return(confirm('Delete really all?'));"}
    }

set base [::$package_id package_url]
foreach object_type $object_types {
  set return_url [export_vars -base ${base}admin {object_type}]
  set add_title ""
  set add_href ""
  if {[catch {set n [db_list count [$object_type instance_select_query \
                                       -folder_id [::$package_id set folder_id] \
                                       -count 1 -with_subtypes false]]}]} {
    set n -
    set delete_title "Delete all such items of this instance"
  } else {
    set add_title [_ xotcl-core.add [list type [$object_type pretty_name]]]
    set add_href  [$package_id make_link $package_id edit-new object_type return_url autoname]
    set delete_title "Delete all [$object_type pretty_plural] of this instance"
  }
  t1 add \
      -object_type  $object_type \
      -instances    $n \
      -instances.href [export_vars -base ./list {object_type}] \
      -edit.href    $add_href \
      -delete.href  [export_vars -base delete-type {object_type}] \
      -edit.title   $add_title \
      -delete.title $delete_title
}

set t1 [t1 asHTML]

# set up categories
set category_map_url [export_vars -base \
          [site_node::get_package_url -package_key categories]cadmin/object-map \
                          { { object_id $package_id } }]