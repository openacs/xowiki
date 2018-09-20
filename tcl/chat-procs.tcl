::xo::library doc {
  XoWiki - chat procs

  @creation-date 2006-02-02
  @author Gustaf Neumann
  @cvs-id $Id$
}
namespace eval ::xowiki {
  ::xo::ChatClass create Chat -superclass ::xo::Chat

  Chat proc login {-chat_id -package_id {-mode ""} {-path ""}} {
    #:log "--chat"
    if {![ns_conn isconnected]} return
    auth::require_login
    if {![info exists package_id]} {set package_id [ad_conn package_id] }
    if {![info exists chat_id]}    {set chat_id $package_id }

    set session_id [ad_conn session_id].[clock seconds]
    set context id=$chat_id&s=$session_id
    set base_url ${path}ajax/chat?${context}

    #:log "chat_id=$chat_id, path=$path"
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
      # To be independent of the guessing mode, instantiate the chat
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
          # onreadystateevent only once. For this reason, for every browser except them, we could
          # use the nice mode without the spinning load indicator.
          #
          set mode streaming
        }
      }
      :log "--chat mode $mode"
    }

    # small JavaScript library to obtain a portable ajax request object
    ::xo::Page requireJS urn:ad:js:get-http-object

    switch -- $mode {
      polling {
        set jspath ${path}ajax/chat.js
        set login_url  ${base_url}&m=login
        set get_update "chatSendCmd(\"${base_url}&m=get_new\",chatReceiver)"
        set get_all    "chatSendCmd(\"${base_url}&m=get_all\",chatReceiver)"
      }
      streaming {
        set jspath ${path}ajax/streaming-chat.js
        set subscribe_url ${base_url}&m=subscribe
      }
      scripted-streaming {
        set jspath ${path}ajax/scripted-streaming-chat.js
        set subscribe_url ${base_url}&m=subscribe&mode=scripted
      }
      default {
        error "mode $mode unknown, valid are: polling, streaming and scripted-streaming"
      }
    }

    ::xo::Page requireJS $jspath
    set users_url [ns_quotehtml ${base_url}&m=get_users]
    set send_url ${base_url}&m=add_msg&msg=

    :log "--CHAT mode=$mode"

    # TODO: styling should happen in some template
    # set style {
    #   margin:1.5em 0 1.5em 0;
    #   padding:1em 0 1em 1em;
    #   background-color: #f9f9f9;
    #   border:1px solid #dedede;
    #   height:150px;
    #   font-size:.95em;
    #   line-height:.7em;
    #   color:#333;
    #   overflow:auto;
    # }

    template::add_body_script -script {
      document.getElementById('chatMsg').focus();
    }

    if {$mode ne "polling"} {
      ::xowiki::Chat create c1 \
          -destroy_on_cleanup \
          -chat_id    $chat_id \
          -session_id $session_id \
          -mode       $mode
    }

    set html ""
    switch -- $mode {
      "polling" {
        set r [subst {
          <iframe name='ichat' id='ichat'
             scrolling='no'
             style='border: 0px; width: 100%; height:100%;'
             src='[ns_quotehtml $login_url]'>
          </iframe>
        }]
        template::add_event_listener \
            -id "messages-form" \
            -event "submit" \
            -script [subst {
              chatSendMsg('$send_url',chatReceiver);
            }]
        append html [subst -nocommands {
          <script nonce='$::__csp_nonce'>
             setInterval(function() {$get_update},5000);
          </script>
        }]
      }

      "streaming" {
        set r [ns_urldecode [c1 get_all]]
        template::add_event_listener \
            -id "messages-form" -event "submit" \
            -script {chatSendMsg();}
        append html [subst {
          <script nonce='$::__csp_nonce'>
             var send_url = '$send_url';
             chatSubscribe('$subscribe_url');
          </script>
        }]
      }

      "scripted-streaming" {
        set r [ns_urldecode [c1 get_all]]
        template::add_event_listener \
            -id "messages-form" -event "submit" \
            -script {chatSendMsg();}
        append html [subst {
          <script nonce='$::__csp_nonce'>
             var send_url = '$send_url';
          </script>
          <iframe name='ichat' id='ichat' src='[ns_quotehtml $subscribe_url]'
             style='width:0px; height:0px; border: 0px'>
          </iframe>
        }]
      }
    }

    append html [subst {
      <div id='messages'>$r</div>
      <form id='messages-form' action='#'>
         <input type='text' size='40' name='msg' id='chatMsg'>
      </form>
    }]

    return $html
  }
}

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
