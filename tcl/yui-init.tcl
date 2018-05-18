#
# URN registry for YUI2 resources, either from ajaxhelper or from CDN
#

set YUI_CSS_PATHS {
    assets/skins/sam/skin
    base/base
    button/assets/skins/sam/button
    container/assets/container
    datatable/assets/skins/sam/datatable
    fonts/fonts-min
    grids/grids
    menu/assets/skins/sam/menu
    reset/reset
    reset-fonts-grids/reset-fonts-grids
    treeview/assets/skins/sam/treeview
}

#
# Not all yui 2 files are available minified, so we have to specify
# manually, where we can get it
#
set YUI_JS_PATHS {
    animation/animation-min
    autocomplete/autocomplete-min
    button/button-min
    connection/connection-min
    container/container-min
    datasource/datasource-min
    datatable/datatable-min
    menu/menu-min
    selector/selector-min
    treeview/treeview-min
    utilities/utilities
    yahoo-dom-event/yahoo-dom-event
}


#
# The following asset files is up to my knowledge not available via CDN
#
template::register_urn \
    -urn      urn:ad:css:yui2:treeview/assets/tree \
    -resource /resources/ajaxhelper/yui/treeview/assets/tree.css
template::register_urn \
    -urn      urn:ad:css:yui2:treeview/assets/folders/tree \
    -resource /resources/ajaxhelper/yui/treeview/assets/folders/tree.css
template::register_urn \
    -urn      urn:ad:css:yui2:treeview/assets/menu/tree \
    -resource /resources/ajaxhelper/yui/treeview/assets/menu/tree.css

if {[file isdirectory $::acs::rootdir/packages/ajaxhelper/www/resources]} {

    foreach path $YUI_CSS_PATHS {
        template::register_urn \
            -urn      urn:ad:css:yui2:$path \
            -resource /resources/ajaxhelper/yui/$path.css
    }

    foreach path $YUI_JS_PATHS {
        template::register_urn \
            -urn      urn:ad:js:yui2:$path \
            -resource /resources/ajaxhelper/yui/$path.js
    }

} else {
    set version 2.7.0
    foreach path $YUI_CSS_PATHS {
        template::register_urn \
            -urn      urn:ad:css:yui2:$path \
            -resource //yui.yahooapis.com/$version/build/$path.css
    }

    foreach path $YUI_JS_PATHS {
        template::register_urn \
            -urn      urn:ad:js:yui2:$path \
            -resource //yui.yahooapis.com/$version/build/$path.js
    }
}

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
