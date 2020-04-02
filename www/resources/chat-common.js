// Common xowiki chat functions

// Add notifications of new messages in the browser tab
var windowInactive = false;
var notifications = 0;
var title = document.title;
window.addEventListener('focus', windowFocus);
window.addEventListener('blur', windowBlur);
function windowBlur() {
    windowInactive = true;
}
function windowFocus() {
    windowInactive = false;
    document.title = title;
    notifications = 0;
}

// Add "Web notifications" of new messages
// https://www.w3.org/TR/notifications/
function checkNotificationPromise() {
    try {
        Notification.requestPermission().then();
    } catch(e) {
        return false;
    }
    return true;
}
function askNotificationPermission() {
    var notificationBtn = document.getElementById('enableNotifications');
    // function to actually ask the permissions
    function handlePermission(permission) {
        // Whatever the user answers, we make sure Chrome stores the information
        if(!('permission' in Notification)) {
            Notification.permission = permission;
        }

        // set the button to shown or hidden, depending on what the user answers
        if(Notification.permission === 'denied' || Notification.permission === 'default') {
            notificationBtn.style.display = 'block';
        } else {
            notificationBtn.style.display = 'none';
        }
    }

    // Let's check if the browser supports notifications
    if (!('Notification' in window)) {
        console.log("This browser does not support notifications.");
    } else {
        if(checkNotificationPromise()) {
            Notification.requestPermission()
                .then((permission) => {
                    handlePermission(permission);
                })
        } else {
            Notification.requestPermission(function(permission) {
                handlePermission(permission);
            });
        }
    }
}
window.onload = function () {
    document.getElementById('enableNotifications').addEventListener("click", askNotificationPermission);
}

// Retrieve user_id
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
        // Produce tab notification
        if (windowInactive) {
            notifications++;
            var newTitle = '(' + notifications + ') ' + title;
            document.title = newTitle;
            // Web notification
            var user_id = json.user_id;
            var text = json.user.replace(/\\'/g, "\"") + ": " + json.message;
            var img = "/shared/portrait-bits.tcl?user_id=" + user_id;
            var notification = new Notification(title, { body: text, icon: img });
        }
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
