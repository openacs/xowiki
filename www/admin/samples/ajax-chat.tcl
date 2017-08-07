namespace eval ::xowiki::tmp {
  ::xowiki::Object create ajax-chat -noinit \
      -set object_type ::xowiki::Object \
      -set lang en \
      -set description {} \
      -set text {
        proc content {} {
          ::xowiki::Chat login -chat_id 22
        }
      } \
      -set nls_language en_US \
      -set mime_type {text/html} \
      -set name en:ajax-chat \
      -set title en:ajax-chat
}

set title "Import XoWiki Pages"
set context {}
set msg [::xowiki::Page import -objects ::xowiki::tmp::ajax-chat -replace true]
template::set_file "[file dirname $__adp_stub]/../importmsg"
ad_return_template

# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
