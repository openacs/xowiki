// simple javascript support for polling ajax based chat interface
// $Id$
// -gustaf neumann   April 2006

var http = getHttpObject();
var http_send = getHttpObject();

function chatSubscribe(subscribe_url) {
    setInterval(function () {
        http.open('GET', subscribe_url);
        http.onreadystatechange = function () {
            if (http.readyState == 4) {
                // alert('status code =' + http.status);
                if (http.status == 200) {
                    var json = JSON.parse(http.responseText);
                    for (var i = 0; i < json.length; i++) {
                        renderData(json[i]);
                    }
                } else {
                    clearInterval();
                    alert('Something wrong in HTTP request, status code = ' + http.status);
                }
            }
        };
        http.send(null);
    }, 5000);
}

function pollingSendMsgHandler() {
    if (http_send.readyState == 4) {
        if (http_send.status != 200) {
	    alert('Something wrong in HTTP request, status code = ' + http_send.status);
        } else {
            var json = JSON.parse(http_send.responseText);
            for (var i = 0; i < json.length; i++) {
                renderData(json[i]);
            }
        }
    }
};
