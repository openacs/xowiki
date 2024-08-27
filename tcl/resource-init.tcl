#
# Register some URNs that we are providing for sharing.
#

template::register_urn -urn urn:ad:js:bootstrap3  \
    -resource //maxcdn.bootstrapcdn.com/bootstrap/3.4.1/js/bootstrap.min.js \
    -csp_list {script-src maxcdn.bootstrapcdn.com}

template::register_urn -urn urn:ad:js:get-http-object \
    -resource /resources/xowiki/get-http-object.js

if {![apm_package_enabled_p "highcharts"]} {
  template::register_urn -urn urn:ad:js:highcharts \
      -resource https://cdnjs.cloudflare.com/ajax/libs/highcharts/11.4.3/highcharts.js \
      -csp_list {script-src cdnjs.cloudflare.com}
}
#template::register_urn -urn urn:ad:js:highcharts-theme   -resource /resources/xowiki/highcharts/js/themes/gray.js

#
# Produce the xowiki.css variants that can be included based on preferred CSS toolkit:
#
#    xowiki.css + xowiki-yui-specific.css        -> xowiki-yui.css
#    xowiki.css + xowiki-bootstrap3-specific.css -> xowiki-bootstrap3.css
#
set resDir $::acs::rootdir/packages/xowiki/www/resources
foreach variant {yui bootstrap3 bootstrap5} {
  if {![ad_file exists $resDir/xowiki-$variant.css]
      || [ad_file mtime $resDir/xowiki-$variant.css] < [ad_file mtime $resDir/xowiki.css]
      || [ad_file mtime $resDir/xowiki-$variant.css] < [ad_file mtime $resDir/xowiki-$variant-specific.css]
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
template::register_urn -urn urn:ad:css:xowiki-bootstrap5 -resource /resources/xowiki/xowiki-bootstrap5.css

::util::resources::register_urns -prefix xowiki


#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
