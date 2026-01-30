ad_include_contract {
  View a page
} {
  item_id:naturalnum,optional
  url:localurl,optional
  template_file:optional
}

set parameter [subst {
  {-m:token view}
  {-return_url "[ns_conn url]"}
  {-template_file "view-links"}
  {-folder_id 0}
}]

if {[info exists url]} {
  #
  # New style, the URL is sufficient
  #
  ::xowiki::Package initialize \
      -parameter $parameter \
      -url $url \
      -actual_query [export_vars -no_empty template_file]
} else {
  #
  # Old style, use item_id.
  #
  # TODO: This branch should be removed after the release of OpenACS 5.10
  #
  #ns_log warning "deprecated call of xowiki/lib/view.tcl: use 'url' as parameter instead"
  #
  #set page [::xowiki::Package instantiate_page_from_id \
  #              -item_id $item_id \
  #              -parameter $parameter]
  #  ::xo::cc export_vars

  ad_log_deprecated "view.tcl" "item_id $item_id" "-url $url"
}

template::head::add_css \
    -href urn:ad:css:xowiki-[::xowiki::CSS toolkit]

set html [::$package_id invoke -method $m]

if {[info exists css]} {
  set html $css$html
}

# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
