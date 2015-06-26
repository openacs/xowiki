<html>
<head>
<script type="text/javascript" src="/resources/xowiki/jquery/jquery.min.js"></script>
<script type="text/javascript">

function changePreview(url,name,mime) {
  $("#preview", parent.document).append(function() {
        switch(mime) {
            case 'image/png':
                window.parent.loadImage(url);
                break;
            case 'image/jpeg':
                window.parent.loadImage(url);
                break;
            case 'image/gif':
                window.parent.loadImage(url);
                break;
        }
  });
  parent.document.getElementById('f_url').value = name;
  parent.document.getElementById('f_mime').value = mime ;
}
</script>
</head>
<body>
<multiple name="sub_files">
<div style="border: 1px solid black;background-color: #cfcfcf;padding-top: 5px;">
    <center>
    <!-- <a href="preview?revision=@sub_files.revision_id@" target="preview"> -->
    @sub_files.title@
    @sub_files.mime_type@
    <if @sub_files.mime_type@ in "image/jpeg" "image/png" "image/gif">
        <img src="@sub_files.url@?m=download" height="60" width="100" onClick="changePreview('@sub_files.url@?m=download','@sub_files.name@', '@sub_files.mime_type@')"></a>
    </if>
<small><br>@sub_files.date@ </small><a href="@sub_files.url@?m=delete&amp;return_url=@return_url@"><img src="/resources/acs-subsite/Delete16.gif" width="16" height="16" border="0" alt="delete" title="Delete" ></a>
</center>
</div>
<br/>
</multiple>
</body>
</html>
