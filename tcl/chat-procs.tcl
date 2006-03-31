ad_library {
    XoWiki - chat procs

    @creation-date 2006-02-02
    @author Gustaf Neumann
    @cvs-id $Id$
}
namespace eval ::xowiki {
  ::xo::ChatClass Chat -superclass ::xo::Chat 

  Chat instproc render {} {
    my orderby time
    set result ""
    foreach child [my children] { 
      set msg       [$child msg]
      set user_id   [$child user_id]
      set timelong  [clock format [$child time]]
      set timeshort [clock format [$child time] -format {[%H:%M:%S]}]
      if {$user_id > 0} {
	acs_user::get -user_id $user_id -array user
	set name [expr {$user(screen_name) ne "" ? $user(screen_name) : $user(name)}]
	set url "/shared/community-member?user%5fid=$user_id"
	set creator "<a target='_parent' href='$url'>$name</a>"
      } else {
	set creator "Nobody"
      }
      append result "<TR><TD class='timestamp'>$timeshort</TD>\
	<TD class='user'>[my encode $creator]</TD>\
	<TD class='message'>[my encode $msg]</TD></TR>\n"
    }
    return $result
  }

  Chat proc initialize_nsvs {} {;}      ;# noop

  Chat proc login {-chat_id -package_id} {
    auth::require_login
    ::xowiki::Page requireJS  "/resources/xowiki/get-http-object.js"
    if {![info exists package_id]} {set package_id [ad_conn package_id] }
    if {![info exists chat_id]}    {set chat_id $package_id }

    set context id=$chat_id&s=[ad_conn session_id].[clock seconds]
    set path packages/xowiki/www/ajax/chat.js
    if { ![file exists [acs_root_dir]/$path] } {
      return -code error "File [acs_root_dir]/$path does not exist"
    }
    set file [open [acs_root_dir]/$path]; set js [read $file]; close $file
    set location  [util_current_location]
    set path      [site_node::get_url_from_object_id -object_id $package_id]
    set login_url $path/ajax/chat?m=login&$context
    set send_url  $path/ajax/chat?m=add_msg&$context&msg=
    set get_update  "chatSendCmd(\"$path/ajax/chat?m=get_new&$context\",chatReceiver)"
    set get_all     "chatSendCmd(\"$path/ajax/chat?m=get_all&$context\",chatReceiver)"
    return "\
      <script type='text/javascript' language='javascript'>
      $js
      setInterval('$get_update',5000)
      </script>
      <form action='#' onsubmit='chatSendMsg(\"$send_url\", chatReceiver); return false;'>
      <iframe name='ichat' id='ichat' frameborder='0' src='$login_url'
          style='width:90%;' height='150'>

      </iframe>
      <input type='text' size='40' name='msg' id='chatMsg'>
      </form> 
    "
  }

  if {0} {
    Chat c1 -chat_id 222 -session_id 123 -user_id 456
    set _ ""
    c1 add_msg "Hello World now"
    append _ [c1 get_new]
    
    ns_return 200 text/html $_
  }
}
