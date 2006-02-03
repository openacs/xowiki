namespace eval ::xowiki::tmp {
  ::xowiki::Object create ajax-chat -noinit \
      -set object_type ::xowiki::Object \
      -set lang en \
      -set description {} \
      -set text {
proc content {} {
  auth::require_login
  set chat_id 22
  set path packages/xowiki/www/ajax/chat.js
  if { ![file exists [acs_root_dir]/$path] } {
    return -code error "File [acs_root_dir]/$path does not exist"
  }
  set file [open [acs_root_dir]/$path]; set js [read $file]; close $file
  set login_url /xowiki/ajax/chat?m=login&id=$chat_id
  set send_url  /xowiki/ajax/chat?m=add_msg&id=$chat_id&msg=
  set get_update  "chatSendCmd(\"/xowiki/ajax/chat?m=get_new&id=$chat_id\",chatReceiver)"
  set get_all     "chatSendCmd(\"/xowiki/ajax/chat?m=get_all&id=$chat_id\",chatReceiver)"
  return "
   <script type='text/javascript' language='javascript'>
   $js
   setInterval('$get_update',5000)
   //setTimeout('$get_all',5000)
   </script>
   <form action='#' onsubmit='chatSendMsg(\"$send_url\", chatReceiver); return false;'>
   <iframe name='ichat' id='ichat' frameborder='0' src='$login_url'
          style='width:95%;' height='150'>

   </iframe>
   <input type='hidden' name='m' value='add_msg'> 
   <input type='text' size='40' name='msg' id='chatMsg'> 
   <span id='chatCounter'>0</span>
   <span id='chatResponse'>&nbsp;</span>
"
}
} \
	-set nls_language en_US \
	-set mime_type {text/html} \
	-set title en:ajax-chat
}

set page_title "Import XoWiki Pages"
set context {}
set msg [::xowiki::Page import -objects ::xowiki::tmp::ajax-chat -replace true]
template::set_file "[file dir $__adp_stub]/../importmsg"
ad_return_template
