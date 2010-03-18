::xo::library doc {
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

  Chat proc login {-chat_id -package_id -mode} {
    my log "--"
    auth::require_login
    if {![info exists package_id]} {set package_id [ad_conn package_id] }
    if {![info exists chat_id]}    {set chat_id $package_id }
    set context id=$chat_id&s=[ad_conn session_id].[clock seconds]
    set path    [lindex [site_node::get_url_from_object_id -object_id $package_id] 0]
    
    if {![info exists mode]} {
      set mode polling
      if {[info command ::thread::mutex] ne "" &&
          ![catch {ns_conn contentsentlength}]} {
        # we seem to have libthread installed, and the patch for obtaining the tcl-stream
        # from a connection thread, so we can use the background delivery thread;
        # scripted streaming should work everywhere
        set mode scripted-streaming
        if {[regexp (firefox) [string tolower [ns_set get [ns_conn headers] User-Agent]]]} {
          # for firefox, we could use the nice mode without the spinning load indicator
          # currently, streaming mode seems broken with current firefox...
          #set mode streaming
        }
      }
      my log "--chat mode $mode"
    }

    switch $mode {
      polling {
        ::xo::Page requireJS  "/resources/xowiki/get-http-object.js"
        set jspath packages/xowiki/www/ajax/chat.js
        set login_url ${path}ajax/chat?m=login&$context
        set get_update  "chatSendCmd(\"$path/ajax/chat?m=get_new&$context\",chatReceiver)"
        set get_all     "chatSendCmd(\"$path/ajax/chat?m=get_all&$context\",chatReceiver)"
      }
      streaming {
        set jspath packages/xowiki/www/ajax/streaming-chat.js
        set subscribe_url ${path}ajax/chat?m=subscribe&$context
      }
      scripted-streaming {
        append context &mode=scripted
        set jspath packages/xowiki/www/ajax/scripted-streaming-chat.js
        set subscribe_url ${path}ajax/chat?m=subscribe&$context
      }
    }
    set send_url  ${path}ajax/chat?m=add_msg&$context&msg=

    if { ![file exists [acs_root_dir]/$jspath] } {
      return -code error "File [acs_root_dir]/$jspath does not exist"
    }
    set file [open [acs_root_dir]/$jspath]; set js [read $file]; close $file

    my log "--CHAT mode=$mode"

    switch $mode {
      polling {return "\
      <script type='text/javascript' language='javascript'>
      $js
      setInterval('$get_update',5000)
      </script>
      <form action='#' onsubmit='chatSendMsg(\"$send_url\",chatReceiver); return false;'>
      <iframe name='ichat' id='ichat' frameborder='0' src='$login_url'
          style='width:90%;' height='150'>
      </iframe>
      <input type='text' size='40' name='msg' id='chatMsg'>
      </form>"
      }


      streaming {return "\
      <script type='text/javascript' language='javascript'>$js
      var send_url = \"$send_url\";
      chatSubscribe(\"$subscribe_url\");
      </script>
   <div id='messages' style='margin:1.5em 0 1.5em 0;
padding:1em 0 1em 1em;
background-color: #f9f9f9;
border:1px solid #dedede;
height: 70px;
height:150px;
font-size:.95em;
line-height:.7em;
color:#333;
overflow:auto;
'></div>
   <form action='#' onsubmit='chatSendMsg(); return false;'>
   <input type='text' size='40' name='msg' id='chatMsg'>"
      }


      scripted-streaming {return "\
      <script type='text/javascript' language='javascript'>
      $js
      var send_url = \"$send_url\";
      </script>
   <div id='messages' style='margin:1.5em 0 1.5em 0;
padding:1em 0 1em 1em;
background-color: #f9f9f9;
border:1px solid #dedede;
height: 70px;
height:150px;
font-size:.95em;
line-height:.7em;
color:#333;
overflow:auto;
'></div>
      <iframe name='ichat' id='ichat' frameborder='0' src='$subscribe_url' 
              style='width:0px; height:0px; border: 0px'>
      </iframe>
      <form action='#' onsubmit='chatSendMsg(); return false;'>
      <input type='text' size='40' name='msg' id='chatMsg'>
      </form>"
      }
    }
  }
}

