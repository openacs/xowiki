#ns_log notice "--including_page= $__including_page, portlet=$portlet"
set content [$__including_page include $portlet]
set header_stuff [::xo::Page header_stuff]
template::set_file [file dir $__adp_stub]/plain-include
