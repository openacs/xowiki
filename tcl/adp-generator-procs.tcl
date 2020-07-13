::xo::library doc {
  XoWiki - ADP generator procs: remove redundancy in ADP files by generating it

  @creation-date 2007-03-13
  @author Gustaf Neumann
  @cvs-id $Id$
}


namespace eval ::xowiki {

  Class create ADP_Generator -parameter {
    {master 1}
    {wikicmds 1}
    {footer 1}
    {recreate 0}
    {extra_header_stuff ""}
  }

  ADP_Generator instproc before_render {obj} {
    # just a hook, might be removed later
  }

  ADP_Generator instproc master_part {} {
    return [subst -novariables -nobackslashes \
                {<master>
                  <property name="context">@context;literal@</property>
                  <if @item_id@ not nil><property name="displayed_object_id">@item_id;literal@</property></if>
                  <property name="&body">body</property>
                  <property name="&doc">doc</property>
                  <property name="head">[:extra_header_stuff]</property>}]\n
  }

  ADP_Generator instproc wikicmds_part {} {
    if {![:wikicmds]} {return ""}
    return {
      <%
      if {$::xowiki::search_mounted_p} {
        template::add_event_listener \
          -id wiki-menu-do-search-control \
          -script {
            document.getElementById('do_search').style.display = 'inline';
            document.getElementById('do_search_q').focus();
          }
      }
      %>
      <div id='wikicmds'>
      <if @view_link@ not nil><a href="@view_link@" accesskey='v' title='#xowiki.view_title#'>#xowiki.view#</a> &middot; </if>
      <if @edit_link@ not nil><a href="@edit_link@" accesskey='e' title='#xowiki.edit_title#'>#xowiki.edit#</a> &middot; </if>
      <if @rev_link@ not nil><a href="@rev_link@" accesskey='r' title='#xowiki.revisions_title#'>#xotcl-core.revisions#</a> &middot; </if>
      <if @new_link@ not nil><a href="@new_link@" accesskey='n' title='#xowiki.new_title#'>#xowiki.new_page#</a> &middot; </if>
      <if @delete_link@ not nil><a href="@delete_link@" accesskey='d' title='#xowiki.delete_title#'>#xowiki.delete#</a> &middot; </if>
      <if @admin_link@ not nil><a href="@admin_link@" accesskey='a' title='#xowiki.admin_title#'>#xowiki.admin#</a> &middot; </if>
      <if @notification_subscribe_link@ not nil><a href='/notifications/manage' title='#xowiki.notifications_title#'>#xowiki.notifications#</a>
      <a href="@notification_subscribe_link@" class="notification-image-button">&nbsp;</a>&middot; </if>
      <if @::xowiki::search_mounted_p@ true><a href='#' id='wiki-menu-do-search-control' title='#xowiki.search_title#'>#xowiki.search#</a> &middot; </if>
      <if @index_link@ not nil><a href="@index_link@" accesskey='i' title='#xowiki.index_title#'>#xowiki.index#</a></if>
      <div id='do_search' style='display: none'>
      <form action='/search/search'><div><label for='do_search_q'>#xowiki.search#</label><input id='do_search_q' name='q' type='text'><input type="hidden" name="search_package_id" value="@package_id@"><if @::__csrf_token@ defined><input type="hidden" name="__csrf_token" value="@::__csrf_token;literal@"></if></div></form>
      </div>
      </div>}
  }

  ADP_Generator instproc footer_part {} {
    if {![:footer]} {return ""}
    return "@footer;noquote@"
  }

  ADP_Generator instproc content_part {} {
    return "\
     @top_includelets;noquote@\n\
     <if @body.menubarHTML@ not nil><div class='visual-clear'><!-- --></div>@body.menubarHTML;noquote@</if>\n\
     <if @page_context@ not nil><h1>@body.title@ (@page_context@)</h1></if>\n\
     <else><h1>@body.title@</h1></else>\n\
     <if @folderhtml@ not nil> \n\
       <div class='folders' style=''>@folderhtml;noquote@</div> \n\
       <div class='content-with-folders'>@content;noquote@</div> \n\
     </if>
    <else>@content;noquote@</else>"
  }

  ADP_Generator instproc generate {} {
    set _ "<!-- Generated by [self class] on [clock format [clock seconds]] -->\n"

    # if we include the master, we include the primitive js function
    if {${:master}} {
      append _ [:master_part]
    }

    append _ \
        {<!-- The following DIV is needed for overlib to function! -->
          <div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
          <div class='xowiki-content'>} \n

    append _ [:wikicmds_part] \n
    append _ [:content_part] \n
    append _ [:footer_part] \n
    append _ "</div> <!-- class='xowiki-content' -->\n"
  }

