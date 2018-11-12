::xo::library doc {
  XoWiki - chat procs

  @creation-date 2006-02-02
  @author Gustaf Neumann
  @cvs-id $Id$
}

namespace eval ::xowiki {
  ::xo::ChatClass create Chat -superclass ::xo::Chat

  ::xo::ChatClass instproc login {-chat_id {-package_id ""} {-mode ""} {-path ""}} {
    #:log "--chat"
    if {![ns_conn isconnected]} return
    auth::require_login

    if {[ad_conn package_key] eq "xowiki"} {
      set xowiki_package_id [ad_conn package_id]
    } else {
      set xowiki_package_id [::xowiki::Package first_instance -privilege read \
                                 -party_id [ad_conn user_id]]
    }

    if {$package_id eq ""} {
      set package_id $xowiki_package_id
    }

    #:log "chat_id=$chat_id, path=$path"
    if {$path eq ""} {
      set path [lindex [site_node::get_url_from_object_id \
                            -object_id $package_id] 0]
    } elseif {[string index $path end] ne "/"} {
      append path /
    }

    set xowiki_path [lindex [site_node::get_url_from_object_id \
                                 -object_id $xowiki_package_id] 0]

    if {![info exists chat_id]} {set chat_id $package_id}

    set session_id [ad_conn session_id].[clock seconds]
    set context id=$chat_id&s=$session_id
    set base_url ${path}ajax/chat?${context}

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

    switch -- $mode {
      polling {
        set jspath ${xowiki_path}ajax/chat.js
        set subscribe_url ${base_url}&m=get_new
      }
      streaming {
        set jspath ${xowiki_path}ajax/streaming-chat.js
        set subscribe_url ${base_url}&m=subscribe
      }
      scripted-streaming {
        set jspath ${xowiki_path}ajax/scripted-streaming-chat.js
        set subscribe_url ${base_url}&m=subscribe&mode=scripted
      }
      default {
        error "mode $mode unknown, valid are: polling, streaming and scripted-streaming"
      }
    }

    # get LinkRegex parameter from the chat package
    set link_regex [parameter::get_global_value \
                        -package_key "chat" \
                        -parameter "LinkRegex"]

    # Should we add a full screen link to the chat?
    set fs_link_p true

    # small JavaScript library to obtain a portable ajax request object
    template::head::add_javascript -src urn:ad:js:get-http-object -order 10
    template::head::add_javascript -script "const linkRegex = \"${link_regex}\";" -order 19
    template::head::add_javascript -src ${xowiki_path}ajax/chat-common.js -order 20
    template::head::add_javascript -src $jspath -order 30

    set send_url ${base_url}&m=add_msg&msg=

    :log "--CHAT mode=$mode"

    template::add_body_script -script {
      document.getElementById('xowiki-chat-send').focus();
    }

    set html ""

    if {[apm_package_installed_p chat]} {
      set message_label [_ chat.message]
      set send_label [_ chat.Send_Refresh]
    } else {
      set message_label "Message"
      set send_label "Send"
    }

    # TODO: it is currently not possible to embed multiple chats in
    # the same page.
    append html [subst {
      <div id='xowiki-chat'>
         <div id='xowiki-chat-messages-and-form'>
           <div id='xowiki-chat-messages'></div>
           <div id='xowiki-chat-messages-form-block'>
             <form id='xowiki-chat-messages-form' action='#'>
               <input type='text' placeholder="$message_label" name='msg' id='xowiki-chat-send' autocomplete="off">
               <input type="hidden" value="$send_label">
             </form>
           </div>
         </div>
         <div id='xowiki-chat-users'></div>
      </div>
    }]

    [self] create c1 \
          -destroy_on_cleanup \
          -chat_id    $chat_id \
          -session_id $session_id \
          -mode       $mode

    set data [c1 login]
    if {$data ne ""} {
      append html [subst {
        <script nonce='$::__csp_nonce'>
          var data = $data;
          for(var i = 0; i < data.length; i++) {
            renderData(data\[i\]);
          }
        </script>
      }]
    }

    if {$fs_link_p} {
      append html [subst {
        <script nonce='$::__csp_nonce'>
          addFullScreenLink();
        </script>
      }]
    }

    switch -- $mode {
      "polling" {
        append html [subst -nocommands {
          <script nonce='$::__csp_nonce'>
             chatSubscribe('$subscribe_url');
          </script>
        }]
        set send_msg_handler pollingSendMsgHandler
      }

      "streaming" {
        append html [subst {
          <script nonce='$::__csp_nonce'>
             chatSubscribe('$subscribe_url');
          </script>
        }]
        set send_msg_handler streamingSendMsgHandler
      }

      "scripted-streaming" {
        append html [subst {
          <iframe name='ichat' id='ichat' src='[ns_quotehtml $subscribe_url]'
             style='width:0px; height:0px; border: 0px'>
          </iframe>
        }]
        set send_msg_handler scriptedStreamingSendMsgHandler
      }
    }

    template::add_refresh_on_history_handler

    template::add_event_listener \
        -id "xowiki-chat-messages-form" -event "submit" \
        -script [subst {chatSendMsg('${send_url}', ${send_msg_handler});}]

    return $html
  }
}

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
