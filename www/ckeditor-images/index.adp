<html>
<head>

<script type="text/javascript">
//var selector_window;
function Init() {
    window.outerWidth = '720px';
    window.outerHeight = '850px';
    window.resizeTo(720,850);
    if (window.scrollbars) {
	window.scrollbars.visible = true;
    }

    var param = window.dialogArguments;
    if (param) {
	document.getElementById("f_url").value = param["f_url"];
	document.getElementById("f_alt").value = param["f_alt"];
	window.preview.location.replace(param.f_url);
    }
    document.getElementById("f_url").focus();
};

function setLink () {
    var f_url = document.getElementById("f_url");
    var url = f_url.value
    window.opener.CKEDITOR.tools.callFunction("@CKEditorFuncNum;noquote@", url);
    window.close();
}
</script>

<style type="text/css">
.xowiki_image_body {
    background: ButtonFace;
    color: ButtonText;
    font: 11px Tahoma,Verdana,sans-serif;
    margin: 0px;
    padding: 5px;
}

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
	
.title { 
    background: #ddf; color: #000; font-weight: bold; font-size: 120%; padding: 3px 10px; margin-bottom: 10px;
    border-bottom: 1px solid black; letter-spacing: 2px;
}
form { padding: 0px; margin: 0px; }
</style>
</head>
<body onload="Init();" style="background-color: #e2e2e2;overflow: scroll;" class="xowiki_image_body">


<b>#xowiki.attached_images#:</b>
<center>
<table><tr><td>
<div style="border: none;"><fieldset style="border: none; padding: 4px;">
<div style="float:left; border: none;">
<iframe name="thumbs" src ="@image_browser_url@/thumb-view?parent_id=@item_id@" frameborder=1 width="150px" height="400px"  scrolling="auto">
</iframe>
</div>
</fieldset>
</td><td><fieldset style="border: none; padding: 4px;">
<iframe name="preview" id="preview" src="@image_browser_url@/resources/blank.gif" frameborder=1 width="500px" height="400px"  ></iframe>
</fieldset>
</div>
</td></tr></table>
</center>


<iframe name="upload" src="@image_browser_url@/upload_image?parent_id=@parent_id@" frameborder=0 width="680px" height="110px"  ></iframe>

<hr>
<div style="clear:both;">
<form action="" method="get" name="form" id="insert_form">
<table width="100%">
<tr style="display:none">
 	<td width="100px" style="text-align: right" nowrap>URL: </td>
	<td >
		<input type="text" value="@bild_url@" onChange="ChangeImageSrc();" name="url" id="f_url" style="width:75%" title="#acs-templating.HTMLArea_ImageURLToolTip#" />
	    	
		<input type="hidden" id="f_id" value=""/>
	    	
	</td>
<tr style="display:none">
<td align="right">Alternativtext:</td>
	<td>
	<input type="text"" name="alt" id="f_alt" style="width:300px" title="#acs-templating.HTMLArea_ImageURLToolTip#" />
	</td>
	<td></td>
</tr>
<tr>
<td><input type="submit" name="ok" value="#xowiki.insert_image#"/></td>
<td><button type="button" name="cancel" onclick="xowiki_image_dialog.dialog('close');" >#xowiki.cancel#</button></td>
</form>
</table>
</div>

</body>
</html>