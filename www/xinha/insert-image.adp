<master src="/www/blank-master">
  <property name="doc(title)">#acs-templating.HTMLArea_InsertImageTitle#</property>
  
<script type="text/javascript" src="/resources/richtext-xinha/xinha-nightly/popups/popup.js"></script>
  
<script type="text/javascript" <if @::__csp_nonce@ not nil> nonce="@::__csp_nonce;literal@"</if>>
	var selector_window;
	window.resizeTo(400, 500);
	
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
	  document.getElementById("f_url").focus();
	};
	
	function onOK() {
	  var required = {
	    "f_url": "#acs-templating.HTMLArea_NoURL#",
	    "f_alt": "#acs-templating.HTMLArea_NoAltText#"
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
	  window.ipreview.location.replace(url);
	  return false;
	};
	
	function openImageSelector() {
	
		// open the image selector popup
		// make sure it is at least this size
		var w=640;
		var h=480;
		
		if (window.screen) {
		   w = parseInt(window.screen.availWidth * 0.50);
		   h = parseInt(window.screen.availHeight * 0.50);
		}
		
		(w < 640) ? w = 640 : w = w;
		(h < 480) ? h = 480 : h = h;
		var dimensions = "width="+w+",height="+h;
	  if (!document.all) {
	    selector_window = window.open("@file_selector_link;noquote@", "file_selector" , "toolbar=no,menubar=no,personalbar=no,scrollbars=yes,resizable=yes," + dimensions);
	  } else {
	    selector_window = window.open("@file_selector_link;noquote@", "file_selector", "channelmode=no,directories=no,location=no,menubar=no,resizable=yes,scrollbars=yes,toolbar=no," + dimensions);
	  }
// 	  alert("HIER");
	  selector_window.moveTo(w/2,h/2);
		selector_window.focus();
// 	  return false;
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

<div class="title">#acs-templating.HTMLArea_InsertImageTitle#</div>

<form action="" method="get" name="imageprops">
<input type="hidden" name="f_name" id="f_name" />
<div style="text-align: center;">
	<table border="0" width="100%" style="margin: 0 auto; text-align: left;padding: 0px;">
	  <tbody>
	  <tr>
	    <td width="1%" style="text-align: right" nowrap>#acs-templating.HTMLArea_ImageURL#</td>
	    <td width="99%"><input type="text" name="url" id="f_url" style="width:75%" title="#acs-templating.HTMLArea_ImageURLToolTip#" />
	    <button id="preview_button" name="preview" title="Preview the image in a new window">Preview</button>
	    </td>
	  </tr>
	  <tr>
	    <td width="1%" style="text-align: right" nowrap>#acs-templating.HTMLArea_ImageAlternateText#</td>
	    <td width="99%"><input type="text" name="alt" id="f_alt" style="width:100%" title="#acs-templating.HTMLArea_ImageAlternateTextToolTip#" /></td>
	  </tr>
	  <tr> 
	    <td  colspan="2" style="text-align: right; padding:3px;">
	    	<if @fs_found@ eq 1>
	    		<button id="image_selector_button" type="button">#acs-templating.HTMLArea_OpenFileStorage#</button>
	    	</if>
	    	<else>
	    		<span style="margin-top:2px; margin-bottom:2px; border:2px outset #FFFFFF;padding-top:1px;padding-bottom:1px;padding-right:6px;padding-left:6px;color:GrayText;cursor:default;" title="#acs-templating.HTMLArea_FileStorageNotFoundToolTip#">#acs-templating.HTMLArea_OpenFileStorage#</span> 
	    	</else></td>
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
	</table>

<table width="100%" style="margin-bottom: 0.2em">
 <tr>
  <td valign="bottom">
    Image Preview:<br />
    <iframe name="ipreview" id="ipreview" frameborder="0" style="border : 1px solid gray;" height="200" width="300" src="./blank.html"></iframe>
  </td>
  <td valign="bottom" style="text-align: right">
    <button id="ok_button" type="button" name="ok">OK</button><br/>
    <button id="cancel_button" type="button" name="cancel">#acs-templating.HTMLArea_action_cancel#</button>
  </td>
 </tr>
</table>
</form>
