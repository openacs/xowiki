<div>
<!--
<fieldset class='box'>
<legend  style='position: inherit ! important; margin: auto ! important; display: block! important; text-align: right ! important;' id='wikicmds'>
-->
<div style='top: -00px ! important; margin-bottom: 25px ! important;' id='wikicmds'>
  <if @edit_link@ not nil><a href="@edit_link@" accesskey='e' title='Diese Seite bearbeiten ...'>#xowiki.edit#</a> &middot; </if>
  <if @rev_link@ not nil><a href="@rev_link@" accesskey='r' >#xotcl-core.revisions#</a> &middot; </if>
  <if @new_link@ not nil><a href="@new_link@" accesskey='n'>#xowiki.new_page#</a> &middot; </if>
  <if @delete_link@ not nil><a href="@delete_link@" accesskey='d'>#xowiki.delete#</a> &middot; </if>
  <if @admin_link@ not nil><a href="@admin_link@" accesskey='a'>#xowiki.admin#</a> &middot; </if>
  <if @notification_subscribe_link@ not nil><a href='/notifications/manage'>#xowiki.notifications#</a> 
    <a href="@notification_subscribe_link@">@notification_image;noquote@</a> &middot; </if>
  <a href='#' onclick='document.getElementById("do_search").style.display="inline";document.getElementById("do_search_q").focus(); return false;'>#xowiki.search#</a> &middot;
  <if @index_link@ not nil><a href="@index_link@" accesskey='i'>#xowiki.index#</a></if>
<div id='do_search' style='display: none'> 
  <FORM action='/search/search'><div><INPUT  id='do_search_q' name='q' type='text'><INPUT type="hidden" name="search_package_id" value="@package_id@" ></div></FORM> 
</div>
</div> <!-- </legend> -->
@top_includelets;noquote@
<if @page_title@ not nil>
<h2>@page_title@</h2>
</if>
@content;noquote@
</div>
