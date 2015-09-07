<master>
  <property name="doc(title)">@edit_form_page_title;literal@</property>
  <property name="&doc">property_doc</property>
  <property name="context">@context;literal@</property>
  <property name="focus">note.title</property>

<style type='text/css'>
#wikicmds {position: relative;top: -50px;  right: 0px; height: 0px;
	  text-align: right;  font-family: sans-serif; font-size: 85%;color: #7A7A78;}
#wikicmds a, #wikicmds a:visited { color: #7A7A78; text-decoration: none;}
#wikicmds a:hover {text-decoration: underline;}
#wikicmds a:active {color: rgb(255,153,51);}
</style>

<div id='wikicmds'>
   <if @back_link@ not nil><a href="@back_link@" accesskey='b' >#xowiki.back#</a> &middot;</if>
   <if @item_id@ not nil>
      <if @view_link@ not nil><a href="@view_link@" accesskey='v' >#xowiki.view#</a> &middot;</if>
      <if @rev_link@ not nil><a href="@rev_link@" accesskey='r' >#xotcl-core.revisions#</a> &middot;</if>
   </if>
   <if @index_link@ not nil><a href="@index_link@" accesskey='i'>#xowiki.index#</a></if>
</div>
  
<formtemplate id="@formTemplate;literal@"></formtemplate>
