::xo::library doc {
  Classes for creating, manageing and rendering trees

  @creation-date 2009-05-29
  @author Gustaf Neumann
  @cvs-id $Id$
}

namespace eval ::xowiki::bootstrap_treeview {

  ad_proc -private ::xowiki::bootstrap_treeview::resource_info {
    {-version "1.2.0"}
  } {

    Get information about available version(s) of bootstrap-treeview either
    from the local filesystem, or from CDN.

  } {
    #
    # Setup variables for access via CDN vs. local resources.
    #
    set resourceDir [acs_package_root_dir xowiki/www/resources/bootstrap-treeview]
    set resourceUrl /resources/xowiki/bootstrap-treeview
    set cdn         //cdnjs.cloudflare.com/ajax/libs/bootstrap-treeview

    if {[file exists $resourceDir/$version/bootstrap-treeview.min.css]} {
      set prefix  $resourceUrl/$version
      set cdnHost ""
    } else {
      set prefix $cdn/$version
      set cdnHost cdnjs.cloudflare.com
    }

    #
    # Return the dict with at least the required fields
    #
    lappend result \
        resourceName "bootstrap-treeview" \
        resourceDir $resourceDir \
        cdn $cdn \
        cdnHost $cdnHost \
        prefix $prefix \
        versionCheckURL "https://cdnjs.com/libraries?q=bootstrap-treeview" \
        cssFiles {bootstrap-treeview.min.css} \
        jsFiles  {bootstrap-treeview.min.js} \
        extraFiles {} \
        urnMap {
          urn:ad:css:bootstrap3-treeview bootstrap-treeview.min.css
          urn:ad:js:bootstrap3-treeview  bootstrap-treeview.min.js
        }

    if {$cdnHost ne ""} {
      lappend result csp_lists [subst {
        urn:ad:css:bootstrap3-treeview {
          style-src $cdnHost
        }
        urn:ad:js:bootstrap3-treeview {
          script-src $cdnHost
        }
      }]
    }
    return $result
  }
}


# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
