// small cross browser function to get an HTTP object for making 
// AJAX style http requests in the background 
// -gustaf neumann Jan, 2006

function getHttpObject() {
     var http_request = false;
     if (window.XMLHttpRequest) { // Mozilla, Safari,...
         http_request = new XMLHttpRequest();
         if (http_request.overrideMimeType) {
              http_request.overrideMimeType('text/xml');
         }
     } else if (window.ActiveXObject) { // IE
         try {
             http_request = new ActiveXObject("Msxml2.XMLHTTP");
         } catch (e) {
             try {
                 http_request = new ActiveXObject("Microsoft.XMLHTTP");
             } catch (e) {}
         }
     }

     if (!http_request) {
         alert('Cannot create and instance of XMLHTTP');
     }
   return http_request;
}

if (typeof DOMParser == "undefined") {
   DOMParser = function () {}
	
   DOMParser.prototype.parseFromString = function (str, contentType) {
      if (typeof ActiveXObject != "undefined") {
         var d = new ActiveXObject("MSXML.DomDocument");
         d.loadXML(str);
         return d;
        }
   }
}

var http = getHttpObject();
