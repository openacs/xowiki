::xo::library doc {
  XoWiki - chat procs

  @creation-date 2006-02-02
  @author Gustaf Neumann
  @cvs-id $Id$
}
namespace eval ::xowiki {
  ::xo::ChatClass create Chat -superclass ::xo::Chat

  # Chat instproc render {} {
  #   :orderby time
  #   set result ""
  #   foreach child [:children] { 
  #     set msg       [$child msg]
  #     set user_id   [$child user_id]
  #     set timelong  [clock format [$child time]]
  #     set timeshort [clock format [$child time] -format {[%H:%M:%S]}]
  #     if {$user_id > 0} {
  #       acs_user::get -user_id $user_id -array user
  #       set name [expr {$user(screen_name) ne "" ? $user(screen_name) : $user(name)}]
  #       set url "/shared/community-member?user%5fid=$user_id"
  #       set creator "<a target='_parent' href='$url'>$name</a>"
  #     } else {
  #       set creator "Nobody"
  #     }
  #     append result "<TR><TD class='timestamp'>$timeshort</TD>\
      #       <TD class='user'>[:encode $creator]</TD>\
      #       <TD class='message'>[:encode $msg]</TD></TR>\n"
  #   }
  #   return $result
  # }

  Chat proc initialize_nsvs {} {;}      ;# noop

  Chat proc login {-chat_id -package_id {-mode ""} {-path ""}} {
    #my log "--chat"
    if {![ns_conn isconnected]} return
    auth::require_login
    if {![info exists package_id]} {set package_id [ad_conn package_id] }
    if {![info exists chat_id]}    {set chat_id $package_id }
    set session_id [ad_conn session_id].[clock seconds]
    set context id=$chat_id&s=$session_id
    #my log "chat_id=$chat_id, path=$path"
    if {$path eq ""} {
      set path [lindex [site_node::get_url_from_object_id -object_id $package_id] 0]
    } elseif {[string index $path end] ne "/"} {
      append path /
    }
    
    if {$mode eq ""} {
      #
      # The parameter "mode" was not specified, we try to guess the
      # "best" mode known to work for the currently used browser.
      #
      # The most conservative mode is
      # - "polling" (which requires for every connected client polling
      #    requests), followed by
      # - "scripted-streaming" (which opens and "infinitely long" HTML 
      #   files with embedded script tags; very portable, but this 
      #   causes the loading indicator to spin), followed by
      # - "streaming" (true streaming, but this requires 
      #   an HTTP stack supporting partial reads).
      #
      # NOTICE 1: The guessing is based on current versions of the
      # browsers. Older versions of the browser might behave
      # differently.
      #
      # NOTICE 2: "streaming" (and to a lesser extend
      # "scripted-streaming" - which used chunked encoding) might be
      # influenced by the buffering behavior of a reverse proxy, which
      # might have to be configured appropriately.
      #
      # To be independet of the guessing mode, instantiate the chat
      # object with "mode" specified.
      #
      set mode polling
      #
      # Check, whether we have the tcllibthread and a sufficiently new
      # aolserver/NaviServer supporting bgdelivery transfers.
      #
      if {[info commands ::thread::mutex] ne "" &&
          ![catch {ns_conn contentsentlength}]} {
        #
        # scripted streaming should work everywhere
        #
        set mode scripted-streaming
        if {![regexp msie|opera [string tolower [ns_set get [ns_conn headers] User-Agent]]]} {
          # Explorer doesn't expose partial response until request state != 4, while Opera fires
          # onreadystateevent only once. For this reason, for every broser except them, we could 
          # use the nice mode without the spinning load indicator.
          #
          set mode streaming
        }
      }
      :log "--chat mode $mode"
    }

    # small javascript library to obtain a portable ajax request object
    ::xo::Page requireJS "/resources/xowiki/get-http-object.js"

    switch -- $mode {
      polling {
        set jspath packages/xowiki/www/ajax/chat.js
        set login_url  ${path}ajax/chat?m=login&$context
        set get_update "chatSendCmd(\"$path/ajax/chat?m=get_new&$context\",chatReceiver)"
        set get_all    "chatSendCmd(\"$path/ajax/chat?m=get_all&$context\",chatReceiver)"
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
      default {
        error "mode $mode unknown, valid are: polling, streaming and scripted-streaming"
      }
    }
    set send_url ${path}ajax/chat?m=add_msg&$context&msg=

    if { ![file exists [acs_root_dir]/$jspath] } {
      return -code error "File [acs_root_dir]/$jspath does not exist"
    }
    set file [open [acs_root_dir]/$jspath]; set js [read $file]; close $file

    :log "--CHAT mode=$mode"

    set style {
      margin:1.5em 0 1.5em 0;
      padding:1em 0 1em 1em;
      background-color: #f9f9f9;
      border:1px solid #dedede;
      height:150px;
      font-size:.95em;
      line-height:.7em;
      color:#333;
      overflow:auto;
    }

    template::add_body_script -script [subst {document.getElementById('chatMsg').focus();}]

    switch -- $mode {
      polling {
        template::add_event_listener \
            -id "messages-form" \
            -event "submit" \
            -script [subst {
          chatSendMsg(\"$send_url\",chatReceiver);
        }]
        return "\
      <script type='text/javascript' language='javascript' nonce='$::__csp_nonce'>
      $js
      setInterval('$get_update',5000)
      </script>
      <form id='messages-form' action='#'>
      <iframe name='ichat' id='ichat' frameborder='0' src='[ns_quotehtml $login_url]'
          style='width:90%;' height='150'>
      </iframe>
      <input type='text' size='40' name='msg' id='chatMsg'>
      </form>"
      }


      streaming {
        ::xowiki::Chat create c1 -destroy_on_cleanup -chat_id $chat_id -session_id $session_id -mode $mode
        set r [ns_urldecode [c1 get_all]]
        regsub -all {<[/]?div[^>]*>} $r "" r
        template::add_event_listener \
            -id "messages-form" -event "submit" \
            -script {chatSendMsg();}
        return "\
      <script type='text/javascript' language='javascript' nonce='$::__csp_nonce'>$js
      var send_url = \"$send_url\";
      chatSubscribe(\"$subscribe_url\");
      </script>
   <div id='messages' style='$style'>$r</div>
   <form id='messages-form' action='#'>
   <input type='text' size='40' name='msg' id='chatMsg'>
   </form>"
      }


      scripted-streaming {
        ::xowiki::Chat create c1 -destroy_on_cleanup -chat_id $chat_id -session_id $session_id -mode $mode
        set r [ns_urldecode [c1 get_all]]
        regsub -all {<[/]?div[^>]*>} $r "" r
        template::add_event_listener \
            -id "messages-form" -event "submit" \
            -script {chatSendMsg();}
        return "\
      <script type='text/javascript' language='javascript' nonce='$::__csp_nonce'>
      $js
      var send_url = \"$send_url\";
      </script>
      <div id='messages' style='$style'>
      <iframe name='ichat' id='ichat' frameborder='0' src='[ns_quotehtml $subscribe_url]' 
              style='width:0px; height:0px; border: 0px'>
      </iframe>
      </div>
      <form id='messages-form' action='#'>
      <input type='text' size='40' name='msg' id='chatMsg'>
      </form>"
      }
    }
  }
}

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
