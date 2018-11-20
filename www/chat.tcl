ad_page_contract {
  a tiny chat client

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Jan 31, 2006
  @cvs-id $Id$
} -query {
  m:word
  id:integer
  s
  msg:optional,allhtml
  {mode ""}
}

if {![nsv_get ::xowiki_chat_class $id chat_class]} {
  ns_returnnotfound
  ad_script_abort
}

#ns_log notice "--chat m=$m session_id=$s [clock format [lindex [split $s .] 1] -format %H:%M:%S] mode=$mode" 
$chat_class create c1 -destroy_on_cleanup -chat_id $id -session_id $s -mode $mode
switch -- $m {
  add_msg {
    #ns_log notice "--c call c1 $m '$msg'"
    ns_return 200 application/json [c1 $m $msg]
    ad_script_abort
    #ns_log notice "--c add_msg returns '$_'"
  }
  get_new {
    ns_return 200 application/json [c1 $m]
    ad_script_abort
  }
  login -
  subscribe -
  get_all {set _ [c1 $m]}
  default {ns_log error "--c unknown method $m called."}
}

#ns_log notice "--chat.tcl $m: returns '$_'"

ns_return 200 text/html [subst {<HTML><body>$_</body></HTML>}]

# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
