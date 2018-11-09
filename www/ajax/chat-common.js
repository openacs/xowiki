// Common xowiki chat functions, mainly for data rendering.

var previous_user_id = "";
var current_color = "";

function createLink(text) {
    if (linkRegex != null) {
        return text.replace(new RegExp(linkRegex,'g'), function(url) {
            return '<a class="xowiki-chat-message-url" href="' + url + '">' + url + '</a>';
        })
    } else {
        return text;
    }
}

function renderData(json) {
    if (json.type == "message") {
        renderMessage(json);
    } else if (json.type == "users") {
        renderUsers(json);
    }
}

function renderMessage(msg) {
    var messages = document.getElementById('xowiki-chat-messages');
    var user = msg.user.replace(/\\'/g, "\"");
    var message = createLink(msg.message);
    var user_id = msg.user_id;
    var my_user = document.getElementById('my-user-id');
    if (my_user == null) {
        my_user_id = "";
    } else {
        my_user_id = my_user.innerText;
    }
    var color = msg.color;

    // User block
    user_block = document.createElement('div');
    user_block.className = 'xowiki-chat-user-block';

    // User link
    a = document.createElement('a');
    a.href = '/shared/community-member?user%5fid=' + user_id;
    a.target = '_blank';
    a.className = 'xowiki-chat-user-link';

    // User name
    span = document.createElement('span');
    span.innerHTML = user;
    span.className = 'xowiki-chat-user';
    span.style = 'color:' + color;
    a.appendChild(span);
    user_block.appendChild(a);
    previous_user_id = user_id;
    current_color = color;

    messages.appendChild(user_block);

    message_block = document.createElement('div');
    if (user_id != my_user_id) {
        message_block.className = 'xowiki-chat-message-block';
    } else {
        message_block.className = 'xowiki-chat-message-block-me';
    }

    // Message body
    span = document.createElement('span');
    span.innerHTML = message;
    if (user_id != my_user_id) {
        span.className = 'xowiki-chat-message';
    } else {
        span.className = 'xowiki-chat-message-me';
    }
    message_block.appendChild(span);

    // Timestamp
    span = document.createElement('span');
    span.innerHTML = msg.timestamp;
    if (user_id != my_user_id) {
        span.className = 'xowiki-chat-timestamp';
    } else {
        span.className = 'xowiki-chat-timestamp-me';
    }
    message_block.appendChild(span);

    messages.appendChild(message_block);

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
        var user = msg.message[i].user.replace(/\\'/g, "\"");
        var user_id = msg.message[i].user_id;
        var color = msg.message[i].color;

        // User link
        a = document.createElement('a');
        a.href = '/shared/community-member?user%5fid=' + user_id;
        a.target = '_blank';
        a.className = 'xowiki-chat-user-link';

        // User block
        user_block = document.createElement('div');
        user_block.className = 'xowiki-chat-user-block';
        a.appendChild(user_block);

        // User name
        span = document.createElement('span');
        span.innerHTML = user;
        span.className = 'xowiki-chat-user';
        span.style = 'color:' + color;
        user_block.appendChild(span);

        // Timestamp
        span = document.createElement('span');
        span.innerHTML = msg.message[i].timestamp;
        span.className = 'xowiki-chat-timestamp';
        user_block.appendChild(span);

        users.appendChild(a);
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
