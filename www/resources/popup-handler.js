var ol_close = "X";
var ol_closeclick = 1; 
//var ol_fgclass="overlibFg";
//var ol_bgclass="overlibBg";
var ol_textfontclass="overlibFont";
var ol_captionfontclass="overlibCapfont";
var ol_closefontclass="overlibClosefont";

var PopupHandler = {
 popupTitle  	: "Definition",
 popupWidth	: 250,
 init		: function (url, title, width) {
    if (title) {this.title = title;} else {this.title = this.popupTitle;};
    if (width) {this.width = width;} else {this.width = this.popupWidth;};
    http.open('GET', url, true);
    http.onreadystatechange = function() {
      if (http.readyState == 4) {
	if (http.status != 200) {
	  alert('Something wrong in HTTP request, status code = ' + http.status);
	}
	overlib(http.responseText, STICKY, CAPTION, 
		PopupHandler.title, WIDTH, PopupHandler.width, 
		FGCOLOR, '#FFFFFF', CAPCOLOR, '#000000', BGCOLOR, '#CCBBBB' );
      }
    };
    http.send(null);
  }
};

function showInfo(url,title, w) {
  PopupHandler.init(url,title, w);
  return false; 
}
