ad_library {
    XoWiki - Search Service Contracts

    @creation-date 2006-01-10
    @author Gustaf Neumann
    @cvs-id $Id$
}

namespace eval ::xowiki {}

ad_proc -private ::xowiki::datasource { revision_id } {
    @param revision_id

  returns a datasource for the search package
} {
  #ns_log notice "--datasource called with revision_id = $revision_id"

  set page [::Generic::CrItem instantiate -item_id 0 -revision_id $revision_id]
  $page volatile
  set content [expr {[$page set object_type] eq "::xowiki::PlainPage" ?
		     [$page set text] : [lindex [$page set text] 0]}]
  $page set unresolved_references 0
  set content [ad_html_text_convert -from [$page set mime_type] -to text/plain -- $content]
		   
  #ns_log notice "--datasource content=$content, oid=$revision_id"
  return [list object_id $revision_id title  [$page set title] \
                content $content keywords {} \
                storage_type text mime text/plain ]
}

ad_proc -private ::xowiki::url { revision_id } {
    @param revision_id

    returns a url for a message to the search package
} {
  set page [::Generic::CrItem instantiate -item_id 0 -revision_id $revision_id]
  $page volatile
  set folder_id [$page set parent_id]
  set pid [db_string get_package_id \
	       "select package_id from acs_objects where object_id = $folder_id"]
  if {$pid > 0} {
    return "[site_node::get_url_from_object_id -object_id $pid]pages/[ad_urlencode [$page set title]]"
  } else {
    # cannot determine package_id; one page from the directory should be viewed to update 
    # package id for the content folder...
    return "cannot determine package_id, view a page from the folder containing page \
	[$page set title]"
  }
}



namespace eval ::xowiki::sc {}

ad_proc -private ::xowiki::sc::register_implementations {} {
    Register the content type fts contract
} {
   acs_sc::impl::new_from_spec -spec {
      name "::xowiki::Page"
      aliases {
	datasource ::xowiki::datasource
	url ::xowiki::url
      }
      contract_name FtsContentProvider
      owner xowiki
    }
    acs_sc::impl::new_from_spec -spec {
      name "::xowiki::PlainPage"
      aliases {
	datasource ::xowiki::datasource
	url ::xowiki::url
      }
      contract_name FtsContentProvider
      owner xowiki
    }
}

ad_proc -private ::xowiki::sc::unregister_implementations {} {
  acs_sc::impl::delete -contract_name FtsContentProvider -impl_name ::xowiki::Page
  acs_sc::impl::delete -contract_name FtsContentProvider -impl_name ::xowiki::PlainPage
}


