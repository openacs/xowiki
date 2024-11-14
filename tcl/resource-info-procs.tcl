::xo::library doc {
  Classes for creating, manageing and rendering trees

  @creation-date 2009-05-29
  @author Gustaf Neumann
  @cvs-id $Id$
}

namespace eval ::xowiki::bootstrap_treeview {

  ad_proc -private ::xowiki::bootstrap_treeview::resource_info {
    {-version ""}
  } {

    Get information about available version(s) of bootstrap-treeview either
    from the local filesystem, or from CDN.

  } {
    set parameter_info {
        package_key xowiki
        parameter_name BootstrapTreeviewVersion
        default_value 1.2.0
    }

    if {$version eq ""} {
      dict with parameter_info {
        set version [::parameter::get_global_value \
                         -package_key $package_key \
                         -parameter $parameter_name \
                         -default $default_value]
      }
    }
    #
    # Setup variables for access via CDN vs. local resources.
    #
    set resourceDir [acs_package_root_dir xowiki/www/resources/bootstrap-treeview]
    set cdn         //cdnjs.cloudflare.com/ajax/libs/bootstrap-treeview

    if {[file exists $resourceDir/$version/bootstrap-treeview.min.css]} {
      set prefix  /resources/xowiki/bootstrap-treeview/$version
      set cdnHost ""
      set cspMap ""
    } else {
      set prefix $cdn/$version
      set cdnHost cdnjs.cloudflare.com
      dict set cspMap ad:css:bootstrap3-treeview style-src $cdnHost
      dict set cspMap urn:ad:js:bootstrap3-treeview script-src $cdnHost
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
        cssFiles {bootstrap-treeview.min.css} \
        jsFiles  {bootstrap-treeview.min.js} \
        extraFiles {} \
        cspMap $cspMap \
        urnMap {
          urn:ad:css:bootstrap3-treeview bootstrap-treeview.min.css
          urn:ad:js:bootstrap3-treeview  bootstrap-treeview.min.js
        } \
        versionCheckAPI {cdn cdnjs library bootstrap-treeview count 1} \
        vulnerabilityCheck {service snyk library bootstrap-treeview} \
        parameterInfo $parameter_info \
        configuredVersion $version

    return $result
  }
}


namespace eval ::xowiki::jquery {

  ad_proc -private ::xowiki::jquery::resource_info {
    {-version ""}
  } {

    Get information about available version(s) of jquery either
    from the local filesystem, or from CDN.

  } {
    set parameter_info {
        package_key xowiki
        parameter_name JqueryVersion
        default_value 3.7.1
    }

    if {$version eq ""} {
      dict with parameter_info {
        set version [::parameter::get_global_value \
                         -package_key $package_key \
                         -parameter $parameter_name \
                         -default $default_value]
      }
    }
    #
    # Setup variables for access via CDN vs. local resources.
    #
    set resourceDir [acs_package_root_dir xowiki/www/resources/jquery]
    set cdn         //cdnjs.cloudflare.com/ajax/libs/jquery

    set path $resourceDir/$version/jquery.min.js
    ns_log notice "jquery: check $path ->" [file exists $path]

    if {[file exists $path]} {
      set prefix  /resources/xowiki/jquery/$version
      set cdnHost ""
      set cspMap ""
    } else {
      set prefix $cdn/$version
      set cdnHost cdnjs.cloudflare.com
      dict set cspMap urn:ad:js:jquery script-src $cdnHost
    }

    #
    # Return the dict with at least the required fields
    #
    lappend result \
        resourceName "jquery" \
        resourceDir $resourceDir \
        cdn $cdn \
        cdnHost $cdnHost \
        prefix $prefix \
        cssFiles {} \
        jsFiles  {jquery.min.js} \
        extraFiles {} \
        cspMap $cspMap \
        urnMap {urn:ad:js:jquery jquery.min.js} \
        versionCheckAPI {cdn cdnjs library jquery count 1} \
        vulnerabilityCheck {service snyk library jquery} \
        parameterInfo $parameter_info \
        configuredVersion $version

    return $result
  }
}


namespace eval ::xowiki::jqueryui {

