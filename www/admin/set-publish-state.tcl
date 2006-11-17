::xowiki::Package initialize -ad_doc {
  Changes the publication state of a content item

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Nov 16, 2006
  @cvs-id $Id$

  @param object_type 
  @param query
} -parameter {
  {-state:required}
  {-revision_id:required}
  {-return_url "."}
}

db_0or1row make_live {select content_item__set_live_revision(:revision_id,:state)}

ad_returnredirect $return_url
