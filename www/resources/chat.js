/*

  Chat Javascript library

  In this file we implement the client-side behavior of the chat
  implementation from tcl/chat-procs.tcl

*/

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
function askNotificationPermission(notificationBtn) {
    // function to actually ask the permissions
    function handlePermission(permission) {
        // Whatever the user answers, we make sure Chrome stores the information
        if(!('permission' in Notification)) {
            Notification.permission = permission;
        }

        // set the button to shown or hidden, depending on what the user answers
        if(Notification.permission === 'default') {
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
    var notificationButton = document.getElementById('enableNotifications');
    if (notificationButton !== null) {
        if(Notification.permission === 'default') {
            // Add the listener to the button and show it, only if the
            // notification permission is 'default' (the user has not accepted
            // or explicitly denied notifications)
            notificationButton.style.display = 'block';
            notificationButton.addEventListener("click", function() {
                askNotificationPermission(notificationButton);
            });
        }
    }
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
        // Produce notifications
        if (windowInactive) {
            // Tab notification
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

function userLinkElement(user_id, current_user) {
    let element;
    let href;

    if (user_id == 0 || !Number(user_id)) {
        href = '';
    } else if (user_id != current_user) {
        href = '/shared/community-member?user%5fid=' + user_id;
    } else {
        href = '/pvt/home';
    }

    if (href != "") {
        element = document.createElement('a');
        element.href = href;
        element.target = '_blank';
    } else {
        element = document.createElement('span');
    }

    element.className = 'xowiki-chat-user-link';

    return element;
}

function chatSubscribe(url) {
    const queryString = url.slice(url.indexOf('?') + 1);
    const searchParams = new window.URLSearchParams(queryString);

    let mode;
    let subscribeURL = url;
    if (searchParams.get('mode') !== null) {
        //
        // A mode was specified explicitly. We use it.
        //
        mode = searchParams.get('mode');
    } else {
        //
        // In absence of a mode, we prefer 'streaming', unless Server
        // Sent Events are not supported. In such case,'scripted' will
        // be used.
        //
        mode = typeof window.EventSource === 'undefined' ? 'scripted' : 'streaming';
        subscribeURL+= '&mode=streaming';
    }

    switch (mode) {
    case 'streaming':
        //
        // Streaming
        //
        // This is the recommended mode using a persistent connection
        // via EventSource.
        //
        const source = new EventSource(`${subscribeURL}&m=subscribe`);

        source.addEventListener('message', (e) => {
            renderData(JSON.parse(e.data));
        });

        //
        // Attempt to reconnect in case of error, but only if the
        // connection is closed: some browsers will reconnect
        // automatically.
        //
        source.addEventListener('error', (e) => {
            if (source.readyState === EventSource.CLOSED) {
                setTimeout(chatSubscribe, 10000, subscribeURL);
            }
        });

        //
        // Close the EventSource connection before we leave/reload the
        // page: some browsers, such as Firefox at the time of
        // writing, may complain otherwise.
        //
        window.addEventListener('beforeunload', (e) => {
            source.close();
        });

        break;
    case 'scripted':
        //
        // Scripted streaming
        //
        // This mode opens and "infinitely long" HTML file in a hidden
        // iframe. On new messages, a javascript fragment will be
        // written in the response that we will pick up and display.
        //
        // This technique, once known under the name "Comet" is a
        // fallback for clients that do not support Server Sent
        // Events.
        //
        //
        window.addEventListener('message', (e) => {
            renderData(e.data);
        });

        const iframe = document.createElement('iframe');
        iframe.src = `${subscribeURL}&m=subscribe`;
        iframe.setAttribute('style', 'width:0px; height:0px; border: 0px');
        document.body.appendChild(iframe);
        break;
    case 'polling':
        //
        // Polling mode
        //
        // In this mode, a new request at every given interval
        // (currently hardcoded to 5 seconds) is required to fetch new
        // messages. This will not scale well with a big number of
        // clients, but is the most reliable mode in case of older
        // versions of NaviServer/AOLserver or limited browser
        // capabilities.
        //
        subscribeURL+= '&m=get_new';
        setInterval(function () {
            const http = new XMLHttpRequest();
            http.open('GET', subscribeURL);
            http.addEventListener('load', function () {
                if (this.status === 200) {
                    for (const json of JSON.parse(this.responseText)) {
                        renderData(json);
                    }
                } else {
                    clearInterval();
                    alert('Something wrong in HTTP request, status code = ' + this.status);
                }
            });
            http.send();
        }, 5000);
        break
    default:
        alert(`Invalid mode '${mode}'`);
    }

    //
    // Send the message when the chat form is submitted.
    //
    const msgField = document.getElementById('xowiki-chat-send');
    document.querySelector('#xowiki-chat-messages-form').addEventListener('submit', (e) => {
        e.preventDefault();
        if (msgField.value === '') {
            return;
        }
        const httpSend = new XMLHttpRequest();
        httpSend.open('GET', `${url}&m=add_msg&msg=${encodeURIComponent(msgField.value)}`);
        httpSend.send();
        if (mode === 'polling') {
            //
            // When polling we take the chance, whenever a message is
            // sent, to receive new messages in the response.
            //
            httpSend.addEventListener('load', function () {
                if (this.status === 200) {
                    for (const json of JSON.parse(this.responseText)) {
                        renderData(json);
                    }
                } else {
                    alert('Something wrong in HTTP request, status code = ' + this.status);
                }
            });
        }

        msgField.value = '';
    });

    //
    // The message field is focused by default.
    //
    msgField.focus();
}
