<master>
  <property name="title">@title;noquote@</property>
  <property name="context">@context;noquote@</property>
  <property name="header_stuff">@header_stuff;noquote@
<link rel='stylesheet' href='/resources/xowiki/cattree.css' media='all'/>
<script language='javascript' src='/resources/acs-templating/mktree.js' type='text/javascript'></script>
<link rel="stylesheet" type="text/css" href="/resources/xowiki/xowiki.css" media="all" />
<script type="text/javascript">
function get_popular_tags() {
  var http = getHttpObject();
  http.open('GET', "@popular_tags_link@", true);
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

<div class='xowiki-content'>
<div style="float:left; width: 25%; font-size: .8em;
     background: url(/resources/xowiki/bw-shadow.png) no-repeat bottom right;
     margin-left: 2px; margin-top: 2px; padding: 0px 6px 6px 0px;			    
">
<div style="margin-top: -2px; margin-left: -2px; border: 1px solid #a9a9a9; padding: 5px 5px; background: #f8f8f8">
@toc;noquote@
</div></div>
<div style="float:right; width: 70%;">@top_portlets;noquote@

<if @book_prev_link@ not nil or @book_relpos@ not nil or @book_next_link@ not nil>
<div class="book-navigation" style="background: #f8f8f8; border: 1px solid #a9a9a9;  width: 500px;">
<table width='100%'>
   <tr>
   <td width='20'>
   <if @book_prev_link@ not nil>
        <a href="@book_prev_link@" accesskey='p' ID="bookNavPrev.a" onclick='return TocTree.getPage("@book_prev_link@");'>
        <img border='0' alt='Previous' src='/resources/xowiki/previous.png' width='15px' ID="bookNavPrev.img"></a>
    </if>
    <else>
        <a href="" accesskey='p' ID="bookNavPrev.a" onclick="">
        <img border='0' alt='No Previous' src='/resources/xowiki/previous-end.png' width='15px' ID="bookNavPrev.img"></a>
    </else>
     </td>

   <td>
   <if @book_relpos@ not nil>
     <table style='display: inline; text-align: center;'>
     <tr><td width='450px' style='font-size: 75%'><div style='width: @book_relpos@;' ID='bookNavBar'></div><span ID='bookNavRelPosText'>@book_relpos@</span></td></tr>
     </table>
   </if>
   </td>

   <td width='20' ID="bookNavNext">
   <if @book_next_link@ not nil>
        <a href="@book_next_link@" accesskey='n' ID="bookNavNext.a" onclick='return TocTree.getPage("@book_next_link@");'>
        <img border='0' alt='Next' src='/resources/xowiki/next.png' width='15px' ID="bookNavNext.img"></a>
   </if>
    <else>
        <a href="" accesskey='n' ID="bookNavNext.a" onclick="">
       <img border='0' alt='No Next' src='/resources/xowiki/next-end.png' width='15px' ID="bookNavNext.img"></a>
    </else>
   </td>
   </tr>
</table>
</div>
</if>

<div id='book-page'>
<include src="view-page" &="package_id"
      &="references" &="name" &="title" &="item_id" &="page" &="context" &="header_stuff" &="return_url" 
      &="content" &="references" &="lang_links" &="package_id" 
      &="rev_link" &="edit_link" &="delete_link" &="new_link" &="admin_link" &="index_link" 
      &="tags" &="no_tags" &="tags_with_links" &="save_tag_link" &="popular_tags_link" 
      &="per_object_categories_with_links" 
      &="digg_link" &="delicious_link" &="my_yahoo_link" 
      &="gc_link" &="gc_comments" &="notification_subscribe_link" &="notification_image" 
      &="top_portlets" &="page">
</div>

</div>
<div style="clear: both; text-align: left; font-size: 85%;">
<hr>
<if @digg_link@ not nil>
<div style='float: right'><a href='@digg_link@'><img  src='http://digg.com/img/badges/100x20-digg-button.png' width='100' height='20' alt='Digg!' border='1'/></a></div>
</if>
<if @delicious_link@ not nil>
<div style='float: right; padding-right: 10px;'><a href='@delicious_link@'><img src="http://i.i.com.com/cnwk.1d/i/ne05/fmwk/delicious_14x14.gif" width="14" height="14" border="0" alt="Add to your del.icio.us" />del.icio.us</a></div>
</if>
<if @my_yahoo_link@ not nil>
<div style='float: right; padding-right: 10px;'>
<a href="@my_yahoo_link@"><img src="http://us.i1.yimg.com/us.yimg.com/i/us/my/addtomyyahoo4.gif" width="91" height="17" border="0" align="middle" alt="Add to My Yahoo!"></a></div>
</if>
<div style="clear: both; text-align: left; font-size: 85%;">
<if @references@ ne "" or @lang_links.found@ ne "">
#xowiki.references_label# @references;noquote@ @lang_links.found;noquote@<br/>
</if>
<if @lang_links.undefined@ ne "">
#xowiki.create_this_page_in_language# @lang_links.undefined;noquote@
</if>
<br/>
<if @no_tags@ eq 0>
#xowiki.your_tags_label#: @tags_with_links;noquote@
(<a href='#' onclick='document.getElementById("edit_tags").style.display="inline";return false;'>#xowiki.edit_link#</a>, 
<a href='#' onclick='get_popular_tags();return false;'>#xowiki.popular_tags_link#</a>)
<span id='edit_tags' style='display: none'>
<FORM action="@save_tag_link@" method='POST'><INPUT name='new_tags' type='text' value="@tags@"></FORM>
</span>
<span id='popular_tags' style='display: none'></span><br/>
</if>
<if @per_object_categories_with_links@ not nil and @per_object_categories_with_links@ ne "">
Categories: @per_object_categories_with_links;noquote@
</if>
</div><br/>
<if @gc_comments@ not nil>
   <p>#general-comments.Comments#
   <ul>@gc_comments;noquote@</ul></p>
</if>
<if @gc_link@ not nil>
   <p>@gc_link;noquote@</p>
</if>
</div> <!-- class='xowiki-content' -->
