ad_library {
    XoWiki - chat procs

    @creation-date 2006-02-02
    @author Gustaf Neumann
    @cvs-id $Id$
}
namespace eval ::xowiki {
  Class Message -parameter {time user_id msg}
  Class Chat -superclass ::xo::OrderedComposite \
      -parameter {chat_id user_id session_id {encoder urlencode} {timewindow 600}} 
  Chat instproc init {} {
    my instvar array
    my set now [clock clicks -milliseconds]
    if {![my exists user_id]}    {my set user_id [ad_conn user_id]}
    if {![my exists session_id]} {my set session_id [ad_conn session_id]}
    set array [self class]-[my set chat_id]
    if {![nsv_exists $array-seen newest]} {nsv_set $array-seen newest 0}
  }
  Chat instproc add_msg {{-get_new:boolean true} -uid msg} {
    my instvar array now
    set user_id [expr {[info exists uid] ? $uid : [my set user_id]}]
    set msg_id $now.$user_id
    nsv_set $array $msg_id [list $now [clock seconds] $user_id $msg]
    nsv_set $array-seen newest $now
    nsv_set $array-last-activity $user_id $now
    if {$get_new} {my get_new}
  }
  Chat instproc check_age {key ago} {
    my instvar array timewindow
    if {$ago > $timewindow} {
      nsv_unset $array $key
      #my log "--c unsetting $key"
      return 0
    }
    return 1
  }
  Chat instproc get_new {} {
    my instvar array now session_id
    set last [expr {[nsv_exists $array-seen $session_id] ? [nsv_get $array-seen $session_id] : 0}]
    if {[nsv_get $array-seen newest]>$last} {
      #my log "--c must check $session_id: [nsv_get $array-seen newest] > $last"
      foreach {key value} [nsv_array get $array] {
	foreach {timestamp secs user msg} $value break
	if {$timestamp > $last} {
	  my add [Message new -time $secs -user_id $user -msg $msg]
	} else {
	  my check_age $key [expr {($now - $timestamp) / 1000}]
	}
      }
      nsv_set $array-seen $session_id $now
      #my log "--c setting session_id $session_id: $now"
    } else {
      #my log "--c nothing new for $session_id"
    }
    my render
  }
  Chat instproc get_all {} {
    my instvar array now session_id
    foreach {key value} [nsv_array get $array] {
      foreach {timestamp secs user msg} $value break
      if {[my check_age $key [expr {($now - $timestamp) / 1000}]]} {
	my add [Message new -time $secs -user_id $user -msg $msg]
      }
    }
    #my log "--c setting session_id $session_id: $now"
    nsv_set $array-seen $session_id $now
    my render
  }
  Chat instproc login {} {
    my instvar array user_id now
    # was the user already active?
    if {![nsv_exists $array-last-activity $user_id]} {
      my add_msg -get_new false login
    }
    foreach {user timestamp} [nsv_array get $array-last-activity] {;# sweeper
      set ago [expr {($now - $timestamp) / 1000}]
      if {$ago > 1200} { 
	my add_msg -get_new false -uid $user "auto logout" 
	nsv_unset $array-last-activity $user 
      }
    }
    my encoder noencode
    #my log "--c setting session_id [my set session_id]: $now"
    my get_all
  }
  Chat instproc urlencode {string} {ns_urlencode $string}
  Chat instproc noencode  {string} {set string}
  Chat instproc encode    {string} {my [my encoder] $string}	
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
    #<span id='chatCounter'  style='font-size: 60%'>0</span>
    #<span id='chatResponse'>&nbsp;</span>  [ad_conn session_id] - [ns_conn url] ?? [util_current_location]

  }

  if {0} {
    Chat c1 -chat_id 222 -session_id 123 -user_id 456
    set _ ""
    c1 add_msg "Hello World now"
    append _ [c1 get_new]
    
    ns_return 200 text/html $_
  }
}