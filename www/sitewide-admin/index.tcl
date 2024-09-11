ad_page_contract {
    @author Gustaf Neumann

    @creation-date July, 2020
} {
}
set title "[::xowiki::Package pretty_name] - Site-wide Admin"
set context [list $title]
set package_key [::xowiki::Package package_key]
set resource_title "Static resources"

set resource_info1 [::xowiki::bootstrap_treeview::resource_info]
set version1 [dict get $resource_info1 configuredVersion]
set resoure_name1  [dict get $resource_info1 resourceName]
set download_url1 [ad_conn url]/download?version=$version1&lib=bootstrap_treeview

set resource_info2 [::xowiki::jquery::resource_info]
set version2 [dict get $resource_info2 configuredVersion]
set resoure_name2  [dict get $resource_info2 resourceName]
set download_url2 [ad_conn url]/download?version=$version2&lib=jquery

set resource_info3 [::xowiki::jqueryui::resource_info]
set version3 [dict get $resource_info3 configuredVersion]
set resoure_name3  [dict get $resource_info3 resourceName]
set download_url3 [ad_conn url]/download?version=$version3&lib=jqueryui

set resource_info4 [::xowiki::jqueryui_touchpunch::resource_info]
set version4 [dict get $resource_info4 configuredVersion]
set resoure_name4  [dict get $resource_info4 resourceName]
set download_url4 [ad_conn url]/download?version=$version4&lib=jqueryui_touchpunch


# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