  ad_proc -private ::xowiki::jqueryui::resource_info {
    {-version ""}
  } {

    Get information about available version(s) of jqueryui either
    from the local filesystem, or from CDN.

  } {
    set parameter_info {
        package_key xowiki
        parameter_name JqueryuiVersion
        default_value 1.14.1
    }

    if {$version eq ""} {
      dict with parameter_info {
        set version [::parameter::get_global_value \
                         -package_key $package_key \
                         -parameter $parameter_name \
                         -default $default_value]
      }
    }
    #
    # Setup variables for access via CDN vs. local resources.
    #
    set resourceDir [acs_package_root_dir xowiki/www/resources/jqueryui]
    set cdn         //cdnjs.cloudflare.com/ajax/libs/jqueryui

    set path $resourceDir/$version/jquery-ui.min.js
    ns_log notice "jquery-ui: check $path ->" [file exists $path]

    if {[file exists $path]} {
      set prefix  /resources/xowiki/jqueryui/$version
      set cdnHost ""
      set cspMap ""
    } else {
      set prefix $cdn/$version
      set cdnHost cdnjs.cloudflare.com
      dict set cspMap urn:ad:css:jqueryui style-src $cdnHost
      dict set cspMap urn:ad:js:jqueryui script-src $cdnHost
    }

    #
    # Return the dict with at least the required fields
    #
    lappend result \
        resourceName "jquery-ui" \
        resourceDir $resourceDir \
        cdn $cdn \
        cdnHost $cdnHost \
        prefix $prefix \
        cssFiles {themes/base/jquery-ui.min.css} \
        jsFiles  {jquery-ui.min.js} \
        extraFiles {} \
        cspMap $cspMap \
        urnMap {
          urn:ad:css:jquery-ui themes/base/jquery-ui.min.css
          urn:ad:js:jquery-ui jquery-ui.min.js
        } \
        versionCheckAPI {cdn cdnjs library jqueryui count 5} \
        vulnerabilityCheck {service snyk library jquery-ui} \
        parameterInfo $parameter_info \
        configuredVersion $version

    return $result
  }
}

namespace eval ::xowiki::jqueryui_touchpunch {

  ad_proc -private ::xowiki::jqueryui_touchpunch::resource_info {
    {-version ""}
  } {

    Get information about available version(s) of jqueryui-touch-punch either
    from the local filesystem, or from CDN.

  } {
    set parameter_info {
        package_key xowiki
        parameter_name JqueryuiTouchPunchVersion
        default_value 0.2.3
    }

    if {$version eq ""} {
      dict with parameter_info {
        set version [::parameter::get_global_value \
                         -package_key $package_key \
                         -parameter $parameter_name \
                         -default $default_value]
      }
    }
    #
    # Setup variables for access via CDN vs. local resources.
    #
    set resourceDir [acs_package_root_dir xowiki/www/resources/jqueryui-touch-punch]
    set cdn         //cdnjs.cloudflare.com/ajax/libs/jqueryui-touch-punch

    set path $resourceDir/$version/jquery.ui.touch-punch.min.js
    ns_log notice "jqueryui-touch-punch: check $path ->" [file exists $path]

    if {[file exists $path]} {
      set prefix  /resources/xowiki/jqueryui-touch-punch/$version
      set cdnHost ""
      set cspMap ""
    } else {
      set prefix $cdn/$version
      set cdnHost cdnjs.cloudflare.com
      dict set cspMap urn:ad:js:jqueryui-touch-punch script-src $cdnHost
    }

    #
    # Return the dict with at least the required fields
    #
    lappend result \
        resourceName "jqueryui-touch-punch" \
        resourceDir $resourceDir \
        cdn $cdn \
        cdnHost $cdnHost \
        prefix $prefix \
        cssFiles {} \
        jsFiles  {jquery.ui.touch-punch.min.js} \
        extraFiles {} \
        cspMap $cspMap \
        urnMap {
          urn:ad:js:jquery-ui-touch-punch jquery.ui.touch-punch.min.js
        } \
        versionCheckAPI {cdn cdnjs library jqueryui-touch-punch count 1} \
        vulnerabilityCheck {service snyk library jquery-ui-touch-punch} \
        parameterInfo $parameter_info \
        configuredVersion $version

    return $result
  }
}




# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
