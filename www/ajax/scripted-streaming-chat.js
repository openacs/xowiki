// simple javascript support for streaming ajax based chat interface
// $Id$
// -gustaf neumann   April 2006

var http_send = getHttpObject();

function getData(data) {
  var messages = document.getElementById('messages');
  for (var i=0;i<data.messages.length;i++) {
    p = document.createElement('p');
    p.className = 'line';
    span = document.createElement('span');
    span.innerHTML = data.messages[i].time;
    span.className = 'timestamp';
    p.appendChild(span);
      
    span = document.createElement('span');
    span.innerHTML = '&nbsp;' + data.messages[i].user + '&nbsp;';
    span.className = 'user';
    p.appendChild(span);
      
    span = document.createElement('span');
    span.innerHTML = data.messages[i].msg;
    span.className = 'message';
    p.appendChild(span);
    
    messages.appendChild(p);
    messages.scrollTop = messages.scrollHeight;
  }
}

function chatSendMsg() {
  var msg = document.getElementById('chatMsg').value;
  if (msg == '') { return; }
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
