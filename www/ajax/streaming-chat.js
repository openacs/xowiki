// simple javascript support for streaming ajax based chat interface
// $Id$
// -gustaf neumann   April 2006

var http = getHttpObject();
var http_last = 0;
var http_send = getHttpObject();

function getData() {
  //alert('access responseText'); // hmm, IE does not allow us to access responstext in state == 3 :(
  var response = http.responseText.substring(http_last);
  // we recognize a complete message by a trailing }\n
  if (response.match(/\}[\n ]+$/)) {
    var messages = document.getElementById('messages');
    //console.log('streaming chat has response');
    //console.log(response);
    var data = JSON.parse(response);
    for (var i=0;i<data.messages.length;i++) {
      p = document.createElement('p');
      p.className = 'line';
      span = document.createElement('span');
      span.innerHTML = data.messages[i].time;
      span.className = 'timestamp';
      p.appendChild(span);
      
      span = document.createElement('span');
      var user = data.messages[i].user.replace("\\'", "'");
      span.innerHTML = '&nbsp;' + user + '&nbsp;';
      span.className = 'user';
      p.appendChild(span);
      
      span = document.createElement('span');
      span.innerHTML = data.messages[i].msg;
      span.className = 'message';
      p.appendChild(span);
      
      messages.appendChild(p);
      messages.scrollTop = messages.scrollHeight;
    }
    http_last = http.responseText.length;
  }
}

function chatSendMsg() {
  var msg = document.getElementById('chatMsg').value;
    if (msg == '') {
         return;
  }
  http_send.open('GET', send_url + encodeURIComponent(msg), true);
  http_send.onreadystatechange = function() {
    if (http_send.readyState == 4) {
      if (http_send.status != 200) {
	alert('Something wrong in HTTP request, status code = ' + http_send.status);
      }
    }
  };
  http_send.send(null);
  document.getElementById('chatMsg').value = '';
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
	//document.getElementById('chatMsg').value = 'logout';
	//chatSendMsg();
      } else {
	alert('Something wrong in HTTP request, status code = ' + status);
      }
    }
  };
  http.send(null);
  http_last = 0;
}
