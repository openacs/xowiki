::xowiki::Package initialize -ad_doc {
  export the objects of the specified type

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Aug 11, 2006
  @cvs-id $Id$

  @param object_type 
} -parameter {
  {-object_type ::xowiki::Page}
  {-objects ""}
}

set folder_id [::$package_id folder_id]
set item_ids [list] 

if {$objects eq ""} {
  set sql [$object_type instance_select_query -folder_id $folder_id -with_subtypes true]
  db_foreach instance_select $sql { lappend item_ids $item_id }
} else {
  foreach o $objects {
    if {[set id [::xo::db::CrClass lookup -name $o -parent_id $folder_id]] != 0} {
      lappend item_ids $id
    }
  }
}

set content ""
foreach item_id $item_ids {
  ::xo::db::CrClass get_instance_from_db -item_id $item_id
  #
  # if the page belongs to an Form/PageTemplate, include it as well
  #
  if {[$item_id istype ::xowiki::PageInstance]} {
    set template_id [$item_id page_template]
    if {[lsearch $item_ids $template_id] == -1 &&
        ![info exists included($template_id)]} {
      ::xo::db::CrClass get_instance_from_db -item_id $template_id
      $template_id volatile
      append content [$template_id marshall] \n
      set included($template_id) 1
    }
  }
  $item_id volatile
  #ns_log notice "exporting $item_id [$item_id name]"
  append content [$item_id marshall] \n
}

ns_return 200 text/plain $content
