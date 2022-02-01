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
  event/event-min
  menu/menu-min
  selector/selector-min
  treeview/treeview-min
  utilities/utilities
  yahoo-dom-event/yahoo-dom-event
  yahoo/yahoo-min
}

if {0} {
  #
  # Downloading YUI files is cumbersome. Therefore, this small helper
  # that maybe someone else finds helpful if there is some more
  # updates (which is not highly likely).
  #
  # see: https://cdnjs.com/libraries/yui/2.9.0
  #
  set version 2.9.0
  set root /usr/local/oacs-5-10/openacs-4/packages/ajaxhelper/www/resources/yui-2.9.0
  foreach path $YUI_CSS_PATHS {
    set dir $root/[file join {*}[lrange [file split $path] 0 end-1]]
    file mkdir $dir
    exec wget -q -P $dir https://cdnjs.cloudflare.com/ajax/libs/yui/2.9.0/$path.css
  }

  foreach path $YUI_JS_PATHS {
    set dir $root/[file join {*}[lrange [file split $path] 0 end-1]]
    file mkdir $dir
    exec wget -q -P $dir https://cdnjs.cloudflare.com/ajax/libs/yui/2.9.0/$path.js
  }
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

if {[ad_file isdirectory $::acs::rootdir/packages/ajaxhelper/www/resources]} {

  #
  # In case, we have yui-2.9.0 then use it, otherwise stick to the old
  # version.
  #
  if {[ad_file isdirectory $::acs::rootdir/packages/ajaxhelper/www/resources/yui-2.9.0]} {
    set version yui-2.9.0
  } else {
    set version yui
  }

  foreach path $YUI_CSS_PATHS {
    template::register_urn \
        -urn      urn:ad:css:yui2:$path \
        -resource /resources/ajaxhelper/$version/$path.css
  }

  foreach path $YUI_JS_PATHS {
    template::register_urn \
        -urn      urn:ad:js:yui2:$path \
        -resource /resources/ajaxhelper/$version/$path.js
  }

} else {
  set version 2.9.0
  foreach path $YUI_CSS_PATHS {
    template::register_urn \
        -urn      urn:ad:css:yui2:$path \
        -resource //cdnjs.cloudflare.com/ajax/libs/yui/$version/$path.css
  }

  foreach path $YUI_JS_PATHS {
    template::register_urn \
        -urn      urn:ad:js:yui2:$path \
        -resource //cdnjs.cloudflare.com/ajax/libs/yui/$version/$path.js
  }
}

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
