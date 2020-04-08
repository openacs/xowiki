// Javascript side of the Minimal Chat skin

var previous_user_id = "";
var current_color = "";

// Send link pic
function addSendPic() {

    var sendPic = '<svg id="xowiki-chat-messages-send-pic" viewBox="0 0 17 17"><g transform="matrix(.68293 0 0 .68293 -6.8692 -10.005)"><path d="m12.464 29.628 6.1719 2.62v3.0647l2.1274-2.1993 6.2291 2.7083 2.4332-16.385z" stroke-width="2.0246px"/><path style="paint-order:fill markers stroke" d="m19.418 31.75 2.0106-1.59-0.87695 2.3341-0.85313 0.03109z" stroke-width="2.6148"/></g></svg>';
    var button = document.getElementById('xowiki-chat-send-button');

    if (button != null) {
        button.innerHTML = sendPic;
    }
}

// Render the message
function renderMessage(msg) {
    var messages = document.getElementById('xowiki-chat-messages');
    var user = msg.user.replace(/\\'/g, "\"");
    var message = createLink(msg.message);
    var user_id = msg.user_id;
    var color = msg.color;

    // Message block
    message_block = document.createElement('div');
    message_block.className = 'xowiki-chat-message-block';

    // User picture
    wrapper = document.createElement('div');
    wrapper.className = 'xowiki-chat-user-pic-wrap';
    if (show_avatar) {
        img = document.createElement('img');
        img.src = '/shared/portrait-bits.tcl?user_id=' + user_id
        img.className = 'xowiki-chat-user-pic';
        img.style = 'border-color:' + color;
        wrapper.appendChild(img);
    }
    message_block.appendChild(wrapper);

    // Timestamp
    span = document.createElement('span');
    span.innerHTML = msg.timestamp.replace(/\[|\]/g, "");
    span.className = 'xowiki-chat-timestamp';
    message_block.appendChild(span);

    // User block
    user_block = document.createElement('div');
    user_block.className = 'xowiki-chat-user-block';

    // User name
    span = document.createElement('span');
    span.textContent = user;
    span.setAttribute("class", "xowiki-chat-user");
    span.setAttribute("style", "color:" + color);
    user_block.appendChild(span);
    previous_user_id = user_id;
    current_color = color;
    message_block.appendChild(user_block);

    // Message body
    span = document.createElement('span');
    span.innerHTML = message;
    span.className = 'xowiki-chat-message';
    message_block.appendChild(span);


    messages.appendChild(message_block);

    messages.scrollTop = messages.scrollHeight;

    // IE will lose focus on message send
    document.getElementById('xowiki-chat-send').focus();
}

// Render the user in the user list
function renderUsers(msg) {
    var users = document.getElementById('xowiki-chat-users');
    while (users.hasChildNodes()) {
        users.removeChild(users.firstChild);
    }
    for (var i = 0; i < msg.message.length; i++) {
        // User block (hidden, useful for counting active users)
        user_block = document.createElement('div');
        user_block.className = 'xowiki-chat-user-block';
        users.appendChild(user_block);
    }
}
