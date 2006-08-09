ad_page_contract {
  This deletes a type with all subtypes and instances
  
  @author Your Name (you@example.com)
  @cvs-id $Id$
  
  @param object_type the class name of an instance of CrClass
} -query {
  object_type
  {query "."}
}

set p [::xowiki::Package create ::[ad_conn package_id]]

db_foreach retrieve_instances [$object_type instance_select_query -folder_id [$p set folder_id]] {
  permission::require_write_permission -object_id $item_id
  $object_type delete -item_id $item_id
}

# drop type requires that all pages of all xowiki instances are deleted
#foreach type [$object_type object_types -subtypes_first true] {$type drop_object_type}

ad_returnredirect $query
