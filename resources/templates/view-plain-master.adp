<!-- Generated by ::xowiki::ADP_Generator on Fri Aug 19 20:58:30 CEST 2022 -->
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
 <if @body.folderHTML@ not nil> 
 <div class='folders' style=''>@body.folderHTML;noquote@</div> 
 <div class='content-with-folders'>@content;noquote@</div> 
 </if>
    <else>@content;noquote@</else>

</div> <!-- class='xowiki-content' -->
