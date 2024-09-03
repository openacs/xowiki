::xowiki::Package initialize -ad_doc {
  Add an element to a given portal

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Oct 23, 2005
  @cvs-id $Id$

} -parameter {
  {-element_id}
  {-portal_id}
  {-referrer .}
}

# permissions?
portal::remove_element -element_id $element_id
# redirect and abort
ad_returnredirect $referrer
ad_script_abort


# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
