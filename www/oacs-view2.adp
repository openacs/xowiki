<!-- Generated by ::xowiki::ADP_Generator on Sun Mar 18 01:20:19 CET 2007 -->
<master>
  <property name="title">@title;noquote@</property>
  <property name="context">@context;noquote@</property>
  <property name="header_stuff">@header_stuff;noquote@
      <link rel='stylesheet' href='/resources/xowiki/cattree.css' media='all' />
      <link rel='stylesheet' href='/resources/calendar/calendar.css' media='all' />
      <script language='javascript' src='/resources/acs-templating/mktree.js' type='text/javascript'></script>
    
  <link rel="stylesheet" type="text/css" href="/resources/xowiki/xowiki.css" media="all" />
  <script type="text/javascript">
function get_popular_tags(popular_tags_link, prefix) {
  var http = getHttpObject();
  http.open('GET', popular_tags_link, true);
  http.onreadystatechange = function() {
    if (http.readyState == 4) {
      if (http.status != 200) {
	alert('Something wrong in HTTP request, status code = ' + http.status);
      } else {
       var e = document.getElementById(prefix + '-popular_tags');
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
<div class='xowiki-content'>
<div id='wikicmds'>
  <if @edit_link@ not nil><a href="@edit_link@" accesskey='e' title='Diese Seite bearbeiten ...'>#xowiki.edit#</a> &middot; </if>
  <if @rev_link@ not nil><a href="@rev_link@" accesskey='r' >#xotcl-core.revisions#</a> &middot; </if>
  <if @new_link@ not nil><a href="@new_link@" accesskey='n'>#xowiki.new#</a> &middot; </if>
  <if @delete_link@ not nil><a href="@delete_link@" accesskey='d'>#xowiki.delete#</a> &middot; </if>
  <if @admin_link@ not nil><a href="@admin_link@" accesskey='a'>#xowiki.admin#</a> &middot; </if>
  <if @notification_subscribe_link@ not nil><a href='/notifications/manage'>#xowiki.notifications#</a> 
    <a href="@notification_subscribe_link@">@notification_image;noquote@</a> &middot; </if>
  <a href='#' onclick='document.getElementById("do_search").style.display="inline";document.getElementById("do_search_q").focus(); return false;'>#xowiki.search#</a> &middot;
  <if @index_link@ not nil><a href="@index_link@" accesskey='i'>#xowiki.index#</a></if>
<span id='do_search' style='display: none'> 
  <FORM action='/search/search'><INPUT  id='do_search_q' name='q' type='text'><INPUT type="hidden" name="search_package_id" value="@package_id@" /></FORM> 
</span>
</div>
<div style="float:left; width: 25%; font-size: 85%;
     background: url(/resources/xowiki/bw-shadow.png) no-repeat bottom right;
     margin-left: 2px; margin-top: 2px; padding: 0px 6px 6px 0px;			    
">
<div style="margin-top: -2px; margin-left: -2px; border: 1px solid #a9a9a9; padding: 5px 5px; background: #f8f8f8">
<include src="/packages/xowiki/www/portlets/include" 
	 &__including_page=page 
	 portlet="categories -open_page @name@  -decoration plain">
</div></div>
<div style="float:right; width: 70%;">
<style type='text/css'>
table.mini-calendar {width: 200px ! important;}
#sidebar {min-width: 220px ! important; top: 0px; overflow: visible;}
</style>
<div style='float: left; width: 62%'>
@top_portlets;noquote@
@content;noquote@
</div>  <!-- float left -->
<div id='sidebar' class='column'>
<div style="background: url(/resources/xowiki/bw-shadow.png) no-repeat bottom right;
     margin-left: 2px; margin-top: 2px; padding: 0px 6px 6px 0px;			    
">
<div style="margin-top: -2px; margin-left: -2px; border: 1px solid #a9a9a9; padding: 5px 5px; background: #f8f8f8">
<include src="/packages/xowiki/www/portlets/weblog-mini-calendar" 
	 &__including_page=page 
         summary="0" noparens="1">
<include src="/packages/xowiki/www/portlets/include" 
	 &__including_page=page 
	 portlet="tags -decoration plain">
<include src="/packages/xowiki/www/portlets/include" 
	 &__including_page=page 
	 portlet="tags -popular 1 -limit 30 -decoration plain">
<hr>
<include src="/packages/xowiki/www/portlets/include" 
	 &__including_page=page 
	 portlet="presence -interval {30 minutes} -decoration plain">
<hr>
<a href="contributors" text="Show People contributing to this XoWiki Instance">Contributors</a>
</div>
</div>
</div> <!-- sidebar -->

</div> <!-- right 70% -->

@footer;noquote@
</div> <!-- class='xowiki-content' -->
