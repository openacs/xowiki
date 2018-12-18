<html>
<head>
<title>CKeditor</title>
<script type="text/javascript" src="/resources/xowiki/jquery/jquery.min.js"></script>
<script type="text/javascript"<if @::__csp_nonce@ not nil> nonce="@::__csp_nonce;literal@"</if>>

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
      <img id="@sub_files.img_id@" src="@sub_files.download_url@" height="60" width="100">
      <if @sub_files.image_p;literal@ true>
        <script type="text/javascript"<if @::__csp_nonce@ not nil> nonce="@::__csp_nonce;literal@"</if>>
          document.getElementById('@sub_files.img_id@').addEventListener('click', function (event) {
             changePreview("@sub_files.download_url@","@sub_files.name@", "@sub_files.mime_type@");
          });
        </script>
      </if>
    <!-- </a> -->
    </if>
<small><br>@sub_files.date@ </small><a href="@sub_files.delete_url@"><img src="/resources/acs-subsite/Delete16.gif" width="16" height="16" border="0" alt="delete" title="Delete" ></a>
</center>
</div>
<br/>
</multiple>
</body>
</html>
