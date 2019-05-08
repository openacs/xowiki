xo::library doc {
  Generic chat procs

  @creation-date 2006-02-02
  @author Gustaf Neumann
  @cvs-id $Id$
}

namespace eval ::xo {
  Class create Message -parameter {time user_id msg color {type "message"}}
  Class create Chat -superclass ::xo::OrderedComposite \
      -parameter {
        chat_id
        user_id
        session_id
        {mode default}
        {encoder noencode}
        {timewindow 600}
        {sweepinterval 60}
        {login_messages_p t}
        {logout_messages_p t}
        {avatar_p t}
        {conf {}}
        {message_relay {connchan bgdelivery none}}
      }

  Chat instproc init {} {
    # :log "-- "

    #
    # Work through the list of provided message_relays and select a
    # usable one.
    #
    set :mr ::xo::mr::none
    foreach mr ${:message_relay} {
      if {[::xo::mr::$mr can_be_used]} {
        set :mr ::xo::mr::$mr
        break
      }
    }

    set :now [clock clicks -milliseconds]
    if {![info exists :user_id]} {
      set :user_id [ad_conn user_id]
    }
    if {![info exists :session_id]} {
      set :session_id [ad_conn session_id]
    }
    set cls [:info class]
    set :array $cls-${:chat_id}
    if {![nsv_exists $cls initialized]} {
      :log "-- initialize $cls"
      $cls initialize_nsvs
      ::xo::clusterwide nsv_set $cls initialized \
          [ad_schedule_proc \
               -thread "t" [:sweepinterval] $cls sweep_all_chats]
    }
    if {![nsv_exists ${:array}-seen newest]} {
      ::xo::clusterwide nsv_set ${:array}-seen newest 0
    }
    if {![nsv_exists ${:array}-color idx]} {
      ::xo::clusterwide nsv_set ${:array}-color idx 0
    }
    if {[:user_id] != 0 || [:session_id] != 0} {
      :init_user_color
    }
    :set_options
  }

  Chat instproc set_options {} {
    dict for {key value} ${:conf} {
      ::xo::clusterwide nsv_set ${:array}-options $key $value
    }
    if {[nsv_array exists ${:array}-options]} {
      foreach {key value} [nsv_array get ${:array}-options] {
        :set $key $value
      }
    }
  }

  Chat instproc register_nsvs {msg_id user_id msg color secs} {
    # Tell the system we are back again, in case we were auto logged out
    if { ![nsv_exists ${:array}-login $user_id] } {
      ::xo::clusterwide nsv_set ${:array}-login $user_id [clock seconds]
    }
    ::xo::clusterwide nsv_set ${:array} $msg_id [list ${:now} $secs $user_id $msg $color]
    ::xo::clusterwide nsv_set ${:array}-seen newest ${:now}
    ::xo::clusterwide nsv_set ${:array}-seen last $secs
    ::xo::clusterwide nsv_set ${:array}-last-activity $user_id ${:now}
  }

  Chat instproc add_msg {{-get_new:boolean true} {-uid ""} msg} {
    # :log "--chat adding $msg"
    set user_id [expr {$uid ne "" ? $uid : ${:user_id}}]
    set color   [:user_color $user_id]
    set msg     [ns_quotehtml $msg]

    # :log "-- msg=$msg"
    :broadcast_msg [Message new -volatile -time [clock seconds] \
                        -user_id $user_id -color $color [list -msg $msg]]

    :register_nsvs ${:now}.$user_id $user_id $msg $color [clock seconds]
    #
    # This in any case a valid result, but only needed for the polling
    # interface
    #
    if {$get_new} {
      :get_new
    }
  }

  Chat instproc current_message_valid {} {
    expr { [info exists :user_id] && ${:user_id} != -1 }
  }

  Chat instproc active_user_list {} {
    nsv_array get ${:array}-login
  }

  Chat instproc nr_active_users {} {
    expr { [llength [nsv_array get ${:array}-login]] / 2 }
  }

  Chat instproc last_activity {} {
    if { ![nsv_exists ${:array}-seen last] } { return "-" }
    return [clock format [nsv_get ${:array}-seen last] -format "%d.%m.%y %H:%M:%S"]
  }

  Chat instproc check_age {key ago} {
    if {$ago > ${:timewindow}} {
      ::xo::clusterwide nsv_unset ${:array} $key
      #:log "--c unsetting $key"
      return 0
    }
    return 1
  }

