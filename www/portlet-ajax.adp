<div class="portlet-title">
<span>@title@</span>
</div>
<script type="text/javascript"<if @::__csp_nonce@ not nil> nonce="@::__csp_nonce;literal@"</if>>
function get() {
  var http = getHttpObject();
  http.open('GET', '@portlet@', true);
  http.onreadystatechange = function() {
    if (http.readyState == 4) {
      if (http.status != 200) {
	alert('Something wrong in HTTP request, status code = ' + http.status);
      } else {
       var div = document.getElementById('@ID@');
       div.innerHTML = http.responseText;
      }     
    }
  };
  http.send(null);
}
get();
</script>
<div class="portlet" id="@ID@">
... loading ....
</div>
