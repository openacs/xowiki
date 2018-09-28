// simple javascript support for streaming ajax based chat interface
// $Id$
// -gustaf neumann   April 2006

var http_send = getHttpObject();

// This function MUST be there as in
// xotcl-core/tcl/bgdelivery-procs.tcl we expect getData to elaborate
// data coming from the continuos javascript iframe.
function getData(data) {
    renderData(data);
}

function scriptedStreamingSendMsgHandler() {
    if (http_send.readyState == 4) {
        if (http_send.status != 200) {
            alert('Something wrong in HTTP request, status code = ' + http_send.status);
        }
    }
};
