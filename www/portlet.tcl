#      
if {![string match "/*" $portlet]} {
  set portlet /packages/xowiki/www/portlets/$portlet
}
