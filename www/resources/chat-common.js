// Common xowiki chat functions

function chatGetMyUserId() {
    var my_user = document.getElementById('xowiki-my-user-id');
    if (my_user == null) {
        my_user_id = "";
    } else {
        my_user_id = my_user.innerText;
    }
    return my_user_id;
}

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

// Simple function to create links
function createLink(text) {
    if (linkRegex != null) {
        return text.replace(new RegExp(linkRegex,'g'), function(url) {
            return '<a class="xowiki-chat-message-url" href="' + url + '">' + url + '</a>';
        })
    } else {
        return text;
    }
}

// Render the data, being a user or a message
function renderData(json) {
    if (json.type == "message") {
        renderMessage(json);
    } else if (json.type == "users") {
        renderUsers(json);
        if (document.getElementById('active_users') !== null) {
            var active_users = document.getElementById('xowiki-chat-users').getElementsByClassName('xowiki-chat-user-block').length;
            if (active_users == 0) {
                    active_users = 1
            }
            document.getElementById('active_users').textContent = active_users;
        }
    }
}
