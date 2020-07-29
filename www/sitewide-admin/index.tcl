ad_page_contract {
    @author Gustaf Neumann

    @creation-date July, 2020
} {
}
set version 1.2.0
set resource_info [::xowiki::bootstrap-treeview::resource_info -version $version]
set resoure_name  [dict get $resource_info resourceName]
set title "$resoure_name - Sitewide Admin"
set download_url download?version=$version
set context [list $title]


# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
