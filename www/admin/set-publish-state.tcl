::xowiki::Package initialize -ad_doc {
  Changes the publication state of a content item

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Nov 16, 2006
  @cvs-id $Id$

  @param object_type
  @param query
} -parameter {
  {-state:wordchar,required}
  {-revision_id:integer,required}
  {-return_url:localurl "."}
}

set page [::xo::db::CrClass get_instance_from_db -revision_id $revision_id]
# ensure page is from the current package
if {$package_id != [$page package_id] || $state ni {production ready live expired}} {
  ad_return_forbidden
  ad_script_abort
}

$page update_publish_status $state

ad_returnredirect $return_url
ad_script_abort

# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
