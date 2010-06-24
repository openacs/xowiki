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
    $package_id get_lang_and_name -default_lang [::xo::cc lang] -path $o lang stripped_name
    set parent_id [$package_id get_parent_and_name -lang $lang \
		       -path $stripped_name -parent_id $folder_id \
		       parent local_name]
    ns_log notice "lookup of $o in $folder_id returns [::xo::db::CrClass lookup -name $o -parent_id $parent_id]"
    if {[set item_id [::xo::db::CrClass lookup -name $local_name -parent_id $parent_id]] != 0} {
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
  if {[catch {set obj [$item_id marshall]} errorMsg]} {
    ns_log error "Error while exporting $item_id [$item_id name]\n$errorMsg\n$::errorInfo"
  } else {
    ns_write "$obj\n" 
  }
}

#ns_return 200 text/plain $content
