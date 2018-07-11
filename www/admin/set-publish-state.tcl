::xowiki::Package initialize -ad_doc {
  Changes the publication state of a content item

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Nov 16, 2006
  @cvs-id $Id$

  @param object_type 
  @param query
} -parameter {
  {-state:required}
  {-revision_id:integer,required}
  {-return_url "."}
}

set page [::xo::db::CrClass get_instance_from_db -revision_id $revision_id]
$page set_live_revision \
    -revision_id $revision_id \
    -publish_status $state

::xo::xotcl_object_cache flush $revision_id

if {$state ne "production"} {
  ::xowiki::notification::do_notifications -revision_id $revision_id
  ::xowiki::datasource $revision_id
} else {
  db_dml flush_syndication {delete from syndication where object_id = :revision_id}
}

ad_returnredirect $return_url
ad_script_abort

# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
