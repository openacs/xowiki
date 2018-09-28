// simple javascript support for streaming ajax based chat interface
// $Id$
// -gustaf neumann   April 2006

var http = getHttpObject();
// Pointer to the last character read from the partial ajax request.
var http_last = 0;
var http_send = getHttpObject();

function getData() {
    // alert('access responseText'); // hmm, IE does not allow us to
    // access responstext in state == 3 :(
    var response = http.responseText.substring(http_last);
    // We recognize a complete message by a trailing }\n. One line
    // might contain multiple messages though.
    if (response.match(/\}[\n ]+$/)) {
        var messages = response.split("\n");
        for (var i = 0; i < messages.length; i++) {
            var message = messages[i].trim();
            if (message == '') {continue;}
            console.log(message);
            var json = JSON.parse(message);
            renderData(json);
        }
        http_last = http.responseText.length;
    }
}

function chatSubscribe(subscribe_url) {
    http.open('GET', subscribe_url, true);
    http.onreadystatechange = function() {
        if (http.readyState == 3) {
	    getData();
        } else if (http.readyState == 4) {
            //console.log("chatSubscribe readyState = " + http.readyState + " status " + http.status);
            // alert('status code =' + http.status);
            var status = http.status;
            if (status == 200 || status == 0) {
            } else {
	        alert('Something wrong in HTTP request, status code = ' + status);
            }
        }
    };
    http.send(null);
    http_last = 0;
}

function streamingSendMsgHandler() {
    if (http_send.readyState == 4) {
        if (http_send.status != 200) {
	    alert('Something wrong in HTTP request, status code = ' + http_send.status);
        }
    }
};
