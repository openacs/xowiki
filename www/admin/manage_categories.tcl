::xowiki::Package initialize -ad_doc {
  Redirector to call categories interface

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date January 2009
  @cvs-id $Id$

  @param object_id
} -parameter {
  {-object_id:required}
}

#
# The primary prupose of this miniscript is the make sure to flush the
# page fragement cache of categories, when categories are edited;
# better would be some kind of callback from categories.
#
# flush could be made in the future more precise
#
$package_id flush_page_fragment_cache -scope agg

ad_returnredirect [site_node::get_package_url -package_key categories]cadmin/object-map?ctx_id=$object_id&object_id=$object_id

