#
::xo::Page requireCSS "/resources/calendar/calendar.css"

set date [dt_sysdate]
proc my_get_url_stub {args} {
  return /dotlrn/calendar
}
set url_stub_callback "my_get_url_stub"

# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
