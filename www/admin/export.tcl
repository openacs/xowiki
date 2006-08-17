::xowiki::Package initialize -ad_doc {
  export the objects of the specified type

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Aug 11, 2006
  @cvs-id $Id$

  @param object_type 
} -parameter {
  {-object_type ::xowiki::Page}
}

set sql [$object_type instance_select_query \
             -folder_id [::$package_id folder_id] \
             -with_subtypes true]

set content ""
db_foreach instance_select $sql {
  ::Generic::CrItem instantiate -item_id $item_id
  $item_id volatile
  append content [::Serializer deepSerialize $item_id] \n
}

ns_return 200 text/plain $content