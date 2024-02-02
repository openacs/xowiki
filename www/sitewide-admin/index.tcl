ad_page_contract {
    @author Gustaf Neumann

    @creation-date July, 2020
} {
}
set title "[::xowiki::Package pretty_name] - Site-wide Admin"
set package_key [::xowiki::Package package_key]
set version 1.2.0
set resource_info [::xowiki::bootstrap_treeview::resource_info -version $version]
set resoure_name  [dict get $resource_info resourceName]
set resource_title "Static resources"
set download_url download?version=$version
set context [list $title]


# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
