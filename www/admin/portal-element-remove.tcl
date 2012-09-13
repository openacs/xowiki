::xowiki::Package initialize -ad_doc {
  Add an element to a given portal

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Oct 23, 2005
  @cvs-id $Id$

} -parameter {
  {-element_id}
  {-portal_id}
  {-referer .}
}

# permissions?
portal::remove_element -element_id $element_id
# redirect and abort
ad_returnredirect $referer
ad_script_abort

