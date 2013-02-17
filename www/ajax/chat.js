// simple javascript support for polling ajax based chat interface
// $Id$
// -gustaf neumann   April 2006

var http = getHttpObject();

function chatReceiver() {
  if (http.readyState == 4) {
    // alert('status code =' + http.status);
    if (http.status == 200) {
      appendToMessages(http.responseText);
    } else {
      clearInterval();
      alert('Something wrong in HTTP request, status code = ' + http.status);
    }
  }
}

function appendToMessages(content) {
  var xmlobject = (new DOMParser()).parseFromString(content, 'application/xhtml+xml');
  var items = xmlobject.getElementsByTagName('TR');
  //alert('found ' + items.length + ' items');
  //var counter = document.getElementById('chatCounter');
  //counter.innerHTML = parseInt(counter.innerHTML) + 1;
  //document.getElementById('chatResponse').innerHTML = 'items = ' + items.length + ' l=' + content.length + ' ' + escape(content);

  //if (items.length > 0) {alert('appending ' + content);}
  var doc = frames['ichat'].document;
  var tbody = frames['ichat'].document.getElementById('messages').tBodies[0];
  //var tbody = tbodies[tbodies.length -1];
  //for (var i = 0 ; i < items.length ; i++) {
  //  tbody.appendChild(frames['ichat'].document.importNode(items[i],true));
  //}
  var tr, td, e, s;
  for (var i = 0 ; i < items.length ; i++) {
    tr = doc.createElement('tr');
    e = items[i].getElementsByTagName('TD');
    td = doc.createElement('td');
    td.innerHTML = decodeURIComponent(e[0].firstChild.nodeValue);
    td.className = 'timestamp';
    tr.appendChild(td);

    td = doc.createElement('td');
    s = e[1].firstChild.nodeValue;
    td.innerHTML = decodeURIComponent(e[1].firstChild.nodeValue.replace(/\+/g,' '));
    td.className = 'user';
    tr.appendChild(td);

    td = doc.createElement('td');
    td.innerHTML = decodeURIComponent(e[2].firstChild.nodeValue.replace(/\+/g,' '));
    td.className = 'message';
    tr.appendChild(td);

    tbody.appendChild(tr);
  }
  frames['ichat'].window.scrollTo(0,tbody.offsetHeight);
}


function chatSendMsg(send_url,handler) {
  var msgField = document.getElementById('chatMsg');
  chatSendCmd(send_url + encodeURIComponent(msgField.value),handler);
  msgField.value = '';
}

var msgcount = 0; // hack to overcome IE
function chatSendCmd(url,handler) {
  http.open('GET', url  + '&mc=' + msgcount++, true);
  http.onreadystatechange = handler;
  http.send(null);
}
