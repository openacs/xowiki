<master>
  <property name="title">@title;noquote@</property>
  <property name="context">@context;noquote@</property>
  <property name="header_stuff">@header_stuff;noquote@
  <link rel="stylesheet" type="text/css" href="/resources/xowiki/xowiki.css" media="all" />
<script type="text/javascript">
function get_popular_tags() {
  var http = getHttpObject();
  http.open('GET', '@popular_tags_link@', true);
  http.onreadystatechange = function() {
    if (http.readyState == 4) {
      if (http.status != 200) {
	alert('Something wrong in HTTP request, status code = ' + http.status);
      } else {
       var e = document.getElementById('popular_tags');
       e.innerHTML = http.responseText;
       e.style.display = 'block';
      }
    }
  };
  http.send(null);
}
</script>
</property>
  
  <!-- The following DIV is needed for overlib to function! -->
  <div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>	

<div id='wikicmds'>
  <if @edit_link@ not nil><a href='@edit_link@' accesskey='e' title='Diese Seite bearbeiten ...'>#xowiki.edit#</a> &middot; </if>
  <if @rev_link@ not nil><a href="@rev_link@" accesskey='r' >#xotcl-core.revisions#</a> &middot;</if>
  <if @new_link@ not nil><a href="@new_link@" accesskey='n'>#xowiki.new#</a> &middot;</if>
  <if @delete_link@ not nil><a href="@delete_link@" accesskey='d'>#xowiki.delete#</a> &middot;</if>
  <if @notification_link@ not nil><a href="@notification_link@">#xowiki.notifications#</a> &middot;</if>
  <if @admin_link@ not nil><a href="@admin_link@" accesskey='a'>#xowiki.admin#</a> &middot;</if>
  <a href='#' onclick='document.getElementById("do_search").style.display="inline";document.getElementById("do_search_q").focus(); return false;'>#xowiki.search#</a> &middot;
  <if @index_link@ not nil><a href="@index_link@" accesskey='i'>#xowiki.index#</a></if>
<span id='do_search' style='display: none'> 
  <FORM action='/search/search'><INPUT  id='do_search_q' name='q' type='text'><INPUT type="hidden" name="search_package_id" value="@package_id@" /></FORM> 
</span>
</div>

@content;noquote@
<div style="clear: both; text-align: left; font-size: 85%;">
<if @references@ ne "" or @lang_links@ ne "">
<p/>&nbsp;<hr>#xowiki.references_label# @references;noquote@ @lang_links;noquote@
</if>
<br>
<if @no_tags@ eq 0>
#xowiki.your_tags_label#: @tags_with_links;noquote@
(<a href='#' onclick='document.getElementById("edit_tags").style.display="inline";return false;'>#xowiki.edit_link#</a>, 
<a href='#' onclick='get_popular_tags();return false;'>#xowiki.popular_tags_link#</a>)
<span id='edit_tags' style='display: none'>
<FORM action='@save_tag_link@' method='POST'><INPUT name='tags' type='text' value='@tags@'></FORM>
</span>
<span id='popular_tags' style='display: none'></span>
</if>
</div><br>
<if @gc_comments@ not nil>
   <p>#general-comments.Comments#
   <ul>@gc_comments;noquote@</ul></p>
</if>
<if @gc_link@ not nil>
   <p>@gc_link;noquote@</p>
</if>
