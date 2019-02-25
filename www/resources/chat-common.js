// Send the message
function chatSendMsg(send_url, handler) {
    var msgField = document.getElementById('xowiki-chat-send');
    var msg = msgField.value;
    if (msg == '') {return;}
    http_send.open('GET', send_url + encodeURIComponent(msg), true);
    http_send.responseType = 'json';
    http_send.onreadystatechange = handler;
    http_send.send(null);
    msgField.value = '';
}
