::xo::library doc {
  XoWiki - Search Service Contracts

  @creation-date 2006-01-10
  @author Gustaf Neumann
  @cvs-id $Id$
}

namespace eval ::xowiki {}

ad_proc -private ::xowiki::datasource { -nocleanup:boolean revision_id } {
  @param revision_id

  returns a datasource for the search package
} {
  set d [list \
             object_id $revision_id \
             title "" \
             content "" \
             text "" \
             html "" \
             keywords "" \
             storage_type text \
             mime text/html \
            ]

  try {
    #ns_log notice "--sc ::xowiki::datasource called with revision_id = $revision_id"
    set page [::xowiki::Package instantiate_page_from_id -revision_id $revision_id -user_id 0]
  } on error {errmsg} {
    ns_log warning ::xowiki::datasource \
        {Could not instantiate page} $revision_id $errmsg
    return $d
  }

  #ns_log notice "--sc ::xowiki::datasource $page [$page set publish_status]"

  if {[$page set publish_status] in {production expired}} {
    #
    # No data source result for pages under construction
    #
    #ns_log notice "--sc page under construction, no datasource"
    return $d
  }

  #ns_log notice "--sc setting absolute links for page = $page [$page set name]"

  try {
    set d [dict merge $d [$page search_render]]
  } on error {errmsg} {
    ns_log warning ::xowiki::datasource \
        {Could not render page} $revision_id $errmsg
    return $d
  }

  if {[dict get $d title] eq ""} {
    dict set d title [$page title]
  }
  switch [dict get $d mime] {
    text/html {
      set content [dict get $d html]
      if {![string is space $content]} {
        try {
          dom parse -simple -html <html>$content doc
          $doc documentElement root
          foreach n [$root selectNodes {//script|//noscript|//style//nav|//button}] {
            $n delete
          }
          set content [$root asHTML]
        } on error {errorMsg} {
          ns_log notice "xowiki::datasource: could not parse result of search_render for page $page: $errorMsg"
        }
      }
      #
      # The function ad_html_text_convert can take forever on largish
      # files, when e.g. someone loads a huge content into xowiki.
      # So, when available, and performance is an issue, one could
      # consider to use "ns_striphtml", but this produces no nice
      # rendering, so text base syndication will suffer. For now,
      # "ns_striphtml" is deactivated.
      #
      if {0 && [info commands ns_striphtml] ne ""} {
        set text [ns_striphtml [dict get $d html]]
      } else {
        set text [ad_html_text_convert -from text/html -to text/plain -- [dict get $d html]]
        #set text [ad_text_to_html -- [dict get $d html]]; #this could be used for entity encoded html text in rss entries
      }

      # If the html contains links (which are rendered by ad_html_text as [1], [2], ...)
      # then we have to use CDATA in the description
      #
      if {[string first {[1]} $text] > -1} {
        append description {<![CDATA[} \n $content { ]]>}
      } else {
        set description [ns_quotehtml $text]
      }
    }
    text/plain {
      set content [dict get $d text]
      set description $content
    }
    default {
      ns_log error "can't handle results of search_render of type '[dict get $d mime]'"
      set content ""
      set description ""
    }
  }

  #ns_log notice "--sc INDEXING $revision_id -> $text keywords [dict get $d keywords]"

  #
  # cleanup old stuff. This might run into an error, when search is not
  # configured, and therefore txt does not exist. TODO: we should look for a better
  # solution, where syndication does not depend on search....
  #
  $page instvar item_id
  if {[::xo::db::require exists_table txt]} {
    ::xo::dc dml delete_old_revisions {
      delete from txt where object_id in \
          (select revision_id from cr_revisions
           where item_id = :item_id and revision_id != :revision_id)
    }
  }

  set pubDate [::xo::db::tcl_date [$page set publish_date] tz]
  set link [$page detail_link]

  set result [list object_id $revision_id title [dict get $d title] \
                  content $content \
                  keywords [dict get $d keywords] \
                  storage_type text mime [dict get $d mime] \
                  syndication [list \
                                   link [string map [list & "&amp;"] $link] \
                                   description $description \
                                   author [$page set creator] \
                                   category "" \
                                   guid "$item_id" \
                                   pubDate $pubDate] \
                 ]
  if {!$nocleanup_p && [catch {::xo::at_cleanup} errorMsg]} {
    ns_log notice "cleanup in ::xowiki::datasource returned $errorMsg"
  }
  return $result
}

ad_proc -private ::xowiki::url { revision_id} {
  returns a URL for a message to the search package
} {
  return [::xowiki::Package get_url_from_id -revision_id $revision_id]
}


namespace eval ::xowiki::sc {

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
    acs_sc::impl::new_from_spec -spec {
      name "::xowiki::FormPage"
      aliases {
        datasource ::xowiki::datasource
        url ::xowiki::url
      }
      contract_name FtsContentProvider
      owner xowiki
    }
    acs_sc::impl::new_from_spec -spec {
      name "::xowiki::File"
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
    acs_sc::impl::delete -contract_name FtsContentProvider -impl_name ::xowiki::FormPage
    acs_sc::impl::delete -contract_name FtsContentProvider -impl_name ::xowiki::File
  }
}

::xo::library source_dependent

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
