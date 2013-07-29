ad_page_contract {
  a tiny chat client

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Jan 31, 2006
  @cvs-id $Id$
} -query {
  m
  id
  s
  msg:optional
  {mode ""}
}

#ns_log notice "--chat m=$m session_id=$s [clock format [lindex [split $s .] 1] -format %H:%M:%S] mode=$mode" 
::xowiki::Chat create c1 -destroy_on_cleanup -chat_id $id -session_id $s -mode $mode
switch -- $m {
  add_msg {
    #ns_log notice "--c call c1 $m '$msg'"
    set _ [c1 $m $msg]
    #ns_log notice "--c add_msg returns '$_'"
  }
  login -
  subscribe -
  get_new -
  get_all {set _ [c1 $m]}
  default {ns_log error "--c unknown method $m called."} 
}

#ns_log notice "--chat.tcl $m: returns '$_'"

set style {
  padding:1em 0 1em 1em;
  background-color: #f9f9f9;
  font-size:.95em;
  color:#333;
  overflow:auto;
}

ns_return 200 text/html "
<HTML>
<style type='text/css'>
#messages .timestamp {vertical-align: top; font-size: 80%; color: #717171;}
#messages .user {text-align: right; vertical-align: top; font-size: 80%; font-weight: bold; color: #717171;}
#messages .message {vertical-align: top;}
body {$style}
</style>
<body>
$_
</body>
</HTML>"
