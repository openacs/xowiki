function receiver1() {
  if (http.readyState == 4) {
    // alert('status code =' + http.status);
    if (http.status != 200) {
      alert('Something wrong in HTTP request, status code = ' + http.status);
    }
  }
}

function chatReceiver() {
  if (http.readyState == 4) {
    // alert('status code =' + http.status);
    if (http.status == 200) {
      appendToMessages(http.responseText);
    } else {
      alert('Something wrong in HTTP request, status code = ' + http.status);
    }
  }
}

function appendToMessages(content) {
  var xmlobject = (new DOMParser()).parseFromString(content, 'application/xhtml+xml');
  //var xmlobject = (new DOMParser()).parseFromString(content, 'text/html');
  var items = xmlobject.getElementsByTagName('TR');
  //alert('found ' + items.length + ' items');
  var counter = document.getElementById('chatCounter');
  counter.innerHTML = parseInt(counter.innerHTML) + 1;
  //document.getElementById('chatResponse').innerHTML = content;

  //if (items.length > 0) {alert('appending ' + content);}
  var tbody = frames['ichat'].document.getElementById('messages').tBodies[0];
  //for (var i = 0 ; i < items.length ; i++) {
  //  tbody.appendChild(frames['ichat'].document.importNode(items[i],true));
  //}
  var tr, td, e, s;
  for (var i = 0 ; i < items.length ; i++) {
    tr = document.createElement('tr');
    e = items[i].getElementsByTagName('TD');
    td = document.createElement('td');
    td.innerHTML = unescape(e[0].firstChild.nodeValue);
    td.className = 'timestamp';
    tr.appendChild(td);

    td = document.createElement('td');
    s = e[1].firstChild.nodeValue;
    td.innerHTML = unescape(e[1].firstChild.nodeValue.replace(/\+/g,' '));
    //td.appendChild(document.createTextNode(e[1].firstChild.nodeValue));
    td.className = 'user';
    tr.appendChild(td);

    td = document.createElement('td');
    td.innerHTML = unescape(e[2].firstChild.nodeValue.replace(/\+/g,' '));
    //td.appendChild(document.createTextNode(e[2].firstChild.nodeValue));
    td.className = 'message';
    tr.appendChild(td);

    //tbody.appendChild(items[i]);
    //tbody.appendChild(items[i].cloneNode(true));
    tbody.appendChild(tr);

  }
  frames['ichat'].window.scrollTo(0,tbody.offsetHeight);
}

function chatSendMsg(send_url,handler) {
  var msgField = document.getElementById('chatMsg');
  chatSendCmd(send_url + escape(msgField.value),handler);
  msgField.value = '';
}
function chatSendCmd(url,handler) {
  http.open('GET', url, true);
  http.onreadystatechange = handler;
  http.send(null);
}
