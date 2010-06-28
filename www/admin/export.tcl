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
    #ns_log notice "lookup of $o in $folder_id returns [::xo::db::CrClass lookup -name $o -parent_id $parent_id]"
    if {[set item_id [::xo::db::CrClass lookup -name $local_name -parent_id $parent_id]] != 0} {
      set items($item_id) 1 
    }
  }
}

#
# The exporter exports the specified objects together with implicitely
# needed objects.
#
::xowiki::::exporter export [array names items]

