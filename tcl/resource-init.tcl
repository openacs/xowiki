#
# Register some URNs that we are providing for sharing.
#
template::register_urn -urn urn:ad:js:jquery      -resource /resources/xowiki/jquery/jquery-3.5.1.min.js
template::register_urn -urn urn:ad:js:jquery-ui   -resource /resources/xowiki/jquery/jquery-ui.min.js
template::register_urn -urn urn:ad:css:jquery-ui  -resource /resources/xowiki/jquery/jquery-ui.css

template::register_urn -urn urn:ad:js:bootstrap3  \
    -resource //maxcdn.bootstrapcdn.com/bootstrap/3.4.1/js/bootstrap.min.js \
    -csp_list {script-src maxcdn.bootstrapcdn.com}

template::register_urn -urn urn:ad:js:get-http-object \
    -resource /resources/xowiki/get-http-object.js
template::register_urn -urn urn:ad:js:bootstrap3-treeview \
    -resource //cdnjs.cloudflare.com/ajax/libs/bootstrap-treeview/1.2.0/bootstrap-treeview.min.js \
    -csp_list {script-src cdnjs.cloudflare.com}

template::register_urn -urn urn:ad:js:highcharts \
    -resource //code.highcharts.com/7.0/highcharts.js \
    -csp_list {script-src code.highcharts.com}
#template::register_urn -urn urn:ad:js:highcharts-theme   -resource /resources/xowiki/highcharts/js/themes/gray.js

#
# Produce the xowiki.css variants that can be included based on preferred CSS tookit:
#
#    xowiki.css + xowiki-yui-specific.css        -> xowiki-yui.css
#    xowiki.css + xowiki-bootstrap3-specific.css -> xowiki-bootstrap3.css
#
set resDir $::acs::rootdir/packages/xowiki/www/resources
foreach variant {yui bootstrap3} {
  if {![file exists $resDir/xowiki-$variant.css]
      || [file mtime $resDir/xowiki-$variant.css] < [file mtime $resDir/xowiki.css]
      || [file mtime $resDir/xowiki-$variant.css] < [file mtime $resDir/xowiki-$variant-specific.css]
    } {
    set content ""
    set F [open $resDir/xowiki.css]; append content [read $F] \n; close $F
    set F [open $resDir/xowiki-$variant-specific.css]; append content [read $F] \n; close $F
    set F [open $resDir/xowiki-$variant.css w]; puts -nonewline $F $content; close $F
    unset content
  }
}

template::register_urn -urn urn:ad:css:bootstrap3 \
    -resource //maxcdn.bootstrapcdn.com/bootstrap/3.4.1/css/bootstrap.min.css \
    -csp_list {font-src maxcdn.bootstrapcdn.com style-src maxcdn.bootstrapcdn.com}

template::register_urn -urn urn:ad:css:xowiki-yui -resource /resources/xowiki/xowiki-yui.css
template::register_urn -urn urn:ad:css:xowiki-bootstrap -resource /resources/xowiki/xowiki-bootstrap3.css
template::register_urn -urn urn:ad:css:bootstrap3-treeview \
    -resource //cdnjs.cloudflare.com/ajax/libs/bootstrap-treeview/1.2.0/bootstrap-treeview.min.css

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
