ad_library {
    XoWiki - main libraray classes and objects

    @creation-date 2006-01-10
    @author Gustaf Neumann
    @cvs-id $Id$
}

namespace eval ::xowiki {

  #
  # create classes for different kind of pages
  #
  ::Generic::CrClass create Page -superclass ::Generic::CrItem \
      -pretty_name "XoWiki Page" -pretty_plural "XoWiki Pages" \
      -table_name "xowiki_page" -id_column "page_id" \
      -mime_type text/html \
      -cr_attributes {
        ::Generic::Attribute new -attribute_name page_title -datatype text \
            -pretty_name "Page Title"
        ::Generic::Attribute new -attribute_name creator -datatype text \
            -pretty_name "Creator"
      } \
      -form ::xowiki::WikiForm

  ::Generic::CrClass create PlainPage -superclass Page \
      -pretty_name "XoWiki Plain Page" -pretty_plural "XoWiki Plain Pages" \
      -table_name "xowiki_plain_page" -id_column "ppage_id" \
      -mime_type text/plain \
      -form ::xowiki::PlainWikiForm

  ::Generic::CrClass create File -superclass Page \
      -pretty_name "XoWiki File" -pretty_plural "XoWiki Files" \
      -table_name "xowiki_file" -id_column "file_id" \
      -storage_type file \
      -form ::xowiki::FileForm

  ::Generic::CrClass create PageTemplate -superclass Page \
      -pretty_name "XoWiki Page Template" -pretty_plural "XoWiki Page Templates" \
      -table_name "xowiki_page_template" -id_column "page_template_id" \
      -form ::xowiki::WikiForm

  ::Generic::CrClass create PageInstance -superclass Page \
      -pretty_name "XoWiki Page Instance" -pretty_plural "XoWiki Page Instances" \
      -table_name "xowiki_page_instance" -id_column "page_instance_id" \
      -cr_attributes {
        ::Generic::Attribute new -attribute_name page_template -datatype integer \
            -pretty_name "Page Template"
        ::Generic::Attribute new -attribute_name instance_attributes -datatype text \
            -pretty_name "Instance Attributes"
      } \
      -form ::xowiki::PageInstanceForm \
      -edit_form ::xowiki::PageInstanceEditForm

  ::Generic::CrClass create Object -superclass PlainPage \
      -pretty_name "XoWiki Object" -pretty_plural "XoWiki Objects" \
      -table_name "xowiki_object" -id_column "xowiki_object_id" \
      -mime_type text/xotcl \
      -form ::xowiki::ObjectForm


  #
  # create reference table and table for user tracking
  #
  