  Chat instproc get_new {} {
    set last [expr {[nsv_exists ${:array}-seen ${:session_id}] ? [nsv_get ${:array}-seen ${:session_id}] : 0}]
    if {[nsv_get ${:array}-seen newest]>$last} {
      #:log "--c must check ${:session_id}: [nsv_get ${:array}-seen newest] > $last"
      foreach {key value} [nsv_array get ${:array}] {
        lassign $value timestamp secs user msg color
        if {$timestamp > $last} {
          #
          # add the message to the ordered composite.
          #
          :add [Message new -time $secs -user_id $user -msg $msg -color $color]
        } else {
          :check_age $key [expr {(${:now} - $timestamp) / 1000}]
        }
      }
      ::xo::clusterwide nsv_set ${:array}-seen ${:session_id} ${:now}
      # :log "--chat setting session_id ${:session_id}: ${:now}"
    } else {
      # :log "--chat nothing new for ${:session_id}"
    }
    :render
  }

  Chat instproc get_all {} {
    foreach {key value} [nsv_array get ${:array}] {
      lassign $value timestamp secs user msg color
      if {[:check_age $key [expr {(${:now} - $timestamp) / 1000}]]} {
        :add [Message new -time $secs -user_id $user -msg $msg -color $color]
      }
    }
    #:log "--chat setting session_id ${:session_id}: ${:now}"
    ::xo::clusterwide nsv_set ${:array}-seen ${:session_id} ${:now}
    :render
  }

  Chat instproc sweeper {} {
    #:log "--core-chat starting"
    foreach {user timestamp} [nsv_array get ${:array}-last-activity] {
      set ago [expr {(${:now} - $timestamp) / 1000}]
      #ns_log notice "--core-chat Checking: now=${:now}, timestamp=$timestamp, ago=$ago"
      if {$ago > 300} {
        :logout -user_id $user -msg "auto logout"
        # ns_log warning "-user_id $user auto logout"
        ${:mr} sweep chat-${:chat_id}
      }
    }
    :broadcast_msg [Message new -volatile -type "users" -time [clock seconds]]
    #:log "-- ending"
  }

  Chat instproc logout {{-user_id ""} {-msg ""}} {
    set user_id [expr {$user_id ne "" ? $user_id : ${:user_id}}]
    ns_log notice "--core-chat User $user_id logging out of chat"
    if {${:logout_messages_p}} {
      if {$msg eq ""} {set msg [_ chat.has_left_the_room].}
      :add_msg -uid $user_id -get_new false $msg
    }

    # These values could already not be here. Just ignore when we don't
    # find them
    try {
      ::xo::clusterwide nsv_unset -nocomplain ${:array}-login $user_id
    }
    try {
      ::xo::clusterwide nsv_unset -nocomplain ${:array}-color $user_id
    }
    try {
      ::xo::clusterwide nsv_unset -nocomplain ${:array}-last-activity $user_id
    }
  }

  Chat instproc init_user_color {} {
    if { [nsv_exists ${:array}-color ${:user_id}] } {
      return
    } else {
      set colors [::xo::parameter get -parameter UserColors -default [[:info class] set colors]]
      # ns_log notice "getting colors of [:info class] = [info exists colors]"
      set color [lindex $colors [expr { [nsv_get ${:array}-color idx] % [llength $colors] }]]
      ::xo::clusterwide nsv_set ${:array}-color ${:user_id} $color
      ::xo::clusterwide nsv_incr ${:array}-color idx
    }
  }

  Chat instproc get_users {} {
    return [:json_encode_msg [Message new -volatile -type "users" -time [clock seconds]]]
  }

  Chat instproc user_active {user_id} {
    # was the user already active?
    #:log "--chat login already avtive? [nsv_exists ${:array}-last-activity $user_id]"
    return [nsv_exists ${:array}-last-activity $user_id]
  }

  Chat instproc login {} {
    :log "--chat login mode=${:mode}"
    if {${:login_messages_p} && ![:user_active ${:user_id}]} {
      :add_msg -uid ${:user_id} -get_new false [_ xotcl-core.has_entered_the_room]
    } elseif {${:user_id} > 0 && ![nsv_exists ${:array}-login ${:user_id}]} {
      # give some proof of our presence to the chat system when we
      # don't issue the login message
      ::xo::clusterwide nsv_set ${:array}-login ${:user_id} [clock seconds]
      ::xo::clusterwide nsv_set ${:array}-last-activity ${:user_id} ${:now}
    }
    :encoder noencode
    #:log "--chat setting session_id ${:session_id}: ${:now} mode=${:mode}"
    return [:get_all]
  }

