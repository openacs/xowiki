ad_library {
    XoWiki - chat procs

    @creation-date 2006-02-02
    @author Gustaf Neumann
    @cvs-id $Id$
}
namespace eval ::xowiki {
  Class Message -parameter {time user_id msg}
  Class Chat -superclass ::xo::OrderedComposite \
      -parameter {chat_id keep_nr_messages {encoder urlencode} {timewindow 600}} 
  Chat instproc context {user_id} {
    if {![my exists now]} {my set now [clock clicks -milliseconds]}
    if {$user_id == -1} {set user_id [ad_conn user_id]}
    my set uid $user_id
    my set array [self class]-[my set chat_id]
  }
  Chat instproc init {} {
    my instvar array uid now
    my context 0
    if {![nsv_exists $array-seen newest]} {
      nsv_set $array-seen newest $now
    }
  }
  Chat instproc add_msg {{-user_id -1} msg} {
    my instvar array uid now
    my context $user_id
    set msg_id $now.$uid
    nsv_set $array $msg_id [list $now [clock seconds] $uid $msg]
    nsv_set $array-seen newest $now
    my get_new -user_id $uid
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
  Chat instproc get_new {{-user_id -1}} {
    my instvar array uid now
    my context $user_id
    set last [expr {[nsv_exists $array-seen $uid] ? [nsv_get $array-seen $uid] : 0}]
    if {[nsv_get $array-seen newest]>$last} {
      my log "--s must check $uid: [nsv_get $array-seen newest] > $last"
      foreach {key value} [nsv_array get $array] {
	foreach {timestamp secs user msg} $value break
	if {$timestamp > $last} {
	  my add [Message new -time $secs -user_id $user -msg $msg]
	} else {
	  my check_age $key [expr {($now - $timestamp) / 1000}]
	}
      }
      nsv_set $array-seen $uid $now
    }
    my render
  }
  Chat instproc get_all {{-user_id -1}} {
    my instvar array uid now
    my context $user_id
    foreach {key value} [nsv_array get $array] {
      foreach {timestamp secs user msg} $value break
      if {[my check_age $key [expr {($now - $timestamp) / 1000}]]} {
	my add [Message new -time $secs -user_id $user -msg $msg]
      }
    }
    nsv_set $array-seen $uid $now
    my render
  }
  Chat instproc login {{-user_id -1}} {
    my instvar array uid now
    my context $user_id
    # was the user already active?
    if {![nsv_exists $array-seen $uid]} {
      my add_msg -user_id $uid login
    }
    my encoder noencode
    my get_all -user_id $uid
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

  if {0} {
    Chat c1 -chat_id 222
    set _ ""
    c1 add_msg "Hello World now"
    append _ [c1 get_new]
    
    ns_return 200 text/html $_
  }
}