  ADP_Generator instproc init {} {
    set name [namespace tail [self]]
    set adpFilename [file dirname [info script]]/../resources/templates/$name.adp
    #
    # Generate the ADP file, when does not exist, or when the
    # generator is newer.
    #
    if {![ad_file exists $adpFilename]
        || [file mtime [info script]] > [ad_file mtime $adpFilename]} {
      try {
        set f [open $adpFilename w]
      } on error {errorMsg} {
        :log "Warning: cannot overwrite ADP $adpFilename, ignoring possible changes"
      } on ok {r} {
        ::puts -nonewline $f [:generate]
        close $f
        :log "Notice: created ADP $adpFilename"
      }
    }
  }
  ####################################################################################
  # Definition of Templates
  ####################################################################################
  #
  # view-plain (without master)
  #
  ADP_Generator create view-plain -master 0 -wikicmds 0 -footer 0

  #
  # view-plain-master (plain with master)
  #
  ADP_Generator create view-plain-master -master 1 -wikicmds 0 -footer 0

  ####################################################################################
  #
  # view-links
  #
  ADP_Generator create view-links -master 0 -footer 0

  #####################################################################################
  #
  # view-default
  #
  ADP_Generator create view-default -master 1 -footer 1

  ####################################################################################
  #
  # oacs-view
  #
  ADP_Generator create oacs-view -master 1 -footer 1 \
      -extra_header_stuff {
        <link rel='stylesheet' href='/resources/xowiki/cattree.css' media='all' >
        <script language='javascript' src='/resources/acs-templating/mktree.js' async type='text/javascript'></script>
      } \
      -proc content_part {} {
        set open_page {-open_page [list @name@]}
        return [subst -novariables -nobackslashes \
                    {<div style="float:left; width: 25%; font-size: 85%;
     background: url(/resources/xowiki/bw-shadow.png) no-repeat bottom right;
     margin-left: 6px; margin-top: 6px; padding: 0px;
">
                      <div style="position:relative; right:6px; bottom:6px;  border: 1px solid #a9a9a9; padding: 5px 5px; background: #f8f8f8;">
                      <include src="/packages/xowiki/www/portlets/include" &__including_page=page
                      portlet="categories [set open_page] -decoration plain">
                      </div></div>
                      <div style="float:right; width: 70%;">
                      [next]
                      </div>
                    }]
      }

  ####################################################################################
  #
  # oacs-view2
  #
  # similar to oacs view (categories left), but having as well a right bar
  #
  ADP_Generator create oacs-view2 -master 1 -footer 1 \
      -extra_header_stuff {
        <link rel='stylesheet' href='/resources/xowiki/cattree.css' media='all' >
        <link rel='stylesheet' href='/resources/calendar/calendar.css' media='all' >
        <script language='javascript' src='/resources/acs-templating/mktree.js' async type='text/javascript'></script>
      } \
      -proc before_render {page} {
        ::xo::cc set_parameter weblog_page weblog-portlet
      } \
      -proc content_part {} {
        set open_page {-open_page [list @name@]}
        return [subst -novariables -nobackslashes \
                    {<div style="float:left; width: 25%; font-size: 85%;
     background: url(/resources/xowiki/bw-shadow.png) no-repeat bottom right;
     margin-left: 6px; margin-top: 6px; padding: 0px;
">
                      <div style="position:relative; right:6px; bottom:6px;  border: 1px solid #a9a9a9; padding: 5px 5px; background: #f8f8f8">
                      <include src="/packages/xowiki/www/portlets/include" &__including_page=page
                      portlet="categories [set open_page] -decoration plain">
                      </div></div>
                      <div style="float:right; width: 70%;">
                      <style type='text/css'>
                      table.mini-calendar {width: 200px ! important;}
                      #sidebar {min-width: 220px ! important; top: 0px; overflow: visible;}
                      </style>
                      <div style='float: left; width: 62%'>
                      [next]
                      </div>  <!-- float left -->
                      <div id='sidebar' class='column'>
                      <div style="background: url(/resources/xowiki/bw-shadow.png) no-repeat bottom right;
     margin-left: 6px; margin-top: 6px; padding: 0px;
">
                      <div style="position:relative; right:6px; bottom:6px;  border: 1px solid #a9a9a9; padding: 5px 5px; background: #f8f8f8">
                      <include src="/packages/xowiki/www/portlets/weblog-mini-calendar" &__including_page=page
                      summary="0" noparens="0">
                      <include src="/packages/xowiki/www/portlets/include" &__including_page=page
                      portlet="tags -decoration plain">
                      <include src="/packages/xowiki/www/portlets/include" &__including_page=page
                      portlet="tags -popular 1 -limit 30 -decoration plain">
                      <hr>
                      <include src="/packages/xowiki/www/portlets/include" &__including_page=page
                      portlet="presence -interval {30 minutes} -decoration plain">
                      <hr>
                      <a href="/xowiki/contributors" title="Show People contributing to this XoWiki Instance">Contributors</a>
                      </div>
                      </div>
                      </div> <!-- sidebar -->

                      </div> <!-- right 70% -->
                    }]
      }

