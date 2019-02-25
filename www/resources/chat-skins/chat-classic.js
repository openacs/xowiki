// Javascript side of the Classic Chat skin

var previous_user_id = "";
var current_color = "";

// Full screen
function addFullScreenLink() {

    // Full screen trigger block
    const triggerFSblock = document.createElement("div");
    triggerFSblock.className = 'xowiki-chat-trigger-fs-block';

    // Full screen trigger
    const triggerFSlink = document.createElement("a");
    triggerFSlink.className = 'xowiki-chat-trigger-fs-link';
    triggerFSlink.setAttribute("href", "#");

    // Trigger icon
    var triggerFSoff = '<svg class="xowiki-chat-trigger-fs-pic" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 12 14" preserveAspectRatio="xMidYMin meet"><g stroke-width=".033882"><path d="m4.994 10.008v2.1596l-0.6017-0.602-0.6017-0.601-1.0668 1.068c-0.58675 0.58697-1.0823 1.0672-1.1012 1.0672-0.04453 0-1.5755-1.5315-1.5755-1.576 0-0.0186 0.49551-0.52914 1.1011-1.1345l1.1011-1.1007-0.71966-0.72024-0.71966-0.72024h4.1838z"/><path d="m9.7119 8.5856-0.71966 0.72024 1.0842 1.0838c0.5963 0.59609 1.0842 1.0993 1.0842 1.1182 0 0.01889-0.3507 0.38481-0.77933 0.81314l-0.7791 0.779-1.0758-1.076-1.0759-1.075-0.6182 0.618-0.6182 0.618v-4.3196h2.1089 2.1089z"/><path d="m2.8589 2.4267 1.0838 1.0842 0.60168-0.60099 0.60168-0.60099v2.1258 2.1258h-4.0148l0.6182-0.6182 0.6182-0.6182-1.1602-1.1606-1.1602-1.1606 0.82964-0.83016c0.4563-0.45658 0.84509-0.83016 0.86398-0.83016 0.01888 0 0.52204 0.48787 1.1181 1.0842z"/><path d="m10.331 2.1727 0.82964 0.83016-1.1602 1.1606-1.1602 1.1606 0.6182 0.6182 0.6182 0.6182h-3.9814v-4.3194l0.61862 0.61794 0.61862 0.61794 1.0668-1.0672c0.58675-0.58697 1.0747-1.0672 1.0842-1.0672 0.0096 0 0.39074 0.37357 0.84704 0.83016z"/></g></svg>';
    var triggerFSon = '<svg class="xowiki-chat-trigger-fs-pic" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 12 14" preserveAspectRatio="xMidYMin meet"><path stroke-width=".033882" d="m0.047182 10.94v-2.1595l0.60168 0.60099 0.60168 0.60099 1.0668-1.0672c0.58675-0.58697 1.0823-1.0672 1.1012-1.0672 0.04453 0 1.5755 1.5315 1.5755 1.576 0 0.0186-0.49551 0.52914-1.1011 1.1345l-1.1011 1.1007 0.71966 0.72024 0.71966 0.72024h-4.1838zm7.6153 1.4394 0.71966-0.72024-1.0842-1.0838c-0.5963-0.5956-1.0842-1.0988-1.0842-1.1177 0-0.01889 0.3507-0.38481 0.77933-0.81314l0.77933-0.77878 1.0759 1.0755 1.0759 1.0755 0.6182-0.6182 0.6182-0.6182v4.3198h-4.2182zm-5.3282-6.9032-1.0838-1.0842-0.60168 0.60099-0.60168 0.60099v-4.2516h4.0148l-0.6182 0.6182-0.6182 0.6182 1.1602 1.1606 1.1602 1.1606-0.82964 0.83016c-0.4563 0.45658-0.84509 0.83016-0.86398 0.83016-0.01888 0-0.52204-0.48787-1.1181-1.0842zm4.591 0.25401-0.82964-0.83016 1.1602-1.1606 1.1602-1.1606-0.6182-0.6182-0.6182-0.6182h3.981v4.3194l-0.61862-0.61794-0.61862-0.61794-1.0668 1.0672c-0.58675 0.58697-1.0747 1.0672-1.0842 1.0672-0.0096 0-0.39074-0.37357-0.84704-0.83016z"/></svg>';
    triggerFSlink.innerHTML = triggerFSon;

    // Full screen when clicked
    triggerFSlink.addEventListener("click", function(event) {
        event.preventDefault();
        var chat = document.getElementById('xowiki-chat');
        var chatFS = document.getElementById('xowiki-chat-fs');
        if (chat != null) {
            chat.id = 'xowiki-chat-fs';
            triggerFSlink.innerHTML = triggerFSoff;
            document.body.style.overflow = "hidden";
        } else if (chatFS != null) {
            chatFS.id = 'xowiki-chat';
            triggerFSlink.innerHTML = triggerFSon;
            document.body.style.overflow = "scroll";
        }
        // Scroll down the messages
        var messages = document.getElementById('xowiki-chat-messages');
        messages.scrollTop = messages.scrollHeight;
    });

    // Add Full screen trigger to the chat
    const formBlock = document.getElementById('xowiki-chat-messages-form-block');
    triggerFSblock.appendChild(triggerFSlink);
    formBlock.appendChild(triggerFSblock);
}

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
    var my_user = document.getElementById('xowiki-my-user-id');
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
    span.textContent = user;
    span.setAttribute("class", "xowiki-chat-user");
    span.setAttribute("style", "color:" + color);
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

// Render the user in the user list
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

        // User picture
        var show_avatar = document.getElementById('xowiki-chat-show-avatar');
        if (show_avatar != null) {
            wrapper = document.createElement('div');
            wrapper.className = 'xowiki-chat-user-pic-wrap';
            img = document.createElement('img');
            img.setAttribute("src", "/shared/portrait-bits.tcl?user_id=" + user_id);
            img.setAttribute("class", "xowiki-chat-user-pic");
            img.setAttribute("style", "border-color:" + color);
            wrapper.appendChild(img);
            user_block.appendChild(wrapper);
        }

        // User name
        span = document.createElement('span');
        span.textContent = user;
        span.setAttribute("class", "xowiki-chat-user");
        span.setAttribute("style", "color:" + color);
        user_block.appendChild(span);

        br = document.createElement('br');
        user_block.appendChild(br);

        // Timestamp
        span = document.createElement('span');
        span.innerHTML = msg.message[i].timestamp;
        span.className = 'xowiki-chat-timestamp';
        user_block.appendChild(span);

        users.appendChild(a);
    }
}
