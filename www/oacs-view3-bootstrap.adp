<master>
    <property name="doc(title)">@title;literal@</property>
    <property name="context">@context;literal@</property>
    <if @item_id@ not nil><property name="displayed_object_id">@item_id;literal@</property></if>
    <property name="&body">property_body</property>
    <property name="&doc">property_doc</property>
    <property name="head">
                  
        <style type='text/css'>
            blockquote {font-size:inherit;}
            div.xowiki-content {font-size:14px;}
            div.xowiki-content h1,h2,h3 {margin-bottom:10px;margin-top:20px;}
            div.xowiki-content h1 {border-bottom: none;color:font-weight:500;color:#cf8a00 !important;}
            div.xowiki-content h2 {border-bottom: none;color:font-weight:500;}
            div.xowiki-content h3 {font-weight:500;}
            div.xowiki-content pre, div.code {font-size:100%;}
            div.xowiki-content .item-footer {border-top:none;}
        </style>
        <link rel='stylesheet' href='/resources/xowiki/cattree.css' media='all' >
        <link rel='stylesheet' href='/resources/calendar/calendar.css' media='all' >
        <script language='javascript' src='/resources/acs-templating/mktree.js' type='text/javascript'></script>
        @header_stuff;literal@
    </property>
    
    <!-- The following DIV is needed for overlib to function! -->
    <div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>    
    <div class='xowiki-content'>
    <div id='wikicmds'>
          <if @view_link@ not nil><a href="@view_link;noi18n@" accesskey='v' title='#xowiki.view_title#'>#xowiki.view#</a> &middot; </if>
          <if @edit_link@ not nil><a href="@edit_link;noi18n@" accesskey='e' title='#xowiki.edit_title#'>#xowiki.edit#</a> &middot; </if>
          <if @rev_link@ not nil><a href="@rev_link;noi18n@" accesskey='r' title='#xowiki.revisions_title#'>#xotcl-core.revisions#</a> &middot; </if>
          <if @new_link@ not nil><a href="@new_link;noi18n@" accesskey='n' title='#xowiki.new_title#'>#xowiki.new_page#</a> &middot; </if>
          <if @delete_link@ not nil><a href="@delete_link;noi18n@" accesskey='d' title='#xowiki.delete_title#'>#xowiki.delete#</a> &middot; </if>
          <if @admin_link@ not nil><a href="@admin_link;noi18n@" accesskey='a' title='#xowiki.admin_title#'>#xowiki.admin#</a> &middot; </if>
          <if @notification_subscribe_link@ not nil><a href='/notifications/manage' title='#xowiki.notifications_title#'>#xowiki.notifications#</a>
          <a href="@notification_subscribe_link;noi18n@" class="notification-image-button">&nbsp;</a> &middot; </if>
          <a href='#' onclick='document.getElementById("do_search").style.display="inline";document.getElementById("do_search_q").focus(); return false;'  title='#xowiki.search_title#'>#xowiki.search#</a> &middot;
          <if @index_link@ not nil><a href="@index_link;noi18n@" accesskey='i' title='#xowiki.index_title#'>#xowiki.index#</a></if>
          <div id='do_search' style='display: none'>
            <form action='/search/search'><div><label for='do_search_q'>#xowiki.search#</label><input id='do_search_q' name='q' type='text'><input type="hidden" name="search_package_id" value="@package_id;literal@" ></div></form>
          </div>
    </div>
 
    <div class="row"> 

        <div class="col-md-9 col-sm-8 col-xs-12 col-md-push-3 col-sm-push-4"> <!-- content -->
            @top_includelets;noquote@
            <if @page_context@ not nil><h1>@title@ (@page_context@)</h1></if>
            <else><h1>@title@</h1></else>
            <if @folderhtml@ not nil> 
                <div class='folders' style=''>@folderhtml;noquote@</div> 
                <div class='content-with-folders'>@content;noquote@</div> 
            </if>
            <else>@content;noquote@</else>
        </div> <!-- content -->

        <div class="col-md-3 col-sm-4 col-xs-12 home-left col-md-pull-9 col-sm-pull-8" style="font-size:small;"> <!-- left panel in full view -->
            <div class="thumbnail">
                <div class="caption">
                    <include src="/packages/xowiki/www/portlets/weblog-mini-calendar" &__including_page=page summary="0" noparens="0">
                </div>
            </div>
            <div class="thumbnail">
                <div class="caption">
                    <include src="/packages/xowiki/www/portlets/include" &__including_page=page portlet="tags -decoration plain">
                </div>
            </div>
            <div class="thumbnail">
                <div class="caption">
                    <include src="/packages/xowiki/www/portlets/include" &__including_page=page portlet="tags -popular 1 -limit 30 -decoration plain">
                </div>
            </div>
            <div class="thumbnail">
                <div class="caption">
                    <include src="/packages/xowiki/www/portlets/include" &__including_page=page portlet="presence -interval {30 minutes} -decoration plain">
                    <a href="contributors" title="Show People contributing to this XoWiki Instance">Contributors</a>
                </div>
            </div> <!-- background -->

            <div class="thumbnail">
                <div class="caption">
                    <include src="/packages/xowiki/www/portlets/include" &__including_page=page portlet="categories -open_page [list @name@] -decoration plain">
                </div>
            </div>  <!-- background -->
        </div>
    </div>
    
    <div class="row">
        <div class="col-xs-12">
            <hr>        
            @footer;noquote@
        </div>
    </div>

</div> <!-- /xowiki-content -->