  ####################################################################################
  #
  # oacs-view3
  #
  # similar to oacs view2 (categories left), but everything left
  #
  ADP_Generator create oacs-view3 -master 1 -footer 1 \
      -extra_header_stuff {
        <style type='text/css'>
        table.mini-calendar {width: 227px ! important;font-size: 80%;}
        div.tags h3 {font-size: 80%;}
        div.tags blockquote {font-size: 80%; margin-left: 20px; margin-right: 20px;}
        </style>
        <link rel='stylesheet' href='/resources/xowiki/cattree.css' media='all' >
        <link rel='stylesheet' href='/resources/calendar/calendar.css' media='all' >
        <script language='javascript' src='/resources/acs-templating/mktree.js' async type='text/javascript'></script>
      } \
      -proc before_render {page} {
        ::xo::cc set_parameter weblog_page weblog-portlet
      } \
      -proc content_part {} {
        set open_page {-open_page [list @name@]}
        return [subst -novariables -nobackslashes {\

          <div style="width: 100%"> <!-- contentwrap -->

          <div style="float:left; width: 245px; font-size: 85%;">
          <div style="background: url(/resources/xowiki/bw-shadow.png) no-repeat bottom right;
     margin-left: 6px; margin-top: 6px; padding: 0px;
">
          <div style="position:relative; right:6px; bottom:6px;  border: 1px solid #a9a9a9; padding: 5px 5px; background: #f8f8f8">
          <include src="/packages/xowiki/www/portlets/weblog-mini-calendar" &__including_page=page
          summary="0" noparens="0">
          <include src="/packages/xowiki/www/portlets/include" &__including_page=page
          portlet="tags -decoration plain">
          <include src="/packages/xowiki/www/portlets/include" &__including_page=page
          portlet="tags -popular 1 -limit 30 -decoration plain">
          <hr>
          <include src="/packages/xowiki/www/portlets/include" &__including_page=page
          portlet="presence -interval {30 minutes} -decoration plain">
          <hr>
          <a href="contributors" title="Show People contributing to this XoWiki Instance">Contributors</a>
          </div>
          </div> <!-- background -->

          <div style="background: url(/resources/xowiki/bw-shadow.png) no-repeat bottom right;
     margin-left: 6px; margin-top: 6px; padding: 0px;
">
          <div style="position:relative; right:6px; bottom:6px;  border: 1px solid #a9a9a9; padding: 5px 5px; background: #f8f8f8">
          <include src="/packages/xowiki/www/portlets/include" &__including_page=page
          portlet="categories [set open_page] -decoration plain">
          </div></div>  <!-- background -->
          </div>

          <div style="margin-left: 260px;"> <!-- content -->
          [next]
          </div> <!-- content -->
          </div> <!-- contentwrap -->

        }]
      }

