<html>
<head>
<title>CKeditor: Upload Image</title>
<style type="text/css">
	html, body {
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
<script type="text/javascript"<if @::__csp_nonce@ not nil> nonce="@::__csp_nonce;literal@"</if>>
@js_update;noquote@
</script>
</head>
<body>

<div id="image_properties">
<formtemplate id="upload_form">
<table>
<tr>
<td colspan="3">
#xowiki.choose_file#: <formwidget id="upload_file">
<script <if @::__csp_nonce@ not nil> nonce="@::__csp_nonce;literal@"</if>>
  document.getElementById('upload_file').addEventListener('change', function (event) {
     document.getElementById('subm_upld').removeAttribute('disabled');
  });
</script>
</td>
</tr>
<tr>
<td><input id='subm_upld' disabled='disabled' type='submit' name='save' value="#xowiki.upload_file#" />
</td>
</tr>
<tr>
<td colspan="3">
<!-- #xowiki.image_width_hint# -->
</td>
</tr>
</table>
</formtemplate>
</div>


</body>
</html>
