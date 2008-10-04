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

ns_log notice "objects=$objects"
#
# In a first step, get the items_ids of the objects which are explicitly exported
#
if {$objects eq ""} {
  set sql [$object_type instance_select_query -folder_id $folder_id -with_subtypes true]
  db_foreach instance_select $sql { set items($item_id) 1 }
} else {
  foreach o $objects {
    ns_log notice "lookup of $o in $folder_id returns [::xo::db::CrClass lookup -name $o -parent_id $folder_id]"
    if {[set item_id [::xo::db::CrClass lookup -name $o -parent_id $folder_id]] != 0} {
      set items($item_id) 1 
    }
  }
}

#
# In a second step, include the objects which should be exported implicitly
#
foreach item_id [array names items] {
  # 
  # load the objects
  #
  ::xo::db::CrClass get_instance_from_db -item_id $item_id
}

while {1} {
  set new 0
  ns_log notice "--export works on [array names items]"
  foreach item_id [array names items] {
    #
    # For PageInstances (or its subtypes), include the parent-objects as well
    #
    if {[$item_id istype ::xowiki::PageInstance]} {
      set template_id [$item_id page_template]
      if {![info exists items($template_id)]} {
        ns_log notice "--export including parent-object $template_id [$template_id name]"
        set items($template_id) 1
        ::xo::db::CrClass get_instance_from_db -item_id $template_id
        set new 1
      }
    }
    #
    # check for child objects of the item
    #
    set sql [$object_type instance_select_query -folder_id $item_id -with_subtypes true]
    db_foreach instance_select $sql {
      if {![info exists items($item_id)]} {
        ::xo::db::CrClass get_instance_from_db -item_id $item_id
        ns_log notice "--export including child $item_id [$item_id name]"
        set items($item_id) 1 
        set new 1
      }
    }
  }
  if {!$new} break
}

set content ""
ns_set put [ns_conn outputheaders] "Content-Type" "text/plain"
ns_set put [ns_conn outputheaders] "Content-Disposition" "attachment;filename=export.xotcl"
ReturnHeaders 

foreach item_id [array names items] {
  ns_log notice "--exporting $item_id [$item_id name]"
  #append content [$item_id marshall] \n
  ns_write "[$item_id marshall] \n" 
}

#ns_return 200 text/plain $content
