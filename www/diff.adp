<master>
  <property name="doc(title)">@title;literal@</property>
  <property name="&doc">property_doc</property>
  <property name="context">@context;literal@</property>
 
<property name="head">
<style type='text/css'>
.added {
  color: green;
  text-decoration: underline;
}
.removed {
  color: red;
  text-decoration: line-through;
}
span.diff-deleted {color: red; text-decoration: line-through;}
span.diff-added {color: green;  text-decoration: underline;}
</style>
</property>

  <!-- The following DIV is needed for overlib to function! -->
  <div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>	

  <p>  Comparing 
<ul>
<li>version @revision_id1@ modified by @user1@ at @time1@ with 
<li>version @revision_id2@ modified by @user2@ at @time2@
</ul>
  </p>
  <hr>

@content;noquote@

