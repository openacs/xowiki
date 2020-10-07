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
  xo::dc foreach instance_select $sql {
    set items($item_id) 1
  }
} else {
  ns_log notice "OBJECTS <$objects>"
  foreach item_id [$package_id get_ids_for_bulk_actions $objects] {
    set items($item_id) 1
  }
}

#
# The exporter exports the specified objects together with implicitly
# needed objects.
#
::xowiki::exporter export [array names items]
ns_conn close

# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