  Chat instproc user_color { user_id } {
    if { ![nsv_exists ${:array}-color $user_id] } {
      :log "warning: Cannot find user color for chat (${:array}-color $user_id)!"
      return [lindex [[:info class] set colors] 0]
    }
    return [nsv_get ${:array}-color $user_id]
  }

  Chat instproc user_name { user_id } {
    if {$user_id > 0} {
      set screen_name [acs_user::get_user_info -user_id $user_id -element screen_name]
      if {$screen_name eq ""} {
        set screen_name [person::name -person_id $user_id]
      }
    } elseif { $user_id == 0 } {
      set screen_name "Nobody"
    } else {
      set screen_name "System"
    }
    return $screen_name
  }

  Chat instproc urlencode   {string} {ns_urlencode $string}
  Chat instproc noencode    {string} {set string}
  Chat instproc encode      {string} {my [:encoder] $string}
  Chat instproc json_encode {string} {
    string map [list \n \\n \" \\\" ' {\\'} \\ \\\\] $string
  }

  Chat instproc json_encode_msg {msg} {
    set type [$msg type]
    switch $type {
      "message" {
        set message   [$msg msg]
        set user_id   [$msg user_id]
        set user      [:user_name $user_id]
        set color     [$msg color]
        set timestamp [clock format [$msg time] -format {[%H:%M:%S]}]
        foreach var {message user timestamp color user_id} {
          set $var [:json_encode [set $var]]
        }
        return [subst {{"type": "$type", "message": "$message", "timestamp": "$timestamp", "user": "$user", "color": "$color", "user_id": "$user_id"}\n}]
      }
      "users" {
        set message [list]
        foreach {user_id timestamp} [:active_user_list] {
          if {$user_id < 0} continue
          set timestamp [clock format [expr {[clock seconds] - $timestamp}] -format "%H:%M:%S" -gmt 1]
          set user      [:user_name $user_id]
          set color     [:user_color $user_id]
          foreach var {user timestamp color user_id} {
            set $var [:json_encode [set $var]]
          }
          lappend message [subst {{"timestamp": "$timestamp", "user": "$user", "color": "$color", "user_id": "$user_id"}}]
        }
        set message "\[[join $message ,]\]"
        return [subst {{"type": "$type", "chat_id": "${:chat_id}", "message": $message}\n}]
      }
    }
  }

  Chat instproc js_encode_msg {msg} {
    set json [string trim [:json_encode_msg $msg]]
    if {$json ne ""} {
      return [subst {
        <script type='text/javascript' language='javascript' nonce='$::__csp_nonce'>
           var data = $json;
           parent.getData(data);
        </script>\n
      }]
    } else {
      return
    }
  }

  Chat instproc broadcast_msg {msg} {
    #:log "--chat broadcast_msg"
    ${:mr} send_to_subscriber chat-${:chat_id} [:json_encode_msg $msg]
  }

  Chat instproc subscribe {-uid} {
    set user_id [expr {[info exists uid] ? $uid : ${:user_id}}]
    set color [:user_color $user_id]
    #ns_log notice "--CHAT [self] subscribe chat-${:chat_id} -mode ${:mode} via <${:mr}>"
    ${:mr} subscribe chat-${:chat_id} -mode ${:mode}
  }

  Chat instproc render {} {
    :orderby time
    set result [list]
    # Piggyback the users list in every rendering, this way we don't
    # need a separate ajax request for the polling interface.
    :add [Message new -type "users" -time [clock seconds]]
    foreach child [:children] {
      lappend result [:json_encode_msg $child]
    }
    return "\[[join $result ,]\]"
  }

  ############################################################################
  # Chat meta class, since we need to define general class-specific methods
  ############################################################################
  Class create ChatClass -superclass ::xotcl::Class
  ChatClass method sweep_all_chats {} {
    #:log "-- starting"
    foreach nsv [nsv_names "[self]-*-seen"] {
      if { [regexp "[self]-(\[0-9\]+)-seen" $nsv _ chat_id] } {
        #:log "--Chat_id $chat_id"
        :new -volatile -chat_id $chat_id -user_id 0 -session_id 0 -init -sweeper
      }
    }
    #:log "-- ending"
  }

  ChatClass method initialize_nsvs {} {
    # empty stub for subclasses to extend
  }

  ChatClass method flush_messages {-chat_id:required} {
    set array "[self]-$chat_id"
    ::xo::clusterwide nsv_unset -nocomplain $array
    ::xo::clusterwide nsv_unset -nocomplain $array-seen
    ::xo::clusterwide nsv_unset -nocomplain $array-last-activity
  }

  ChatClass method init {} {
    # default setting is set19 from http://www.graphviz.org/doc/info/colors.html
    # per parameter settings in the chat package are available (param UserColors)
    set :colors [list #1b9e77 #d95f02 #7570b3 #e7298a #66a61e #e6ab02 #a6761d #666666]
  }
}


namespace eval ::xowiki {

  ::xo::ChatClass create Chat -superclass ::xo::Chat

  ::xo::ChatClass proc is_chat_p {class} {
    return [expr {[:isobject $class] && [$class class] eq [self]}]
  }

  ::xo::ChatClass instproc get_mode {} {
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
    # AOLserver/NaviServer supporting bgdelivery transfers.
    #
    if {[info commands ::thread::mutex] ne "" &&
        ![catch {ns_conn contentsentlength}]} {
      #
      # scripted streaming should work everywhere
      #
      set mode scripted-streaming
      if {![regexp msie|opera [string tolower [ns_set get [ns_conn headers] User-Agent]]]} {
        #
        # Explorer doesn't expose partial response until request state
        # != 4, while Opera fires onreadystateevent only once. For
        # this reason, for every browser except them, we could use the
        # nice mode without the spinning load indicator.
        #
        set mode streaming
      }
    }

    return $mode
  }

  ::xo::ChatClass ad_instproc login {
    -chat_id:required
    {-skin "classic"}
    {-package_id ""}
    {-mode ""}
    {-path ""}
    {-avatar_p true}
    -login_messages_p
    -logout_messages_p
    -timewindow
  } {
    Logs into a chat
  } {
    #:log "--chat"
    if {![ns_conn isconnected]} return
    auth::require_login

    set session_id [ad_conn session_id].[clock seconds]
    set base_url [export_vars -base /shared/ajax/chat -no_empty {
      {id $chat_id} {s $session_id} {class "[self]"}
    }]

    # This might come in handy to get resources from the chat package
    # if we want to have e.g. a separate css.
    # set package_key [apm_package_key_from_id $package_id]
    # set resources_path /resources/${package_key}
    template::head::add_css -href /resources/xowiki/chat-skins/chat-$skin.css

    if {$mode eq ""} {
      #
      # The parameter "mode" was not specified, we try to guess the
      # "best" mode known to work for the currently used browser.
      #
      set mode [:get_mode]
      :log "--chat mode $mode"
    }

    switch -- $mode {
      polling {
        set jspath /resources/xowiki/chat.js
        set subscribe_url ${base_url}&m=get_new&mode=polling
      }
      streaming {
        set jspath /resources/xowiki/streaming-chat.js
        set subscribe_url ${base_url}&m=subscribe&mode=streaming
      }
      scripted-streaming {
        set jspath /resources/xowiki/scripted-streaming-chat.js
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

    # Should we display avatars? (JavaScript can only take 'true' or 'false' as boolean values)
    if {$avatar_p} {
        set show_avatar true
    } else {
        set show_avatar false
    }

    # small JavaScript library to obtain a portable ajax request object
    template::head::add_javascript -src urn:ad:js:get-http-object -order 10
    template::head::add_javascript -script "const linkRegex = \"${link_regex}\";" -order 19
    template::head::add_javascript -script "const show_avatar = $show_avatar;" -order 20
    template::head::add_javascript -src /resources/xowiki/chat-common.js -order 21
    template::head::add_javascript -src /resources/xowiki/chat-skins/chat-$skin.js -order 22
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
               <input type='text' placeholder="$message_label" name='msg' id='xowiki-chat-send' autocomplete="off" />
               <button id='xowiki-chat-send-button' type='submit'>$send_label</button>
             </form>
           </div>
         </div>
         <div id='xowiki-chat-users'></div>
      </div>
      <span id="xowiki-my-user-id" hidden>[ad_conn user_id]</span>
    }]

    set conf [dict create]
    foreach var [list login_messages_p logout_messages_p timewindow] {
      if {[info exists $var]} {
        dict set conf $var [set $var]
      }
    }

    :create c1 \
        -destroy_on_cleanup \
        -chat_id    $chat_id \
        -session_id $session_id \
        -mode       $mode \
        -conf       $conf
    #:log "--CHAT created c1 with mode=$mode"

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

    append html [subst {
      <script nonce='$::__csp_nonce'>
        addSendPic();
      </script>
    }]

    #:log "--CHAT create HTML for mode=$mode"

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


::xo::library source_dependent
#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
