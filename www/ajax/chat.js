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
    var items = xmlobject.getElementsByTagName('div')[0].children;

    //console.debug("items: " + items.length);
    //if (items.length > 0) {console.log(content);}
    //if (items.length > 0) {console.log(items[0].innerHTML);}

    var doc = frames['ichat'].document;
    var messages = frames['ichat'].document.getElementsByTagName('div')[0];
    for (var i = 0 ; i < items.length ; i++) {
	var p   = doc.createElement('p'); // add class 'line'
	var att = doc.createAttribute("class");
	att.value = 'line';
	p.setAttributeNode(att);
	p.innerHTML = decodeURIComponent(items[i].innerHTML).replace(/\+/g,' ');
	messages.appendChild(p);
    }
    frames['ichat'].window.scrollTo(0,messages.offsetHeight);
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
