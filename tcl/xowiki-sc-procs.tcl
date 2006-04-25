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
  ns_log notice "--datasource called with revision_id = $revision_id"

  set page [::Generic::CrItem instantiate -item_id 0 -revision_id $revision_id]
  $page volatile

  # ensure context for dependencies of folder object
  set folder_id [$page set parent_id]
  ::xowiki::Page require_folder_object -folder_id $folder_id

  set html [$page render]
  set text [ad_html_text_convert -from text/html -to text/plain -- $html]
  
  ns_log notice "-- INDEXING $revision_id -> $text"
  #$page set unresolved_references 0
  $page instvar item_id

  return [list object_id $revision_id title [$page set page_title] \
	      content $text keywords {} \
	      storage_type text mime text/plain \
	      syndication [list \
			link [::xowiki::Page pretty_link -fully_qualified 1 [$page set title]] \
			description $text \
			author [$page set creator] \
			category "" \
			guid "[ad_url]/o/$item_id" \
			pubDate [$page set last_modified]] \
	     ]
}

ad_proc -private ::xowiki::url { revision_id } {
    @param revision_id

    returns a url for a message to the search package
} {
  set page [::Generic::CrItem instantiate -item_id 0 -revision_id $revision_id]
  $page volatile
  set folder_id [$page set parent_id]
  set pid [db_string get_pid "select package_id from cr_folders where folder_id = $folder_id"]
  if {$pid > 0} {
    set package_id [$folder_id set package_id]
    return [::xowiki::Page pretty_link -package_id $package_id [$page set title]]
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
    acs_sc::impl::new_from_spec -spec {
      name "::xowiki::PageInstance"
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
  acs_sc::impl::delete -contract_name FtsContentProvider -impl_name ::xowiki::PageInstance
}


