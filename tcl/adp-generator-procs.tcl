ad_library {
    XoWiki - adp generator procs: remove redundancy in adp files by generating it

    @creation-date 2007-03-13
    @author Gustaf Neumann
    @cvs-id $Id$
}


namespace eval ::xowiki {
  
  Class ADP_Generator -parameter {
    {master 1} 
    {wikicmds 1} 
    {footer 1} 
    {recreate 0}
    {extra_header_stuff ""}
  }

  ADP_Generator instproc before_render {obj} {
    # just a hook, might be removed later
  }

  ADP_Generator instproc ajax_tag_definition {} {
    # if we have no footer, we have no tag form
    if {![my footer]} {return ""}

    return {<script type="text/javascript">
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
</script>}
  }



  ADP_Generator instproc master_part {} {
    return [subst -novariables -nobackslashes \
{<master>
  <property name="title">@title;noquote@</property>
  <property name="context">@context;noquote@</property>
  <property name="&body">property_body</property>
  <property name="&doc">property_doc</property>
  <property name="header_stuff">
  <link rel="stylesheet" type="text/css" href="/resources/xowiki/xowiki.css" media="all" >
  @header_stuff;noquote@[my extra_header_stuff]
  [my ajax_tag_definition]
  </property>
  <property name="head">
  <link rel="stylesheet" type="text/css" href="/resources/xowiki/xowiki.css" media="all" >
  @header_stuff;noquote@[my extra_header_stuff]
  [my ajax_tag_definition]
  </property>}]\n
  }

  ADP_Generator instproc wikicmds_part {} {
    if {![my wikicmds]} {return ""}
    return {<div id='wikicmds'>
  <if @edit_link@ not nil><a href="@edit_link@" accesskey='e' title='Diese Seite bearbeiten ...'>#xowiki.edit#</a> &middot; </if>
  <if @rev_link@ not nil><a href="@rev_link@" accesskey='r'>#xotcl-core.revisions#</a> &middot; </if>
  <if @new_link@ not nil><a href="@new_link@" accesskey='n'>#xowiki.new_page#</a> &middot; </if>
  <if @delete_link@ not nil><a href="@delete_link@" accesskey='d'>#xowiki.delete#</a> &middot; </if>
  <if @admin_link@ not nil><a href="@admin_link@" accesskey='a'>#xowiki.admin#</a> &middot; </if>
  <if @notification_subscribe_link@ not nil><a href='/notifications/manage'>#xowiki.notifications#</a> 
      <a href="@notification_subscribe_link@">@notification_image;noquote@</a> &middot; </if>  
   <a href='#' onclick='document.getElementById("do_search").style.display="inline";document.getElementById("do_search_q").focus(); return false;'>#xowiki.search#</a> &middot;
  <if @index_link@ not nil><a href="@index_link@" accesskey='i'>#xowiki.index#</a></if>
<div id='do_search' style='display: none'> 
  <FORM action='/search/search'><div><INPUT id='do_search_q' name='q' type='text'><INPUT type="hidden" name="search_package_id" value="@package_id@" ></div></FORM> 
</div>
</div>}
  }

  ADP_Generator instproc footer_part {} {
    if {![my footer]} {return ""}
    return "@footer;noquote@"
  }

  ADP_Generator instproc content_part {} {
    return "@top_includelets;noquote@\n<h1>@title@</h1>\n@content;noquote@"
  }


  ADP_Generator instproc generate {} {
    my instvar master wikicmds footer
    set _ "<!-- Generated by [self class] on [clock format [clock seconds]] -->\n"

    # if we include the master, we include the primitive js function
    if {$master} {
      append _ [my master_part]
    }

    append _ \
{<!-- The following DIV is needed for overlib to function! -->
  <div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>	
<div class='xowiki-content'>} \n

    append _ [my wikicmds_part] \n
    append _ [my content_part] \n
    append _ [my footer_part] \n
    append _ "</div> <!-- class='xowiki-content' -->\n"
  }

  ADP_Generator instproc init {} {
    set name [namespace tail [self]]
    set filename [file dirname [info script]]/../www/$name.adp
    # generate the adp file, if it does not exist
    if {[catch {set f [open $filename w]} errorMsg]} {
      my log "Warning: cannot overwrite $filename, ignoring possible changes"
    } else {
      puts -nonewline $f [my generate]
      close $f
    }
  }

  ADP_Generator create view-plain -master 0 -wikicmds 0 -footer 0
  ADP_Generator create view-links -master 0 -footer 0
  ADP_Generator create view-default -master 1 -footer 1

  ADP_Generator create oacs-view -master 1 -footer 1 \
    -extra_header_stuff {
      <link rel='stylesheet' href='/resources/xowiki/cattree.css' media='all' />
      <script language='javascript' src='/resources/acs-templating/mktree.js' type='text/javascript'></script>
    } \
    -proc content_part {} {
       return [subst -novariables -nobackslashes \
{<div style="float:left; width: 25%; font-size: 85%;
     background: url(/resources/xowiki/bw-shadow.png) no-repeat bottom right;
     margin-left: 2px; margin-top: 2px; padding: 0px 6px 6px 0px;			    
">
<div style="margin-top: -2px; margin-left: -2px; border: 1px solid #a9a9a9; padding: 5px 5px; background: #f8f8f8;">
<include src="/packages/xowiki/www/portlets/include" 
	 &__including_page=page 
	 portlet="categories -open_page @name@  -decoration plain">
</div></div>
<div style="float:right; width: 70%;">
[next]
</div>
}]
     }

