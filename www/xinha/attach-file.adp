<master src="/www/blank-master">
  <property name="doc(title)">#acs-templating.HTMLArea_InsertImageTitle#</property>

<script type="text/javascript" src="/resources/richtext-xinha/xinha-nightly/popups/popup.js"></script>

<script type="text/javascript" <if @::__csp_nonce@ not nil> nonce="@::__csp_nonce;literal@"</if>>  
	var selector_window;
	window.resizeTo(415, 300);

	function Init() {
	  __dlg_init();
	  var param = window.dialogArguments;
	  if (param) {
	      document.getElementById("f_url").value = param["f_url"];
	      document.getElementById("f_alt").value = param["f_alt"];
	      document.getElementById("f_border").value = param["f_border"];
	      document.getElementById("f_align").value = param["f_align"];
	      document.getElementById("f_vert").value = param["f_vert"];
	      document.getElementById("f_horiz").value = param["f_horiz"];
	      window.ipreview.location.replace(param.f_url);
	  }
	  // document.getElementById("f_url").focus();
	  var f_url = document.getElementById("f_url");
	  var url = f_url.value;
	  if (url) {
             	// window.ipreview.location.replace(url);
      		onOK();
	      	__dlg_close(null);
	  }
	};
	
	function onOK() {
	  var required = {
	    "f_url": "#acs-templating.HTMLArea_NoURL#"
	  };
	  for (var i in required) {
	    var el = document.getElementById(i);
	    if (!el.value) {
	      alert(required[i]);
	      el.focus();
	      return false;
	    }
	  }
	  // pass data back to the calling window
	  var fields = ["f_url", "f_alt", "f_align", "f_border",
	                "f_horiz", "f_vert", "f_name"];
	  var param = new Object();
	  for (var i in fields) {
	    var id = fields[i];
	    var el = document.getElementById(id);
	    param[id] = el.value;
	  }
	  if (selector_window) {
	    selector_window.close();
	  }
	  __dlg_close(param);
	  return false;
	};
	
	function onCancel() {
	  if (selector_window) {
	    selector_window.close();
	  }
	  __dlg_close(null);
	  return false;
	};

	function onPreview() {
	  var f_url = document.getElementById("f_url");
	  var url = f_url.value;
	  if (!url) {
	    alert("You have to enter a URL first");
	    f_url.focus();
	    return false;
	  }
	  if (document.getElementById('preview_div').style.display == 'none') { 
		document.getElementById('showpreview').click();
	  }
	  document.getElementById('ipreview').src = url;
	  return false;
	};

	function resizeWindow(formname) {
 		var w, h;
	        var urlTag    = document.getElementById('insert_image_url');
                var uploadTag = document.getElementById('insert_image_upload');
		if (formname == "url") {
			w = 415;
			h = 330;
			urlTag.style.display='';
			uploadTag.style.display='none';
		}
		if (formname == "upload") {
			w = 415;
			h = 310;
			urlTag.style.display='none';
	                uploadTag.style.display='';
		}
		if (document.getElementById('showpreview').checked == true) {
			h = h + 200;
		}
	        window.resizeTo(w, h);
	}

	function togglePreview() {
		var w = window.clientWidth;
		var h = window.clientHeight;
		if (document.getElementById('insert_image_url').style.display == 'none') { 
			resizeWindow('upload');
		} else { 
			resizeWindow('url');
		}		
		var displayPreview = document.getElementById('preview_div');
		if (displayPreview.style.display == 'none') { 
			displayPreview.style.display='';
		} else { 
			displayPreview.style.display='none';
		}
	}
	
</script>

<style type="text/css">
	html, body {
	  background: ButtonFace;
	  color: ButtonText;
	  font: 11px Tahoma,Verdana,sans-serif;
	  margin: 0px;
	  padding: 0px;
	}
	body { padding: 5px; }
	table {
	  font: 11px Tahoma,Verdana,sans-serif;
	}
	form p {
	  margin-top: 5px;
	  margin-bottom: 5px;
	}
	.fl { width: 9em; float: left; padding: 2px 5px; text-align: right; }
	.fr { width: 6em; float: left; padding: 2px 5px; text-align: right; }
	fieldset { padding: 0px 10px 5px 5px; }
	select, input, button { font: 11px Tahoma,Verdana,sans-serif; }
	.space { padding: 2px; }
	
	.title { background: #ddf; color: #000; font-weight: bold; font-size: 120%; padding: 3px 10px; margin-bottom: 10px;
	border-bottom: 1px solid black; letter-spacing: 2px;
	}
	form { padding: 0px; margin: 0px; }
</style>

</head>

<body id="body">

