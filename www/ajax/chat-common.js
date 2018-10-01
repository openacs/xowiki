// Common xowiki chat functions, mainly for data rendering.

function renderData(json) {
    if (json.type == "message") {
        renderMessage(json);
    } else if (json.type == "users") {
        renderUsers(json);
    }
}

function renderMessage(msg) {
    var messages = document.getElementById('xowiki-chat-messages');
    p = document.createElement('p');
    span = document.createElement('span');
    span.innerHTML = msg.timestamp;
    span.className = 'xowiki-chat-timestamp';
    p.appendChild(span);

    span = document.createElement('span');
    var user = msg.user.replace(/\\'/g, "\"");
    span.innerHTML = '&nbsp;' + user + ':&nbsp;';
    span.className = 'xowiki-chat-user';
    p.appendChild(span);

    span = document.createElement('span');
    span.innerHTML = msg.message;
    span.className = 'xowiki-chat-message';
    p.appendChild(span);

    messages.appendChild(p);
    messages.scrollTop = messages.scrollHeight;

    // IE will lose focus on message send
    document.getElementById('xowiki-chat-send').focus();
}

function renderUsers(msg) {
    var users = document.getElementById('xowiki-chat-users');
    while (users.hasChildNodes()) {
        users.removeChild(users.firstChild);
    }
    for (var i = 0; i < msg.message.length; i++) {
        p = document.createElement('p');
        span = document.createElement('span');
        span.innerHTML = msg.message[i].timestamp;
        span.className = 'xowiki-chat-timestamp';
        p.appendChild(span);

        span = document.createElement('span');
        var user = msg.message[i].user.replace(/\\'/g, "\"");
        span.innerHTML = '&nbsp;' + user + '&nbsp;';
        span.className = 'xowiki-chat-user';
        p.appendChild(span);
        users.appendChild(p);
    }
}

function chatSendMsg(send_url, handler) {
    var msgField = document.getElementById('xowiki-chat-send');
    var msg = msgField.value;
    if (msg == '') {return;}
    http_send.open('GET', send_url + encodeURIComponent(msg), true);
    http_send.onreadystatechange = handler;
    http_send.send(null);
    msgField.value = '';
}