  #
  # similar to oacs view (categories left), but having as well a right bar
  #
  ADP_Generator create oacs-view2 -master 1 -footer 1 \
    -extra_header_stuff {
      <link rel='stylesheet' href='/resources/xowiki/cattree.css' media='all' />
      <link rel='stylesheet' href='/resources/calendar/calendar.css' media='all' />
      <script language='javascript' src='/resources/acs-templating/mktree.js' type='text/javascript'></script>
    } \
    -proc before_render {page} {
      ::xo::cc set_parameter weblog_page weblog-portlet
    } \
    -proc content_part {} {
       return [subst -novariables -nobackslashes \
{<div style="float:left; width: 25%; font-size: 85%;
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
[next]
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
}]
     }

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
      <link rel='stylesheet' href='/resources/xowiki/cattree.css' media='all' />
      <link rel='stylesheet' href='/resources/calendar/calendar.css' media='all' />
      <script language='javascript' src='/resources/acs-templating/mktree.js' type='text/javascript'></script>
    } \
    -proc before_render {page} {
      ::xo::cc set_parameter weblog_page weblog-portlet
    } \
    -proc content_part {} {
       return [subst -novariables -nobackslashes \
{<div style="float:left; width: 245px; font-size: 85%;">


<div style="background: url(/resources/xowiki/bw-shadow.png) no-repeat bottom right;
     margin-left: 2px; margin-top: 2px; padding: 0px 6px 6px 0px;			    
">
<div style="margin-top: -2px; margin-left: -2px; border: 1px solid #a9a9a9; padding: 5px 5px; background: #f8f8f8">
<include src="/packages/xowiki/www/portlets/weblog-mini-calendar" 
	 &__including_page=page 
         summary="0" noprens="1">
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
</div> <!-- background -->

<div style="background: url(/resources/xowiki/bw-shadow.png) no-repeat bottom right;
     margin-left: 2px; margin-top: 2px; padding: 0px 6px 6px 0px;			    
">
<div style="margin-top: -2px; margin-left: -2px; border: 1px solid #a9a9a9; padding: 5px 5px; background: #f8f8f8">

<include src="/packages/xowiki/www/portlets/include" 
	 &__including_page=page 
	 portlet="categories -open_page @name@  -decoration plain">
</div></div>  <!-- background -->
</div>
<div style="float:right; width: 70%;">
[next]
</div> <!-- right 70% -->
}]
     }



  #
  # view-book, wiki cmds in rhs
  #
  ADP_Generator create view-book -master 1 -footer 1  -wikicmds 0 \
    -extra_header_stuff {
    } \
    -proc before_render {page} {
      #::xo::cc set_parameter weblog_page weblog-portlet
    } \
    -proc content_part {} {
       return [subst -novariables -nobackslashes \
{<div style="float:left; width: 25%; font-size: .8em;
     background: url(/resources/xowiki/bw-shadow.png) no-repeat bottom right;
     margin-left: 2px; margin-top: 2px; padding: 0px 6px 6px 0px;			    
">
<div style="margin-top: -2px; margin-left: -2px; border: 1px solid #a9a9a9; padding: 5px 5px; background: #f8f8f8">
@toc;noquote@
</div></div>
<div style="float:right; width: 70%;">@top_includelets;noquote@

<if @book_prev_link@ not nil or @book_relpos@ not nil or @book_next_link@ not nil>
<div class="book-navigation" style="background: #f8f8f8; border: 1px solid #a9a9a9;  width: 500px;">
<table width='100%' 
  summary='This table provides a progress bar and buttons for next and previous pages'>
   <tr>
   <td width='20'>
   <if @book_prev_link@ not nil>
        <a href="@book_prev_link@" accesskey='p' ID="bookNavPrev.a" onclick='return TocTree.getPage("@book_prev_link@");'>
        <img border='0' alt='Previous' src='/resources/xowiki/previous.png' width='15' ID="bookNavPrev.img"></a>
    </if>
    <else>
        <a href="" accesskey='p' ID="bookNavPrev.a" onclick="">
        <img border='0' alt='No Previous' src='/resources/xowiki/previous-end.png' width='15' ID="bookNavPrev.img"></a>
    </else>
     </td>

   <td>
   <if @book_relpos@ not nil>
     <table style='display: inline; text-align: center;'>
     <tr><td width='450' style='font-size: 75%'><div style='width: @book_relpos@;' ID='bookNavBar'></div><span ID='bookNavRelPosText'>@book_relpos@</span></td></tr>
     </table>
   </if>
   </td>

   <td width='20' ID="bookNavNext">
   <if @book_next_link@ not nil>
        <a href="@book_next_link@" accesskey='n' ID="bookNavNext.a" onclick='return TocTree.getPage("@book_next_link@");'>
        <img border='0' alt='Next' src='/resources/xowiki/next.png' width='15' ID="bookNavNext.img"></a>
   </if>
    <else>
        <a href="" accesskey='n' ID="bookNavNext.a" onclick="">
       <img border='0' alt='No Next' src='/resources/xowiki/next-end.png' width='15' ID="bookNavNext.img"></a>
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
      &="top_includelets" &="page">
</div>
</div>
}]}


  #
  # view-book-no-ajax, adp identical to view-book.
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