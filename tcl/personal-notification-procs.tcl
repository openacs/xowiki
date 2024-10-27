::xo::library doc {

  Personal notifications - Mode procs

  @creation-date 2020-08-02
  @author Gustaf Neumann
}

::xo::library require includelet-procs

namespace eval ::xowiki::includelet {
  #
  # Includelet interface to personal notifications
  #
  Class create personal-notification-messages -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration plain}
        {parameter_declaration {
          {-url_poll ""}
          {-url_dismiss ""}
          {-poll_interval 5000}
        }}
      } -ad_doc {
        Personal notification messages

        This includelet can be used for personal messaging, where a
        sender can send messages to a single user in a single
        applications (e.g. in an exam), where the user has to
        acknowledge every single message to make it disappear
        (current implementation). The messages are not persisted
        (current implementation).
      }

  personal-notification-messages ad_proc get_messages_response {
    {-notification_id:integer}
    {-user_id:integer}
  } {

    Get all messages for the notification-id and the give user in form
    of an AJAX array.

  } {
    #
    # Get messages for this notification_id and user. This function
    # returns a JSON result.
    #
    # TODO: replace inclass_exam with personal_notifications
    if {[nsv_dict exists inclass_exam $notification_id $user_id]} {
      set msgs [nsv_dict get inclass_exam $notification_id $user_id]
    } else {
      set msgs {}
    }
   #
    # Convert the messages to JSON. The timestamp (ts) is used as an
    # ID for an individual message.
    #
    set json {}
    foreach {ts msgDict} $msgs {
      set msg  [string map {\" {\"} \n {<br>}} [dict get $msgDict msg]]
      set from [string map {\" {\"} \n {<br>}} [::xo::get_user_name [dict get $msgDict from]]]
      set urgency [string map {\" {\"} \n {<br>}} [dict get $msgDict urgency]]
      lappend json [subst -nobackslash {{"text": "$msg","ts":$ts,"from":"$from","urgency":"$urgency"}}]
    }
    return [subst {\[[join $json ,]\]}]
  }

  personal-notification-messages ad_proc message_add {
    {-notification_id:integer}
    {-to_user_id:integer,1..n}
    {-payload:required}
  } {

    Send the user a message. The payload has the form of a dict
    containing at least "msg" and "from" (in form of a user_id).

  } {
    #
    # Set the timestamp to [clock microseconds]. It is assumed that we have
    # at most one message per microsecond to this user.
    #
    foreach to_user_id $to_user_id {
      nsv_dict set inclass_exam $notification_id $to_user_id \
          [clock microseconds] \
          $payload
    }
  }

  personal-notification-messages ad_proc message_dismiss {
    {-notification_id:integer}
    {-user_id:integer}
    {-ts:integer}
  } {

    The user has dismissed a message. flush this message from the set
    of displayed messages.

  } {
    nsv_dict unset inclass_exam $notification_id $user_id $ts
  }

  personal-notification-messages ad_proc modal_message_dialog {
    -to_user_id:integer,1..n,required
    {-title "#xowiki.Send_message_to#"}
    {-adpicon pencil}
  } {
    Create a bootstrap3/5-compatible modal dialog
  } {
    if {[::template::CSS toolkit] eq "bootstrap5"} {
      set data_attribute "data-bs"
      set close_button_label ""
      set before_close  "<h4 class='modal-title' id='configurationModalTitle'>$title</h4>"
      set after_close  ""

    } else {
      set data_attribute "data"
      set close_button_label {<span aria-hidden="true">&#215;</span>}
      set before_close  ""
      set after_close  "<h4 class='modal-title' id='configurationModalTitle'>$title</h4>"
    }
    if {[llength $to_user_id] == 1} {
      set id dialog-msg-$to_user_id
      set to_user_name [::xo::get_user_name $to_user_id]
    } else {
      set id dialog-msg-all
      set to_user_name " [llength $to_user_id] #xowiki.Participants#"
    }
    append title " " $to_user_name

    foreach to_user_id $to_user_id {
      append input_fields [subst {<input type="hidden" name="to_user_id" value="$to_user_id">}]
    }
    set btnDefault [::template::CSS class btn-default]
    return [list link [subst {
      <a href="#$id" title="$title" role="button" $data_attribute-toggle="modal" $data_attribute-keyboard="false">
      <adp:icon name="$adpicon" aria-hidden="true"></span>
    }] dialog [subst {
      <div class="modal fade" id='$id' tabindex="-1" role="dialog">
      <div class="modal-dialog" role="document">
<form role="form" class="form-vertical" method="post" action="">
  <div class="modal-content">
    <div class="modal-header">
      $before_close<adp:button type="button" class="close" data-dismiss="modal" aria-label="Close">$close_button_label
      </adp:button>$after_close
    </div><!-- modal-header -->

    <div class="modal-body">
      <div class="form-group">
      <label for="msg"><adp:icon name="$adpicon"> #xowiki.Message#</label>
        <input class="form-control" id="msg" name="msg" placeholder="#xowiki.Enter_message#" required autofocus>
      </div>
      <div class="form-group">
      #xowiki.Urgency#
        <label class="radio-inline" for="option1">#xowiki.urgency_low#</label>
        <input id="option1" name="urgency" value="info" type="radio">
        <label class="radio-inline" for="option2">#xowiki.urgency_normal#</label>
        <input id="option2" name="urgency" value="warning" type="radio" checked>
        <label class="radio-inline" for="option3">#xowiki.urgency_high#</label>
        <input id="option3" name="urgency" value="danger" type="radio">
      </div> <!--form-group-->

      $input_fields
    </div><!--modal-body-->
    <div class="modal-footer">
    <adp:button type="button" class="btn btn-default" data-dismiss="modal">#acs-kernel.common_Close#</adp:button>
    <adp:button type="submit" class="btn btn-default submit" data-id="$id" data-dismiss="modal">#xowiki.Send#</adp:button>
    </div>
  </div>
</form>
      </div><!--modal-dialog-->
      </div><!--modal-->
    }]]
  }

  personal-notification-messages ad_proc modal_message_dialog_register_submit {
    -url:required
  } {

    Register a submit callback for all bootstrap3 modal dialogs having
    an .submit class.

  } {
    template::add_body_script -script [subst {
      document.querySelectorAll('div.modal form .submit').forEach(function(e) {
        e.addEventListener('click', function(ev){
          ev.preventDefault();
          //console.log(ev.target.dataset.id);
          var form = document.querySelector('#' + ev.target.dataset.id + ' form');

          var data = new FormData(form);
          var xhttp = new XMLHttpRequest();
          xhttp.open('POST', '$url', true);
          xhttp.onload = function () {
            //console.log(this.responseText);
          };
          xhttp.send(data);
        });});
    }]
  }

  personal-notification-messages instproc initialize {} {
    :get_parameters
    #
    # The following code depends on the variables
    #
    # - url_poll
    # - url_dismiss
    # - poll_interval
    #
    # provided via get_parameters
    #

    # Create Bootstrap3/5 compatible attributes
    if {[::template::CSS toolkit] eq "bootstrap5"} {
      set data_attribute "data-bs"
      set close_button_label ""
    } else {
      set data_attribute "data"
      set close_button_label {<span aria-hidden="true">&#215;</span>}
    }
    template::add_body_script -script [subst {
      var inclass_exam_messages_ts = \[\];

      var inclass_exam_dismiss_handler = function (ev) {
        var ts = ev.target.dataset.ts;
        var xhttp = new XMLHttpRequest();
        xhttp.open("GET", '$url_dismiss&ts=' + ts, true);
        xhttp.send();
      };

      var inclass_exam_get_data = function () {
        var xhttp = new XMLHttpRequest();
        xhttp.open("GET", '$url_poll', true);
        xhttp.onreadystatechange = function() {
          if (this.readyState == 4 && this.status == 200) {
            //console.log(xhttp.responseText);
            var data_array = JSON.parse(xhttp.responseText);
            var el = document.querySelector('#personal-notification-messages');
            var block = '';
            data_array.forEach(function(data) {
              if (data.text != "" && typeof data.text !== "undefined" ) {
                if (inclass_exam_messages_ts.indexOf(data.ts) == -1) {
                  var alert = 'alert-' + data.urgency;
                  block = '<div class="alert ' + alert + ' alert-dismissible" style="width:50%">'
                  + '<button id="ts' + data.ts + '" data-ts="' +  data.ts + '" href="#" class="[::template::CSS class close]" '
                  + '$data_attribute-dismiss="alert" aria-label="close">$close_button_label</button>'
                  + '<strong>' + data.from +':</strong> <span>' + data.text + '</span>'
                  + '</div>';
                  inclass_exam_messages_ts.push(data.ts);
                }
              }
              if (block != '') {
                el.innerHTML += block;
              }
            });
            document.querySelectorAll('button.[::template::CSS class close]').forEach(function(e) {
              //console.log('register dismiss handler ts '+ e.dataset.ts);
              e.removeEventListener('click', inclass_exam_dismiss_handler);
              e.addEventListener('click', inclass_exam_dismiss_handler);
            });
          }
        };
        xhttp.send();
      };

      inclass_exam_get_data();
      (function poll() {
        setTimeout(function() {
          inclass_exam_get_data();
          poll();
        }, $poll_interval);
      })();
    }]
  }

  personal-notification-messages instproc render {} {
    return {
      <div id='personal-notification-messages'>
      </div>
    }
  }
}

::xo::library source_dependent
#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
