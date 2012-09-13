<master>
  <property name="title">@title;noquote@</property>
  <property name="doc(title)">@title;noquote@</property>
  <property name="context">@context;noquote@</property>
  <property name="header_stuff">@header_stuff;noquote@
  <link rel="stylesheet" type="text/css" href="/resources/xowiki/xowiki.css" media="all" />
  </property>
  <property name="head">@header_stuff;noquote@
  <link rel="stylesheet" type="text/css" href="/resources/xowiki/xowiki.css" media="all" />
  </property>

<div class='xowiki-content'>
<div id='wikicmds'>
 <if @back_link@ not nil><a href="@back_link@" accesskey='b'>#xowiki.back#</a> &middot; </if>
 <if @index_link@ not nil><a href="@index_link@" accesskey='i'>#xowiki.index#</a></if>
</div>
<p>&nbsp;</p>
<h3>Error:</h3>
<p>
<blockquote>
@error_msg;noquote@
<p>&nbsp;</p>
</blockquote>
</p>
</div>
