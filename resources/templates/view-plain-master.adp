<<<<<<< view-plain-master.adp
<!-- Generated by ::xowiki::ADP_Generator on Wed Jan 22 14:59:23 CET 2020 -->
=======
<!-- Generated by ::xowiki::ADP_Generator on Sun Jan 26 18:57:43 CET 2020 -->
>>>>>>> 1.1.2.2
<master>
                  <property name="context">@context;literal@</property>
                  <if @item_id@ not nil><property name="displayed_object_id">@item_id;literal@</property></if>
                  <property name="&body">body</property>
                  <property name="&doc">doc</property>
                  <property name="head"></property>
<!-- The following DIV is needed for overlib to function! -->
          <div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
          <div class='xowiki-content'>

 @top_includelets;noquote@
 <if @body.menubarHTML@ not nil><div class='visual-clear'><!-- --></div>@body.menubarHTML;noquote@</if>
 <if @page_context@ not nil><h1>@body.title@ (@page_context@)</h1></if>
 <else><h1>@body.title@</h1></else>
 <if @folderhtml@ not nil> 
 <div class='folders' style=''>@folderhtml;noquote@</div> 
 <div class='content-with-folders'>@content;noquote@</div> 
 </if>
    <else>@content;noquote@</else>

</div> <!-- class='xowiki-content' -->
