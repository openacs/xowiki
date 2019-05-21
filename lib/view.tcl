set parameter [subst {
  {-m view}
  {-return_url "[ns_conn url]"}
  {-template_file "view-links"}
  {-folder_id 0}
}]

# TODO the following should be done more elegantly
set actual_query [expr {[info exists template_file] ? "template_file=$template_file" : " "}]

if {[info exists url]} {
  #
  # New style, the URL is sufficient
  #
  ::xowiki::Package initialize \
      -parameter $parameter \
      -url $url \
      -actual_query $actual_query
} else {
  #
  # Old style, use item_id.
  #
  # TODO: This branch should be removed after the release of OpenACS 5.10
  #
  ns_log warning "deprecated call of xowiki/lib/view.tcl: use 'url' as parameter instead"

  set page [::xowiki::Package instantiate_page_from_id \
                -item_id $item_id \
                -parameter $parameter]
    ::xo::cc export_vars
}

template::head::add_css \
    -href urn:ad:css:xowiki-[::xowiki::Package preferredCSSToolkit]

set html [::$package_id invoke -method $m]

if {[info exists css]} {
  set html $css$html
}




# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