  if {![db_0or1row check-xowiki-references-table \
            "select tablename from pg_tables where tablename = 'xowiki_references'"]} {
    db_dml create-xowiki-references-table "create table xowiki_references(
        reference integer references cr_items(item_id) on delete cascade,
        link_type text,
        page      integer references cr_items(item_id) on delete cascade)"
    db_dml create-xowiki-references-index \
        "create index xowiki_ref_index ON xowiki_references(reference)"
  }
  if {![db_0or1row check-xowiki-last-visited-table \
            "select tablename from pg_tables where tablename = 'xowiki_last_visited'"]} {
    db_dml create-xowiki-last-visited-table "create table xowiki_last_visited(
        page_id integer references cr_items(item_id) on delete cascade,
        package_id integer,
        user_id integer,
        count   integer,
        time    timestamp)"
    db_dml create-xowiki-last-visited-update-index \
        "create unique index xowiki_last_visited_index_unique ON xowiki_last_visited(user_id, page_id)"
    db_dml create-xowiki-last-visited-index \
        "create index xowiki_last_visited_index ON xowiki_last_visited(user_id, package_id)"
  }

  if {![db_0or1row check-tag-table \
            "select tablename from pg_tables where tablename = 'xowiki_tags'"]} {
    db_dml create-xowiki-tag-table "create table xowiki_tags(
        item_id integer references cr_items(item_id) on delete cascade,
        package_id integer,
        user_id integer references users(user_id),
        tag     text,
        time    timestamp)"
    db_dml create-xowiki-tags-index-user \
        "create index xowiki_tags_index_user ON xowiki_tags(user_id, item_id)"
    db_dml create-xowiki-tags-index-tag \
        "create index xowiki_tags_index_tag ON xowiki_tags(tag, package_id)"
  }

  #
  # Page definitions
  #
  
  Page parameter {
    page_id
    {creator ""}
    {revision_id 0}
    item_id
    object_type
    parent_id
    package_id
    name
    title
    text
    {folder_id -100}
    {lang_links ""}
    {lang en}
    {render_adp 1}
    {absolute_links 0}
  }
  Page set recursion_count 0
  Page array set RE {
    include {([^\\]){{(.+)}}[ \n\r]*}
    anchor  {([^\\])\\\[\\\[([^\]]+)\\\]\\\]}
    div     {()([^\\])&gt;&gt;([^&]*)&lt;&lt;()([ \n]*<br */?>)?}
    clean   {[\\](\{\{|&gt;&gt;|\[\[)}
    clean2  { <br */?> *(<div)}
  }

  #
  # templating and CSS
  #

  Page proc requireCSS name {set ::need_css($name) 1}
  Page proc requireJS  name {set ::need_js($name)  1}
  Page proc header_stuff {} {
    set result ""
    foreach file [array names ::need_css] {
      append result "<link rel='stylesheet' href='$file' media='all'>\n"
    }
    foreach file [array names ::need_js]  {
      append result "<script language='javascript' src='$file' type='text/javascript'>" \
          "</script>"
    }
    return $result
  }
  Page proc quoted_html_content text {
    list [ad_text_to_html $text] text/html
  }

  #
  # Operations on the whole instance
  #
  Class create Folder


  Page ad_proc select_query {
    {-select_attributes ""}
    {-order_clause ""}
    {-where_clause ""}
    {-count:boolean false}
    {-folder_id}
    {-page_size 20}
    {-page_number ""}
    {-extra_where_clause ""}
    {-extra_from_clause ""}
  } {
    returns the SQL-query to select the xowiki pages of the specified folder
    @select_attributes attributes for the sql query to be retrieved, in addion
      to ci.item_id acs_objects.object_type, which are always returned
    @param order_clause clause for ordering the solution set
    @param where_clause clause for restricting the answer set
    @param count return the query for counting the solutions
    @param folder_id parent_id
    @return sql query
  } {
    my instvar object_type_key
    #if {![info exists folder_id]} {my instvar folder_id}

    set attributes [list ci.item_id ci.name p.page_id] 
    foreach a $select_attributes {
      if {$a eq "title"} {set a p.title}
      lappend attributes $a
    }
    if {$count} {
      set attribute_selection "count(*)"
      set order_clause ""      ;# no need to order when we count
      set page_number  ""      ;# no pagination when count is used
    } else {
      set attribute_selection [join $attributes ,]
    }

    if {$where_clause ne ""} {set where_clause "and $where_clause "}
    if {$page_number ne ""} {
      set pagination "offset [expr {$page_size*($page_number-1)}] limit $page_size"
    } else {
      set pagination ""
    }
    return "select $attribute_selection from xowiki_pagei p, cr_items ci $extra_from_clause \
        where ci.parent_id = $folder_id and ci.item_id = p.item_id and \
        ci.live_revision = p.page_id $where_clause $extra_where_clause $order_clause $pagination"
  }


  Page proc rss_head {
                      -channel_title
                      -link
                      -description
                      {-language en-us}
                    } {
#<?xml-stylesheet type='text/css' href='http://localhost:8002/resources/xowiki/rss.css' ?>
    return "<?xml version='1.0' encoding='utf-8'?>
<rss version='2.0'
  xmlns:ent='http://www.purl.org/NET/ENT/1.0/'
  xmlns:dc='http://purl.org/dc/elements/1.1/'>
<channel>
  <title>$channel_title</title>
  <link>$link</link>
  <description>$description</description>
  <language>$language</language>
  <generator>xowiki</generator>"
  }

  Page proc rss_item {-creator -title -link -guid -description -pubdate } {
    append result <item> \n\
        <dc:creator> $creator </dc:creator> \n\
        <title> $title </title> \n\
        <link> $link </link> \n\
        "<guid isPermaLink='false'>" $guid </guid> \n\
        <description> $description </description> \n\
        <pubDate> $pubdate </pubDate> \n\
        </item> \n
  }
  
  Page proc rss_tail {} {
    return  "\n</channel>\n</rss>\n"
  }
  
  Page ad_proc rss {
    -maxentries
    -days 
    -package_id:required
  } {
    Report content of xowiki folder in rss 2.0 format. The
    reporting order is descending by date. The title of the feed
    is taken from the title, the description
    is taken from the description field of the folder object.
    
    @param maxentries maximum number of entries retrieved
    @param days report entries changed in speficied last days
    @param package_id to determine the xowiki instance
    
  } {
    set folder_id [::$package_id folder_id]
   
    set limit_clause [expr {[info exists maxentries] ? " limit $maxentries" : ""}]
    set timerange_clause [expr {[info exists days] ? 
                                " and p.last_modified > (now() + interval '$days days ago')" : ""}]
    set xmlMap { & &amp; < &lt; > &gt; \" &quot; ' &apos; }
    
    set content [my rss_head \
                     -channel_title [string map $xmlMap [::$folder_id set title ]] \
                     -description   [string map $xmlMap [::$folder_id set description]] \
                     -link [ad_url][site_node::get_url_from_object_id -object_id $package_id] \
                    ]
    
    db_foreach get_pages \
        "select s.body, p.name, p.creator, p.title, p.page_id,\
                p.object_type as content_type, p.last_modified, p.description  \
        from xowiki_pagex p, syndication s, cr_items i  \
        where i.parent_id = $folder_id and i.live_revision = s.object_id \
                and s.object_id = p.page_id $timerange_clause \
        order by p.last_modified desc $limit_clause \
        " {
          
          if {[string match "::*" $name]} continue
          if {$content_type eq "::xowiki::PageTemplate::"} continue

          set description [string trim $description]
          if {$description eq ""} {set description $body}
          regexp {^([^.]+)[.][0-9]+(.*)$} $last_modified _ time tz
          
          if {$title eq ""} {set title $name}
          #append title " ($content_type)"
          set time "[clock format [clock scan $time] -format {%a, %d %b %Y %T}] ${tz}00"
          append content [my rss_item \
                              -creator [string map $xmlMap $creator] \
                              -title [string map $xmlMap $title] \
                              -link [::$package_id pretty_link -absolute true $name] \
                              -guid [ad_url]/$page_id \
                              -description [string map $xmlMap $description] \
                              -pubdate $time \
                             ]
        }
    
    append content [my rss_tail]
    #set t text/plain
    set t text/xml
    ns_return 200 $t $content
  }
  
  Page proc import {-user_id -package_id -folder_id {-replace 0} -objects} {
    set object_type [self]
    if {![info exists folder_id]}  {set folder_id  [$object_type require_folder -name xowiki]}
    if {![info exists package_id]} {set package_id [ad_conn package_id]}
    if {![info exists user_id]}    {set user_id    [ad_conn user_id]}
    if {![info exists objects]}    {set objects    [$object_type allinstances]}

    set msg "processing objects: $objects<p>"
    set added 0
    set replaced 0
    foreach o $objects {
      $o set parent_id $folder_id
      $o set package_id $package_id
      $o set creation_user $user_id
      # page instances have references to page templates, add these first
      if {[$o istype ::xowiki::PageInstance]} continue
      set item [CrItem lookup -name [$o set name] -parent_id $folder_id]
      if {$item != 0 && $replace} { ;# we delete the original
        ::Generic::CrItem delete -item_id $item
        set item 0
        incr replaced
      }
      if {$item == 0} {
        $o save_new
        incr added
      }
    }

    foreach o $objects {
      if {[$o istype ::xowiki::PageInstance]} {
        db_transaction {
          set item [CrItem lookup -name [$o set name] -parent_id $folder_id]
          if {$item != 0 && $replace} { ;# we delete the original
            ::Generic::CrItem delete -item_id $item
            set item 0
            incr replaced
          }
          if {$item == 0} {  ;# the item does not exist -> update reference and save
            set old_template_id [$o set page_template]
            set template [CrItem lookup \
                              -name [$old_template_id set name] \
                              -parent_id $folder_id]
            $o set page_template $template
            $o save_new
            incr added
          }
        }
      }
      $o destroy
    }
    append msg "$added objects inserted, $replaced objects replaced<p>"
  }

  #
  # conditional links, could go into package as well...
  #
  
  Page instproc make_link {-privilege -url object method args} {
    my instvar package_id
 
    if {[info exists privilege]} {
      set granted [expr {$privilege eq "public" ? 1 :
                 [permission::permission_p \
                      -object_id $package_id -privilege $privilege \
                      -party_id [::xo::cc user_id]] }]
    } else {
      # determine privilege from policy
      set granted [$package_id permission_p $object $method]
      #my log "--p $package_id permission_p $object $method ==> $granted"
    }
    if {$granted} {
      if {[$object istype ::xowiki::Package]} {
        set base  [$package_id package_url]
        if {[info exists url]} {
          return [uplevel export_vars -base [list $base$url] [list $args]]
        } else {
          lappend args [list $method 1]
          return [uplevel export_vars -base [list $base] [list $args]]
        }
      } elseif {[$object istype ::xowiki::Page]} {
        set base [$package_id url]
        lappend args [list m $method]
        return [uplevel export_vars -base [list $base] [list $args]]
      }
    }
    return ""
  }

  #
  # tag management, get_tags works on instance or gobally
  #

  Page proc save_tags {-package_id:required -item_id:required -user_id:required tags} {
    db_dml delete_tags \
        "delete from xowiki_tags where item_id = $item_id and user_id = $user_id"
    foreach tag $tags {
      db_dml insert_tag \
          "insert into xowiki_tags (item_id,package_id, user_id, tag, time) \
           values ($item_id, $package_id, $user_id, :tag, current_timestamp)"
    }
   }
  Page proc get_tags {-package_id:required -item_id -user_id} {
    if {[info exists item_id]} {
      if {[info exists user_id]} {
        # tags for item and user
        set tags [db_list get_tags "SELECT distinct tag from xowiki_tags where user_id=$user_id and item_id=$item_id and package_id=$package_id"]
      } else {
        # all tags for this item 
        set tags [db_list get_tags "SELECT distinct tag from xowiki_tags where item_id=$item_id and package_id=$package_id"]
      }
    } else {
      if {[info exists user_id]} {
        # all tags for this user
        set tags [db_list get_tags "SELECT distinct tag from xowiki_tags where user_id=$user_id and package_id=$package_id"]
      } else {
        # all tags for the package
        set tags [db_list get_tags "SELECT distinct tag from xowiki_tags where package_id=$package_id"]
      }
    }
    join $tags " "
  }


  #
  # Methods of ::xowiki::Page
  #

  Page instforward query_parameter {%my set package_id} %proc
  Page instforward exists_query_parameter {%my set package_id} %proc
  Page instforward form_parameter {%my set package_id} %proc
  Page instforward exists_form_parameter {%my set package_id} %proc

  Page instproc condition {method attr value} {
    switch $attr {
      has_class {return [expr {[my set object_type] eq $value}]}
    }
    return 0
  }

#   Page instproc init {} {    
#     my log "--W "
#     ::xo::show_stack
#     next
#   }

#   Page instproc destroy  {} {
#     my log "--W "
#     ::xo::show_stack
#     next
#   }

  Page instproc initialize_loaded_object {} {
    my instvar title creator
    if {[info exists title] && $title eq ""} {set title [my set name]}
    next
  }

  Page instproc regsub-eval {re string cmd} {
    subst [regsub -all $re [string map { \" \\\" \[ \\[ \] \\] \
                                            \$ \\$ \\ \\\\} $string] \
               "\[$cmd\]"]
  }

  Page instproc include {ch arg} {
    [self class] instvar recursion_depth
    if {[regexp {^adp (.*)$} $arg _ adp]} {
      if {[catch {lindex $adp 0} errMsg]} {
        # there is something syntactically wrong
        return "${ch}Error in '{{$arg}}' in [my set name]<br/>\n\
           Syntax: adp &lt;name of adp-file&gt; {&lt;argument list&gt;}<br/>\n
           Invalid argument list: '$adp'; must be attribute value pairs (even number of elements)"
      }
      set adp [string map {&nbsp; " "} $adp]
      set adp_fn [lindex $adp 0]
      if {![string match "/*" $adp_fn]} {set adp_fn /packages/xowiki/www/$adp_fn}
      set adp_args [lindex $adp 1]
      if {[llength $adp_args] % 2 == 1} {
        return "${ch}Error in '{{$arg}}'<br/>\n\
           Syntax: adp &lt;name of adp-file&gt; {&lt;argument list&gt;}<br/>\n
           Invalid argument list: '$adp_args'; must be attribute value pairs (even number of elements)"
      }
      lappend adp_args __including_page [self]
      set including_page_level [template::adp_level]
      if {[catch {set page [template::adp_include $adp_fn $adp_args]} errorMsg]} {
        # in case of error, reset the adp_level to the previous value
        set ::template::parse_level $including_page_level 
        return "${ch}Error during evaluation of '{{$arg}}' in [my set name]<br/>\n\
           adp_include returned error message: $errorMsg<br>\n"
      }

      return $ch$page
    } else {
      # we have a direct (adp-less include)
      my instvar package_id
      if {[catch {set page_name [lindex $arg 0]} errMsg]} {
        my log "--S arg='$arg'"
        # there is something syntactically wrong
        return "${ch}Error in '{{$arg}}' in [my set name]<br/>\n\
           Syntax: &lt;name of portlet&gt; {&lt;argument list&gt;}<br/>\n
           Invalid argument list: '$arg'; must be attribute value pairs (attribues with dashes)"
      }
      if {[my isclass ::xowiki::portlet::$page_name]} {
        # direct call, without page, not tailorable
        set page [::xowiki::portlet::$page_name new \
                      -package_id $package_id \
                      -name $page_name \
                      -actual_query [::xo::cc actual_query]]
      } else {
        # we include a page, tailorable
        set page [$package_id resolve_page $page_name __m]
        catch {$page set __decoration portlet}
      }
      if {$page ne ""} {
        $page destroy_on_cleanup
        $page set __including_page [self]
        $page set __caller_parameters [lrange $arg 1 end]
        #$page set __decoration portlet
        foreach {att value} [$page set __caller_parameters] {
          switch -- $att {
            -decoration {$page set __decoration $value}
            -title {$page set title $value}
          }
        }
        if {[$page exists __decoration] && [$page set __decoration] ne "plain"} {
          $page mixin add ::xowiki::portlet::decoration=[$page set __decoration]
        }
        return $ch[$page render]
      } else {
        return "${ch} $page_name unknown<br>\n"
      }
    }
  }
  Page instproc div {ch arg} {
    if {$arg eq "content"} {
      return "$ch<div id='content' class='column'>"
    } elseif {[string match left-col* $arg] \
              || [string match right-col* $arg] \
              || $arg eq "sidebar"} {
      return "$ch<div id='$arg' class='column'>"
    } elseif {$arg eq "box"} {
      return "$ch<div class='box'>"
    } elseif {$arg eq ""} {
      return "$ch</div>"
    } else {
      return $ch
    }
  }
  Page instproc anchor {ch arg} {
    set label $arg
    set link $arg
    regexp {^(.*)[|](.*)$} $arg _ link label
    if {[string match "http*//*" $link] || [string match "/*" $link]} {
      return "$ch<a class='external' href='$link'>$label</a>"
    }

    set name ""
    my instvar parent_id package_id
    # do we have a language link (it starts with a ':')
    if {[regexp {^:(..):(.*)$} $link _ lang stripped_name]} {
      set link_type language
    } elseif {[regexp {^(file|image):(.*)$} $link _ link_type stripped_name]} {
      set lang ""
      set name $link
    } else {
      # do we have a typed link?
      if {![regexp {^([^:][^:][^:]+):((..):)?(.+)$} $link _ link_type _ lang  stripped_name]} {
        # must be an untyped link; defaults, in case the second regexp does not match either
        set lang ""
        set link_type link
        set stripped_name $link
        regexp {^(..):(.+)$} $link _ lang stripped_name
      }
    }
    set normalized_name [::$package_id normalize_name $stripped_name]
    if {$lang  eq ""}   {set lang [my lang]}
    if {$name  eq ""}   {set name $lang:$normalized_name}
    if {$label eq $arg} {set label $stripped_name}

    Link create [self]::link \
        -page [self] \
        -type $link_type -name $name -lang $lang \
        -stripped_name $normalized_name -label $label \
        -folder_id $parent_id -package_id $package_id
    return $ch[[self]::link render]
  }

  Page instproc references {} {
    [my info class] instvar table_name
    my instvar item_id
    set refs [list]
    db_foreach references "SELECT page,ci.name,link_type,f.package_id \
        from xowiki_references,cr_items ci,cr_folders f \
        where reference=$item_id and ci.item_id = page and ci.parent_id = f.folder_id" {
          ::xowiki::Package require $package_id
          lappend refs "<a href='[::$package_id pretty_link $name]'>$name</a>"
        }
    join $refs ", "
  }

  Page instproc substitute_markup {source} {
    set baseclass [expr {[[my info class] exists RE] ? [my info class] : [self class]}]
    $baseclass instvar RE
    #my log "-- baseclass for RE = $baseclass"
    if {[my set mime_type] eq "text/enhanced"} {
      set source [ad_enhanced_text_to_html $source]
    }
    set content ""
    set l " "; #use one byte trailer for regexps for escaped content
    foreach l0 [split [lindex $source 0] \n] {
      append l $l0
      if {[string first \{\{ $l] > -1 && [string first \}\} $l] == -1} continue
      set l [my regsub-eval $RE(anchor)  $l {my anchor  "\1" "\2"}]
      set l [my regsub-eval $RE(div)     $l {my div     "\2" "\3"}]
      set l [my regsub-eval $RE(include) $l {my include "\1" "\2"}]
      regsub -all $RE(clean) $l {\1} l
      regsub -all $RE(clean2) $l { \1} l
      append content [string range $l 1 end] \n
      set l " "
    }
    return $content
  }

  Page instproc adp_subst {content} {
    set __ignorelist [list RE __defaults name_method object_type_key]
    foreach __v [my info vars] {
      if {[info exists $__v]} continue
      my instvar $__v
    }
    foreach __v [[my info class] info vars] {
      if {[lsearch -exact $__ignorelist $__v]>-1} continue
      if {[info exists $__v]} continue
      [my info class] instvar $__v
    }
    set __ignorelist [list __v __ignorelist __varlist __template_variables__ \
                          text item_id content]
    set __varlist [list]
    set __template_variables__ "<ul>\n"
    foreach __v [lsort [info vars]] {
      if {[lsearch -exact $__ignorelist $__v]>-1} continue
      lappend __varlist $__v
      append __template_variables__ "<li><b>$__v:</b> '[set $__v]'\n"
    }
    append __template_variables__ "</ul>\n"
    regsub -all [template::adp_variable_regexp] $content {\1@\2;noquote@} content
    set template_code [template::adp_compile -string $content]
    #my log "--pl before adp_eval '[template::adp_level]'"
    set my_parse_level [template::adp_level]
    if {[catch {set template_value [template::adp_eval template_code]} errmsg]} {
      set ::template::parse_level $my_parse_level 
      #my log "--pl after adp_eval '[template::adp_level]' mpl=$my_parse_level"
      return "Error in Page $name: $errmsg<br>$content<p>Possible values are$__template_variables__"
    }
    return $template_value
  }

  Page instproc get_content {} {
    #my log "--"
    set content [my substitute_markup [my set text]]
  }
  Page instproc set_content {text} {
    my text [list [string map [list >> "\n<br />&gt;&gt;" << "&lt;&lt;\n"] \
                       [string trim $text " \n"]] text/html]
  }

  Page instproc get_rich_text_spec {field_name default} {
    set spec ""
    foreach {s widget_spec} [[my set parent_id] get_payload widget_specs] {
      foreach {page_name var_name} [split $s ,] break
      # in case we have no name (edit new page) we use the first value or the default.
      set name [expr {[my exists name] ? [my set name] : $page_name}]
      #ns_log notice "--w T.name = '[my set name]' var=$page_name, $var_name $field_name []"
      if {[string match $page_name $name] &&
          [string match $var_name $field_name]} {
        set spec $widget_spec
        break
      }
    }
    if {$spec eq ""} {return $default}
    return $field_name:$spec
  }

  Page instproc update_references {page_id references} {
    db_dml delete_references \
        "delete from xowiki_references where page = $page_id"
    foreach ref $references {
      foreach {r link_type} $ref break
      db_dml insert_reference \
          "insert into xowiki_references (reference, link_type, page) \
           values ($r,:link_type,$page_id)"
    }
   }

  Page instproc render {-update_references:switch} {
    my instvar item_id references lang render_adp unresolved_references parent_id
    #my log "-- my class=[my info class]"

    set name [my set name]
    regexp {^(..):(.*)$} $name _ lang name
    set references [list]
    set unresolved_references 0
    #my log "--W setting unresolved_references to 0  [info exists unresolved_references]"
    set content [my get_content]
    #my log "--W after content [info exists unresolved_references] [my exists unresolved_references] ?? [info vars]"
    if {$update_references || $unresolved_references > 0} {
      my update_references $item_id [lsort -unique $references]
    }
    if {![my exists lang_links]} {
      #my log "-- for some reason, no lang links"
      my set lang_links ""
    } else {
      my set lang_links [join [my set lang_links] ", "]
    }
    return [expr {$render_adp ? [my adp_subst $content] : $content}]
  }


  Page instproc record_last_visited {-user_id} {
    my instvar item_id package_id
    if {![info exists user_id]} {set user_id [ad_conn user_id]}
    if {$user_id > 0} {
      # only record information for authenticated users
      db_dml update_last_visisted \
          "update xowiki_last_visited set time = current_timestamp, count = count + 1 \
           where page_id = $item_id and user_id = $user_id"
      if {[db_resultrows] < 1} {
        db_dml insert_last_visisted \
            "insert into xowiki_last_visited (page_id, package_id, user_id, count, time) \
             values ($item_id, $package_id, $user_id, 1, current_timestamp)"
      }
    }
  }

  #
  # Methods of ::xowiki::PlainPage
  #

  PlainPage parameter {
    {render_adp 0}
  }
  PlainPage array set RE {
    include {([^\\]){{(.+)}}[ \n\r]}
    anchor  {([^\\])\\\[\\\[([^\]]+)\\\]\\\]}
    div     {()([^\\])>>([^<]*)<<}
    clean   {[\\](\{\{|>>|\[\[)}
    clean2  {(--DUMMY NOT USED--)}
  }

  PlainPage instproc get_content {} {
    #my log "-- my class=[my info class]"
    return [my substitute_markup [my set text]]
  }
  PlainPage instproc set_content {text} {
    my text $text
  }

  PlainPage instproc substitute_markup {source} {
    [self class] instvar RE
    set content ""
    foreach l [split $source \n] {
      set l " $l"
      set l [my regsub-eval $RE(anchor)  $l {my anchor  "\1" "\2"}]
      set l [my regsub-eval $RE(div)     $l {my div     "\2" "\3"}]
      set l [my regsub-eval $RE(include) $l {my include "\1" "\2"}]
      regsub -all $RE(clean) $l {\1} l
      append content [string range $l 1 end] \n
    }
    return $content
  }

  #
  # Methods of ::xowiki::File
  #

  File parameter {
    {render_adp 0}
  }
  File instproc full_file_name {} {
    if {![my exists full_file_name]} {
      if {[my exists item_id]} {
        my instvar text mime_type package_id item_id revision_id
        set storage_area_key [db_string get_storage_key \
                  "select storage_area_key from cr_items where item_id=$item_id"]
        my set full_file_name [cr_fs_path $storage_area_key]/$text
        #my log "--F setting FILE=[my set full_file_name]"
      }
    }
    return [my set full_file_name]
  }
    
  File instproc get_content {} {
    my instvar name mime_type description parent_id package_id creation_user
    # don't require permissions here, such that rss can present the link
    set page_link [my make_link -privilege public [self] download ""]
    #my log "--F page_link=$page_link ---- "
    set t [TableWidget new -volatile \
               -columns {
                 AnchorField name -label [_ xowiki.name]
                 Field mime_type -label [_ xowiki.page_type]
                 Field last_modified -label "Last Modified"
                 Field mod_user -label "By User"
                 Field size -label "Size"
               }]

    regsub {[.][0-9]+([^0-9])} [my set last_modified] {\1} last_modified
    regexp {^([^:]+):(.*)$} $name _ link_type stripped_name
    set label $stripped_name

    $t add \
        -name $stripped_name \
        -mime_type $mime_type \
        -name.href $page_link \
        -last_modified $last_modified \
        -mod_user [::xo::get_user_name $creation_user] \
        -size [file size [my full_file_name]]

    if {$link_type eq "image"} {
      set l [Link new -volatile \
                 -page [self] \
                 -type $link_type -name $name -lang "" \
                 -stripped_name $stripped_name -label $label \
                 -folder_id $parent_id -package_id $package_id]
      set image "<div >[$l render]</div>"
    } else {
      set image ""
    }
    return "$image<p>[$t asHTML]</p>\n<p>$description</p>"
  }

  #
  # PageTemplate specifics
  #
  PageTemplate parameter {
    {render_adp 0}
  }

  #
  # PageInstance methods
  #
  PageInstance instproc get_field_type {name template default_spec} {
    # get the widget field specifications from the payload of the folder object
    # for a field with a specified name in a specified page template
    set spec $default_spec
    foreach {s widget} [[my set parent_id] get_payload widget_specs] {
      foreach {template_name var_name} [split $s ,] break
      #ns_log notice "--w T.title = '[$template set name]' var=$name"
      if {[string match $template_name [$template set name]] &&
          [string match $var_name $name]} {
        set spec $widget
        #ns_log notice "--w using $widget for $name"
      }
    }
    #ns_log notice "--w returning spec $spec"
    return $spec
  }

  PageInstance instproc get_content {} {
    my instvar page_template
    #my log  "-- fetching page_template = $page_template"
    ::Generic::CrItem instantiate -item_id $page_template
    $page_template destroy_on_cleanup
    #if {[my set instance_attributes] eq ""} {
    #  set T [my adp_subst [$page_template set text]]
    #  return [my substitute_markup $T]
    #}
    set T [my adp_subst [$page_template set text]]
    return [my substitute_markup $T]
  }
  PageInstance instproc adp_subst {content} {
    my instvar page_template
    #my log "--r page_template exists? $page_template: [info command $page_template]"
    # add extra variables as instance variables
    array set __ia [my set instance_attributes]
    foreach var [array names __ia] {
      #my log "-- set $var [list $__ia($var)]"
      if {[string match "richtext*" [my get_field_type $var $page_template text]]} {
        # ignore the text/html info from htmlarea
        my set $var [lindex $__ia($var) 0]
      } else {
        my set $var $__ia($var)
      }
    }
    next
  }

  #
  # Methods of ::xowiki::Object
  #

  Object instproc get_content {} {
    if {[[self]::payload info methods content] ne ""} {
      return  [my substitute_markup [[self]::payload content]]
    } else {
      return "<pre>[string map {> &gt; < &lt;} [my set text]]</pre>"
    }
  }

  Object instproc initialize_loaded_object {} {
    my set_payload [my set text]
    next
  }
  Object instproc set_payload {cmd} {
    set payload [self]::payload
    if {[my isobject $payload]} {$payload destroy}
    ::xo::Context create $payload -requireNamespace \
        -actual_query [::xo::cc actual_query]
    $payload set package_id [my set package_id]
    if {[catch {$payload contains $cmd} error ]} {
      ns_log error "content $cmd lead to error: $error"
    }
  }
  Object instproc get_payload {var {default ""}} {
    set payload [self]::payload
    if {![my isobject $payload]} {
      ::xo::Context create $payload -requireNamespace
    }
    expr {[$payload exists $var] ? [$payload set $var] : $default}
  }

}

source [file dirname [info script]]/xowiki-www-procs.tcl
