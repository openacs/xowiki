// simple javascript support for streaming ajax based chat interface
// $Id$
// -gustaf neumann   April 2006

function chatSubscribe(subscribe_url) {
    const source = new EventSource(subscribe_url);

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
            setTimeout(chatSubscribe, 10000, subscribe_url);
        }
    });
}

var http_send = getHttpObject();
function streamingSendMsgHandler() {
    if (http_send.readyState == 4) {
        if (http_send.status != 200) {
	    alert('Something wrong in HTTP request, status code = ' + http_send.status);
        }
    }
};
