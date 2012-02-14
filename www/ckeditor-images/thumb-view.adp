<html>
<head>
<script src='/resources/xowiki/jquery/jquery.js' type='text/javascript'></script>
<script type="text/javascript">
function changePreview(url,name) {
  $("#preview", top.document).attr('src',url);
  parent.document.getElementById('f_url').value = name ;
}
</script>
</head>
<body>
<multiple name="sub_files">
<div style="border: 1px solid black;background-color: #cfcfcf;padding-top: 5px;">
	<center>
	<!-- <a href="preview?revision=@sub_files.revision_id@" target="preview"> -->

	<img src="@sub_files.url@?m=download" height="60" width="100" onClick="changePreview('@sub_files.url@?m=download','@sub_files.name@')"></a>
	
<small><br>@sub_files.date@ </small><a href="@sub_files.url@?m=delete&return_url=@return_url;noquote@"><img src="/resources/acs-subsite/Delete16.gif" width="16" height="16" border="0" alt="Löschen" title="Löschen" ></a> 
</center>
</div>
<br/>
</multiple>
</body>
</html>