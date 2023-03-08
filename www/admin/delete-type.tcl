::xowiki::Package initialize -ad_doc {
  This deletes a type with all subtypes and instances

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Aug 11, 2006
  @cvs-id $Id$

  @param object_type
  @param query
} -parameter {
  {-object_type:token ::xowiki::Page}
  {-return_url:localurl "."}
}

set sql [$object_type instance_select_query \
             -with_subtypes 0 \
             -folder_id [::$package_id folder_id]]
xo::dc foreach retrieve_instances $sql {
  permission::require_write_permission -object_id $item_id
  ::$package_id www-delete -item_id $item_id -name $name
}

#
# Drop type would require that all pages of all xowiki instances are
# deleted:
#
# foreach type [$object_type object_types -subtypes_first true] {
#   $type drop_object_type
# }

ad_returnredirect $return_url
ad_script_abort

# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