<div class="title">#acs-templating.HTMLArea_InsertImageTitle# URL <span id="insert_image_link"><a id="resize_window_url_button" href="#"><font size="-3">click here</font></a></span></div>
<div id="insert_image_url" style="display:none;">
  <div style="text-align: center;">
    <form action="" method="get" name="imageprops">
      <input type="hidden" name="f_name" id="f_name" />
      <table border="0" width="100%" style="margin: 0 auto; text-align: left;padding: 0px;">
	<tbody>
	  <tr>
	    <td width="1%" style="text-align: right" nowrap>#acs-templating.HTMLArea_ImageURL#</td>
	    <td width="99%">
	      <input type="text" name="url" id="f_url" style="width:75%"
		     title="#acs-templating.HTMLArea_ImageURLToolTip#" value="@f_url@" />
	      <button id="preview_button" name="preview" title="Preview the image in a new window">Preview</button>
	    </td>
	  </tr>
	  <tr>
	    <td width="1%" style="text-align: right" nowrap>#acs-templating.HTMLArea_ImageAlternateText#</td>
	    <td width="99%">
	      <input type="text" name="alt" id="f_alt" style="width:100%" title="#acs-templating.HTMLArea_ImageAlternateTextToolTip#" />
	    </td>
	  </tr>
	</tbody>
      </table>
  </div>
  <p />
  <table style="margin-left: auto;margin-right: auto;" >
    <tr>
      <td valign="top">
	<fieldset style="margin-left: 5px;">
	  <legend>Layout</legend>
	  
	  <table>
	    <tr>
	      <td>#acs-templating.HTMLArea_ImageAlignment#</td>
	      <td>
		<select size="1" name="align" id="f_align">
		  <option value="left"                         >#acs-templating.HTMLArea_ImageAlignmentLeft#</option>
		  <option value="right"                        >#acs-templating.HTMLArea_ImageAlignmentRight#</option>
		  <option value="bottom" selected="1"          >#acs-templating.HTMLArea_ImageAlignmentBottom#</option>
		  <option value="middle"                       >#acs-templating.HTMLArea_ImageAlignmentMiddle#</option>
		  <option value="top"                          >#acs-templating.HTMLArea_ImageAlignmentTop#</option>
		</select>
	      </td>
	    </tr>
	    <tr>
	      <td>#acs-templating.HTMLArea_ImageBorderSize#</td>
	      <td><input type="text" name="border" id="f_border" size="5" title="#acs-templating.HTMLArea_ImageBorderSizeToolTip#" /></td>
	    </tr>
	  </table>
	</fieldset>
      </td>
      <td valign="top">
	<fieldset style="margin-right: 5px;">
	  <legend>#acs-templating.HTMLArea_ImageSpacing#</legend>
	  
	  <table border="0">
	    <tr>
	      <td>#acs-templating.HTMLArea_ImageSpacingHorizontal#</td>
	      <td><input type="text" name="horiz" id="f_horiz" size="5" title="#acs-templating.HTMLArea_ImageSpacingHorizontalToolTip#" /></td>
	    </tr>
	    <tr>
	      <td>#acs-templating.HTMLArea_ImageSpacingVertical#</td>
	      <td><input type="text" name="vert" id="f_vert" size="5" title="#acs-templating.HTMLArea_ImageSpacingVerticalToolTip#" /></td>
	    </tr>					
	  </table>
	</fieldset>
      </td>
    </tr>
  </form>
  </table>
  <input type="checkbox" name="showpreview" id="showpreview"> Show Preview
  <div id="preview_div" style="display:none">
    <fieldset style="margin-top:10px;padding-top:10px;">
      <legend><strong>@HTML_Preview@</strong></legend>
      <iframe name="ipreview" id="ipreview" frameborder="0" style="width:95%;" height="150"  src="./blank.html"></iframe>
    </fieldset>
  </div>
  <br /><br />
  <button id="ok_button" type="button" name="ok">OK</button>&nbsp;<button class="cancel_buttons" type="button" name="cancel">#acs-templating.HTMLArea_action_cancel#</button>
  <br /><br />
</div>

<div class="title">#acs-templating.HTMLArea_InsertImageTitle# Upload <span id="uplaod_image_link"><a id="resize_window_upload_button" href="#"><font size="-3">click here</font></a></span></div>
<div id="insert_image_upload">
	<table border="0" width="100%" style="margin: 0 auto; text-align: left;padding: 0px;">
	  <tbody>
      <td valign="top" width="50%" >
	<if @write_p;literal@ true>
	  <fieldset style="margin-top:10px;padding-top:10px;">
	    <legend><strong>@HTML_UploadTitle@</strong></legend>
	    <formtemplate id="upload_form">
	      <table cellspacing="2" cellpadding="2" border="0" width="55%">
		<tr class="form-element">
		  <if @formerror.upload_file@ not nil>
		    <td class="form-widget-error">
		  </if>
		  <else>
		    <td class="form-widget">
		  </else>
		  <formwidget id="upload_file">
		    <formerror id="upload_file">
		      <div class="form-error">@formerror.upload_file@</div>
		    </formerror><br />
                        #acs-templating.This_image_can_be_reused_by#<br />
                        <formgroup id="share">
                          @formgroup.widget;noquote@ @formgroup.label@
		    <br /></formgroup>
                  <img src="/shared/images/info.gif" width="12" height="9" alt="[i]" title="Help text" border="0">
                  #acs-templating.This_image_can_be_reused_help#
		    <formerror id="share">
		      <div class="form-error">@formerror.share@</div>
		    </formerror>                        
      </td>
    </tr>
    <tr class="form-element">
      <td class="form-widget" colspan="2" align="center">
	<formwidget id="ok_btn">&nbsp;<button class="cancel_buttons" type="button" name="cancel">#acs-templating.HTMLArea_action_cancel#</button>        
      </td>
    </tr>
    </table>
    </formtemplate>
    </fieldset>
    </if>
	</td>
	</tr>
	<tr>
	<td>
	</td>
	</tr>
	  </tbody>
	</table>
</div>