  # oacs-view3-bootstrap3
  #
  # similar to oacs view3, but based on bootstrap
  #
  ADP_Generator create oacs-view3-bootstrap3 -master 1 -footer 0 -wikicmds 1 \
      -extra_header_stuff {
        <style type='text/css'>
            blockquote {font-size:inherit;}
            div.xowiki-content {font-size:14px;}
            div.xowiki-content h1,h2,h3 {margin-bottom:10px;margin-top:20px;}
            div.xowiki-content h1 {border-bottom: none;font-weight:500;color:#cf8a00 !important;}
            div.xowiki-content h2 {border-bottom: none;font-weight:500;}
            div.xowiki-content h3 {font-weight:500;}
            div.xowiki-content pre, div.code {font-size:100%;}
            div.xowiki-content .item-footer {border-top:none;}
        </style>
        <link rel='stylesheet' href='/resources/xowiki/cattree.css' media='all' >
        <link rel='stylesheet' href='/resources/calendar/calendar.css' media='all' >
        <script language='javascript' src='/resources/acs-templating/mktree.js' async type='text/javascript'></script>
      } \
      -proc before_render {page} {
        ::xo::cc set_parameter weblog_page weblog-portlet
      } \
      -proc content_part {} {
        set open_page {-open_page [list @name@]}
        return [subst -novariables -nobackslashes {\

    <div class="row">

        <div class="col-md-9 col-sm-8 col-xs-12 col-md-push-3 col-sm-push-4"> <!-- content -->
            @top_includelets;noquote@
            <if @body.menubarHTML@ not nil><div class='visual-clear'><!-- --></div>@body.menubarHTML;noquote@</if>
            <if @page_context@ not nil><h1>@body.title@ (@page_context@)</h1></if>
            <else><h1>@body.title@</h1></else>
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
                    <a href="/xowiki/contributors" title="Show People contributing to this XoWiki Instance">Contributors</a>
                </div>
            </div> <!-- background -->

            <div class="thumbnail">
                <div class="caption">
                    <include src="/packages/xowiki/www/portlets/include" &__including_page=page portlet="categories [set open_page] -decoration plain">
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
        }]
      }



  ####################################################################################
  #
  # view-book
  #
  # wiki cmds in rhs
  #
  ADP_Generator create view-book -master 1 -footer 1  -wikicmds 0 \
      -extra_header_stuff {
      } \
      -proc before_render {page} {
        #::xo::cc set_parameter weblog_page weblog-portlet
      } \
      -proc content_part {} {
        return {
<%
if {$book_prev_link ne ""} {
  template::add_event_listener \
      -id bookNavPrev.a \
      -preventdefault=false \
      -script [subst {TocTree.getPage("$book_prev_link");}]
}
if {$book_next_link ne ""} {
  template::add_event_listener \
      -id bookNavNext.a \
      -preventdefault=false \
      -script [subst {TocTree.getPage("$book_next_link");}]
}
%>                      <div style="float:left; width: 25%; font-size: .8em;
     background: url(/resources/xowiki/bw-shadow.png) no-repeat bottom right;
     margin-left: 6px; margin-top: 6px; padding: 0px;
">
                      <div style="position:relative; right:6px; bottom:6px; border: 1px solid #a9a9a9; padding: 5px 5px; background: #f8f8f8">
                      @toc;noquote@
                      </div></div>
                      <div style="float:right; width: 70%;">
                      <if @book_prev_link@ not nil or @book_relpos@ not nil or @book_next_link@ not nil>
                      <div class="book-navigation" style="background: #fff; border: 1px dotted #000; padding-top:3px; margin-bottom:0.5em;">
                      <table width='100%'
                      summary='This table provides a progress bar and buttons for next and previous pages'>
                      <colgroup><col width='20'><col><col width='20'>
                      </colgroup>
                      <tr>
                      <td>
                      <if @book_prev_link@ not nil>
                      <a href="@book_prev_link@" accesskey='p' id="bookNavPrev.a">
                      <img alt='Previous' src='/resources/xowiki/previous.png' width='15' id="bookNavPrev.img"></a>
                      </if>
                      <else>
                      <a href="" accesskey='p' id="bookNavPrev.a">
                      <img alt='No Previous' src='/resources/xowiki/previous-end.png' width='15' id="bookNavPrev.img"></a>
                      </else>
                      </td>

                      <td>
                      <if @book_relpos@ not nil>
                      <table width='100%'>
                      <colgroup><col></colgroup>
                      <tr><td style='font-size: 75%'><div style='width: @book_relpos@;' id='bookNavBar'></div></td></tr>
                      <tr><td style='font-size: 75%; text-align:center;'><span id='bookNavRelPosText'>@book_relpos@</span></td></tr>
                      </table>
                      </if>
                      </td>

                      <td id="bookNavNext">
                      <if @book_next_link@ not nil>
                      <a href="@book_next_link@" accesskey='n' id="bookNavNext.a">
                      <img alt='Next' src='/resources/xowiki/next.png' width='15' id="bookNavNext.img"></a>
                      </if>
                      <else>
                      <a href="" accesskey='n' id="bookNavNext.a">
                      <img alt='No Next' src='/resources/xowiki/next-end.png' width='15' id="bookNavNext.img"></a>
                      </else>
                      </td>
                      </tr>
                      </table>
                      </div>
                      </if>

                      <div id='book-page'>
                      <include src="view-page" &="package_id"
                      &="references" &="name" &="title" &="item_id" &="page" &="context" &="return_url"
                      &="content" &="references" &="lang_links" &="package_id"
                      &="rev_link" &="edit_link" &="delete_link" &="new_link" &="admin_link" &="index_link"
                      &="tags" &="no_tags" &="tags_with_links" &="save_tag_link" &="popular_tags_link"
                      &="per_object_categories_with_links"
                      &="digg_link" &="delicious_link" &="my_yahoo_link"
                      &="gc_link" &="gc_comments" &="notification_subscribe_link" &="notification_image"
                      &="top_includelets" &="folderhtml" &="page" &="doc" &="body">
                      </div>
                      </div>
                    }}

  ####################################################################################
  #
  # view-book-no-ajax
  #
  # ADP identical to view-book.
  #
  ADP_Generator create view-book-no-ajax -master 1 -footer 1 -wikicmds 0 \
      -extra_header_stuff {
      } \
      -proc before_render {page} {
        #::xo::cc set_parameter weblog_page weblog-portlet
      } \
      -proc content_part {} {
        return [view-book content_part]
      }

}

::xo::library source_dependent

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
