::xowiki::Package initialize -ad_doc {
  this file is called by the bulk action of admin/list

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Nov 11, 2007
  @cvs-id $Id$

  @param object_type
} -parameter {
  {-objects ""}
}

foreach item_id [$package_id get_ids_for_bulk_actions $objects] {
  ns_log notice "DELETE $item_id"
  ::$package_id www-delete -item_id $item_id
}

ad_returnredirect "./list"
ad_script_abort

# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
