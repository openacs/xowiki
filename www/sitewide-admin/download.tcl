ad_page_contract {
    @author Gustaf Neumann

    @creation-date Jan 04, 2017
} {
    {version:token,notnull ""}
}

set resource_info [::xowiki::bootstrap_treeview::resource_info -version $version]
set resourceDir [dict get $resource_info resourceDir]
file mkdir $resourceDir/$version

if {![file writable $resourceDir/$version]} {
    error "directory $resourceDir/$version is not writable"
}

::util::resources::download -resource_info $resource_info

# foreach url [dict get $resource_info downloadURLs] {
#     set fn [file tail $url]
#     set output [exec $unzip -o $resourceDir/$version/$fn -d $resourceDir/$version]
#     file rename -- \
#                 $resourceDir/$version/ckeditor \
#                 $resourceDir/$version/$ck_package
# }

ad_returnredirect .

#https://cdnjs.cloudflare.com/ajax/libs/bootstrap-treeview/1.2.0//bootstrap-treeview.min.css
#      //cdnjs.cloudflare.com/ajax/libs/bootstrap-treeview/1.2.0/bootstrap-treeview.min.css

# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:

