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
ns_set put [ns_conn outputheaders] "Content-Type" "text/plain"
ns_set put [ns_conn outputheaders] "Content-Disposition" "attachment;filename=export.xotcl"
ReturnHeaders 

foreach item_id $item_ids {
  # check, if the page was already included
  if {[info exists included($item_id)]} {continue}

  ::xo::db::CrClass get_instance_from_db -item_id $item_id
  #
  # if the page belongs to an Form/PageTemplate, include it as well
  #
  if {[$item_id istype ::xowiki::PageInstance]} {
    set template_id [$item_id page_template]
    while {1} {
      if {![info exists included($template_id)]} {
        set x [::xo::db::CrClass get_instance_from_db -item_id $template_id]
        $template_id volatile
        ns_log notice "--exporting needed [$item_id name] ($template_id) //$x [$x info class], m=[$template_id marshall] "
        #append content [$template_id marshall] \n
        ns_write "[$template_id marshall] \n" 
        set included($template_id) 1
      }
      if {![::xo::db::CrClass isobject $template_id]} {
        ::xo::db::CrClass get_instance_from_db -item_id $template_id
      }
      # in case, the template_id has another template,
      # iterate...
      if {[$template_id istype ::xowiki::PageInstance]} {
        set template_id [$template_id page_template]
      } else {
        break
      }
    }
  }
  $item_id volatile
  ns_log notice "--exporting $item_id [$item_id name]"
  #append content [$item_id marshall] \n
  ns_write "[$item_id marshall] \n" 
}

#ns_return 200 text/plain $content
