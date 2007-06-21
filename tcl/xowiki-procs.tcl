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
        if {[::xo::db::has_ltree]} {
          ::Generic::Attribute new -attribute_name page_order -datatype text \
              -pretty_name "Order" -sqltype ltree
        }
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

  ::Generic::CrClass create PodcastItem -superclass File \
      -pretty_name "Podcast Item" -pretty_plural "Podcast Items" \
      -table_name "xowiki_podcast_item" -id_column "podcast_item_id" \
      -cr_attributes {
          ::Generic::Attribute new -attribute_name pub_date -datatype date -sqltype timestamp \
              -pretty_name "Publication Date"
          ::Generic::Attribute new -attribute_name duration -datatype text \
              -pretty_name "Duration"
          ::Generic::Attribute new -attribute_name subtitle -datatype text \
              -pretty_name "Subtitle"
          ::Generic::Attribute new -attribute_name keywords -datatype text \
              -pretty_name "Keywords"
      } \
      -storage_type file \
      -form ::xowiki::PodcastForm

  ::Generic::CrClass create PageTemplate -superclass Page \
      -pretty_name "XoWiki Page Template" -pretty_plural "XoWiki Page Templates" \
      -table_name "xowiki_page_template" -id_column "page_template_id" \
      -cr_attributes {
        ::Generic::Attribute new -attribute_name anon_instances -datatype boolean \
            -sqltype boolean -default "f" \
            -pretty_name "#xowiki.PageTemplate-anon_instances#"
      } \
      -form ::xowiki::PageTemplateForm

  ::Generic::CrClass create PageInstance -superclass Page \
      -pretty_name "XoWiki Page Instance" -pretty_plural "XoWiki Page Instances" \
      -table_name "xowiki_page_instance" -id_column "page_instance_id" \
      -cr_attributes {
        ::Generic::Attribute new -attribute_name page_template -datatype integer \
            -pretty_name "Page Template"
        ::Generic::Attribute new -attribute_name instance_attributes -datatype text \
            -pretty_name "Instance Attributes" -default ""
      } \
      -form ::xowiki::PageInstanceForm \
      -edit_form ::xowiki::PageInstanceEditForm

  ::Generic::CrClass create Object -superclass PlainPage \
      -pretty_name "XoWiki Object" -pretty_plural "XoWiki Objects" \
      -table_name "xowiki_object" -id_column "xowiki_object_id" \
      -mime_type text/xotcl \
      -form ::xowiki::ObjectForm

  ::Generic::CrClass create Form -superclass PageTemplate \
      -pretty_name "XoWiki Form" -pretty_plural "XoWiki Forms" \
      -table_name "xowiki_form" -id_column "xowiki_form_id" \
      -cr_attributes {
        ::Generic::Attribute new -attribute_name form -datatype text \
            -pretty_name "#xowiki.Form-form#"
        ::Generic::Attribute new -attribute_name form_constraints -datatype text \
            -pretty_name "#xowiki.Form-form_constraints#"
      } \
      -form ::xowiki::FormForm
  ::Generic::CrClass create FormInstance -superclass PageInstance \
      -pretty_name "XoWiki FormInstance" -pretty_plural "XoWiki FormInstances" \
      -table_name "xowiki_form_instance" -id_column "xowiki_form_instance_id" \
      -form ::xowiki::FormInstanceEditForm

  #
  # create various extra tables, indices and views
  #
  ::xo::db::require table xowiki_references \
        "reference integer references cr_items(item_id) on delete cascade,
         link_type [::xo::db::sql map_datatype text],
         page      integer references cr_items(item_id) on delete cascade"
  ::xo::db::require index -table xowiki_references -col reference


  ::xo::db::require table xowiki_last_visited \
       "page_id integer references cr_items(item_id) on delete cascade,
        package_id integer,
        user_id integer,
        count   integer,
        time    timestamp"
  ::xo::db::require index -table xowiki_last_visited -col user_id,page_id -unique true
  ::xo::db::require index -table xowiki_last_visited -col user_id,package_id
  ::xo::db::require index -table xowiki_last_visited -col time


  ::xo::db::require table xowiki_tags \
       "item_id integer references cr_items(item_id) on delete cascade,
        package_id integer,
        user_id integer references users(user_id),
        tag     [::xo::db::sql map_datatype text],
        time    timestamp"
  ::xo::db::require index -table xowiki_tags -col user_id,item_id
  ::xo::db::require index -table xowiki_tags -col tag,package_id


  if {[::xo::db::has_ltree]} {
    ::xo::db::require index -table xowiki_page -col page_order -using gist
  }

  set sortkeys [expr {[db_driverkey ""] eq "oracle" ? "" : ", ci.tree_sortkey, ci.max_child_sortkey"}]
  ::xo::db::require view xowiki_page_live_revision \
      "select p.*, cr.*,ci.parent_id, ci.name, ci.locale, ci.live_revision, \
	  ci.latest_revision, ci.publish_status, ci.content_type, ci.storage_type, \
	  ci.storage_area_key $sortkeys \
          from xowiki_page p, cr_items ci, cr_revisions cr  \
          where p.page_id = ci.live_revision \
            and p.page_id = cr.revision_id  \
            and ci.publish_status <> 'production'"

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
    {lang en}
    {render_adp 1}
    {absolute_links 0}
    page_order
  }
  Page set recursion_count 0
  Page array set RE {
    include {([^\\]){{([^<]+?)}}(\s|<|$)?}
    anchor  {([^\\])\\\[\\\[([^\]]+?)\\\]\\\]}
    div     {()([^\\])&gt;&gt;([^&<]*?)&lt;&lt;()([ \n]*<br */?>)?}
    clean   {[\\](\{\{|&gt;&gt;|\[\[)}
    clean2  { <br */?> *(<div)}
  }

  #
  # templating and CSS
  #

  Page proc requireCSS name {set ::need_css($name) 1}
  Page proc requireJS  name {
    if {![info exists ::need_js($name)]} {lappend ::js_order $name}
    set ::need_js($name)  1
  }
  Page proc header_stuff {} {
    set result ""
    foreach file [array names ::need_css] {
      append result "<link rel='stylesheet' href='$file' media='all' />\n"
    }
    if {[info exists ::js_order]} {
      foreach file $::js_order  {
        append result "<script language='javascript' src='$file' type='text/javascript'>" \
          "</script>"
      }
    }
    return $result
  }
  Page proc quoted_html_content text {
    list [ad_text_to_html $text] text/html
  }

  #
  # Operations on the whole instance
  #

  Page ad_proc select_query {
    {-select_attributes ""}
    {-orderby ""}
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
    @param orderby clause for ordering the solution set
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
      set orderby ""      ;# no need to order when we count
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
    set outer_join [expr {[string first s. $attribute_selection] > -1 ?
                          "left outer join syndication s on s.object_id = p.revision_id" : ""}]
    set order_clause [expr {$orderby ne "" ? "ORDER BY $orderby" : ""}]
    set sql "select $attribute_selection from xowiki_pagei p $outer_join, cr_items ci \
        $extra_from_clause \
        where ci.parent_id = $folder_id and ci.item_id = p.item_id and \
        ci.live_revision = p.page_id $where_clause $extra_where_clause $order_clause $pagination"
    #my log "--SQL=$sql"
    return $sql
  }

  #
  # Page marshall/demarshall
  #


  Page instproc marshall {} {
    my instvar name
    if {[regexp {^..:[0-9]+$} $name] ||
        [regexp {^[0-9]+$} $name]} {
      #
      # for anonymous entries, names might clash in the target
      # instance. If we create on the target site for anonymous
      # entries always new instances, we end up with duplicates.
      # Therefore, we rename anonymous entries during export to
      #    ip_address:port/item_id
      #
      set old_name $name
      set server [ns_info server]
      set port [ns_config ns/server/${server}/module/nssock port]
      set name [ns_info address]:${port}/[my item_id]
      set content [my serialize]
      set name $old_name
    } else {
      set content [my serialize]
    }
    return $content
  }

  File instproc marshall {} {
    set fn [my full_file_name]
    set F [open $fn]
    fconfigure $F -translation binary
    set C [read $F]
    close $F
    my set __file_content [::base64::encode $C]
    next
  }

  Page instproc demarshall {-parent_id -package_id -creation_user} {
    # this method is the counterpart of marshall
    my set parent_id $parent_id
    my set package_id $package_id 
    my set creation_user $creation_user
    # in the general case, no more actions required
  }

  File instproc demarshall {args} {
    next
    # we have to care about recoding the file content
    my instvar import_file __file_content
    set import_file [ns_tmpnam]
    set F [open $import_file w]
    fconfigure $F -translation binary
    puts -nonewline $F [::base64::decode $__file_content]
    close $F
  }

  Page instproc copy_content_vars {-from_object:required} {
    array set excluded_var {
      folder_id 1 package_id 1 absolute_links 1 lang_links 1 
      publish_status 1 item_id 1 revision_id 1 last_modified 1 parent_id 1
    }
    foreach var [$from_object info vars] {
      if {![info exists excluded_var($var)]} {
        my set $var [$from_object set $var]
      }
    }
  }

  Page proc import {-user_id -package_id -folder_id {-replace 0} -objects} {
    my log "DEPRECATED"
    if {![info exists package_id]}  {set package_id  [::xo::cc package_id]}
    set cmd  [list $package_id import -replace $replace]
    
    if {[info exists user_id]}   {lappend cmd -user_id $user_id}
    if {[info exists objects]}   {lappend cmd -objects $objects}
    eval $cmd
  }

  #
  # tag management, get_tags works on instance or gobally
  #

  Page proc save_tags {-package_id:required -item_id:required -user_id:required tags} {
    db_dml [my qn delete_tags] \
        "delete from xowiki_tags where item_id = $item_id and user_id = $user_id"
    foreach tag $tags {
      db_dml [my qn insert_tag] \
          "insert into xowiki_tags (item_id,package_id, user_id, tag, time) \
           values ($item_id, $package_id, $user_id, :tag, current_timestamp)"
    }
   }
  Page proc get_tags {-package_id:required -item_id -user_id} {
    if {[info exists item_id]} {
      if {[info exists user_id]} {
        # tags for item and user
        set tags [db_list [my qn get_tags] \
               "SELECT distinct tag from xowiki_tags \
		where user_id=$user_id and item_id=$item_id and package_id=$package_id"]
      } else {
        # all tags for this item 
        set tags [db_list [my qn get_tags] \
                "SELECT distinct tag from xowiki_tags \
		where item_id=$item_id and package_id=$package_id"]
      }
    } else {
      if {[info exists user_id]} {
        # all tags for this user
        set tags [db_list [my qn get_tags] \
                "SELECT distinct tag from xowiki_tags \
                 where user_id=$user_id and package_id=$package_id"]
      } else {
        # all tags for the package
        set tags [db_list [my qn get_tags] \
                "SELECT distinct tag from xowiki_tags \
                 where package_id=$package_id"]
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

  Page instproc complete_name {name {nls_language ""}} {
    if {![regexp {^..:} $name]} {
      if {$name ne ""} {
        # prepend the language prefix only, if the entry is not empty
        if {$nls_language eq ""} {set nls_language [my set nls_language]}
        set name [string range $nls_language 0 1]:$name
      }
    }
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
    my instvar title
    if {[info exists title] && $title eq ""} {set title [my set name]}
    next
  }

  Page instproc regsub-eval {re string cmd} {
    subst [regsub -all $re [string map { \" \\\" \[ \\[ \] \\] \
                                            \$ \\$ \\ \\\\} $string] \
               "\[$cmd\]"]
  }

  Page instproc include_portlet {arg} {
    # we want to use package_id as proc-local variable, since the 
    # cross package reference might alter it locally
    set package_id [my package_id]

    # do we have a wellformed list?
    if {[catch {set page_name [lindex $arg 0]} errMsg]} {
      #my log "--S arg='$arg'"
      # there is something syntactically wrong
      return "<div class='errorMsg'>Error in '{{$arg}}' in [my set name] ($errMsg)<br/>\n\
           Syntax: &lt;name of portlet&gt; {&lt;argument list&gt;}<br/>\n
           Invalid argument list: '$arg'; must be attribute value pairs (attribues with dashes)</div>"
    }

    # the include is either a portlet class, or a wiki page
    if {[my isclass ::xowiki::portlet::$page_name]} {
      # direct call, without page, not tailorable
      set page [::xowiki::portlet::$page_name new \
		    -package_id $package_id \
		    -name $page_name \
		    -actual_query [::xo::cc actual_query]]
    } else {
      # we include a wiki page, tailorable
      set page [$package_id resolve_page $page_name __m]
      if {[regexp {^/(/[^?]*)[?]?(.*)$} $page_name _ url query]} {
        # here we handle cross package xowiki includes
        ::xowiki::Package initialize -parameter {{-m view}} -url $url \
            -actual_query $query
        if {$package_id != 0} {
          set page [$package_id resolve_page [$package_id set object] __m]
        }
        #my log "--resolve --> $page"
      }
      if {$page ne "" && ![$page exists __decoration]} {
        $page set __decoration portlet
      }
    }

    if {$page ne ""} {
      my set __last_includelet $page
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
      if {[$page exists __decoration] && [$page set __decoration] ne "none"} {
	$page mixin add ::xowiki::portlet::decoration=[$page set __decoration]
      }

      if {[catch {set html [$page render]} errorMsg]} {
        set html "<div class='errorMsg'><p>Error in includelet '$page_name' $errorMsg\
           <pre>$::errorInfo</pre></div>\n"
      }
      #my log "--include portlet returns $html"
      return $html
    } else {
      return "<div class='errorMsg'><p>Error: includelet '$page_name' unknown</div>\n"
    }
  }

  Page instproc include {ch arg ch2} {
    [self class] instvar recursion_depth
    if {[regexp {^adp (.*)$} $arg _ adp]} {
      if {[catch {lindex $adp 0} errMsg]} {
        # there is something syntactically wrong
        return "${ch}<div class='errorMsg'>Error in '{{$arg}}' in [my set name] ($errMsg)<br/>\n\
           Syntax: adp &lt;name of adp-file&gt; {&lt;argument list&gt;}<br/>\n
           Invalid argument list: '$adp'; must be attribute value pairs (even number of elements)</div>"
      }
      set adp [string map {&nbsp; " "} $adp]
      set adp_fn [lindex $adp 0]
      if {![string match "/*" $adp_fn]} {set adp_fn /packages/xowiki/www/$adp_fn}
      set adp_args [lindex $adp 1]
      if {[llength $adp_args] % 2 == 1} {
        return "${ch}<div class='errorMsg'>Error in '{{$arg}}'<br/>\n\
           Syntax: adp &lt;name of adp-file&gt; {&lt;argument list&gt;}<br/>\n
           Invalid argument list: '$adp_args'; must be attribute value pairs (even number of elements)</div>"
      }
      lappend adp_args __including_page [self]
      set including_page_level [template::adp_level]
      if {[catch {set page [template::adp_include $adp_fn $adp_args]} errorMsg]} {
        # in case of error, reset the adp_level to the previous value
        set ::template::parse_level $including_page_level 
        return "${ch}<div class='errorMsg'>Error during evaluation of '{{$arg}}' in [my set name]<br/>\n\
           adp_include returned error message: $errorMsg</div>\n"
      }

      return $ch$page$ch2
    } else {
      # we have a direct (adp-less include)
      # Some browsers change {{cmd -flag "..."}} into {{cmd -flag &quot;...&quot;}}
      # We have to change this back
      regsub -all {([^\\])&quot;}  $arg "\\1\"" arg
      set html [my include_portlet $arg]
      #my log "--include portlet returns $html"
      return $ch$html$ch2
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
    set options ""
    regexp {^([^|]+)[|](.*)$} $arg _ link label
    regexp {^([^|]+)[|](.*)$} $label _ label options
    if {[string match "http*//*" $link] || [string match "//*" $link]} {
      regsub {^//} $link / link
      set l [ExternalLink new -label $label -href $link]
      eval $l configure $options
      set html [$l render]
      $l destroy
      return "$ch$html"
    }

    set name ""
    my instvar parent_id package_id
    # do we have a language link (it starts with a ':')
    if {[regexp {^:(..):(.*)$} $link _ lang stripped_name]} {
      set link_type language
    } elseif {[regexp {^(file|image|swf):(.*)$} $link _ link_type stripped_name]} {
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
    
    if {[catch {eval [self]::link configure $options} error]} {
      return "${ch}<div class='errorMsg'>Error during processing of options: $error</div>"
    } else {
      return $ch[[self]::link render]
    }
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
      set l [my regsub-eval $RE(include) $l {my include "\1" "\2" "\3"}]
      regsub -all $RE(clean) $l {\1} l
      regsub -all $RE(clean2) $l { \1} l
      append content [string range $l 1 end] \n
      set l " "
    }
    #my log "--substitute_markup returns $content"
    return $content
  }

  Page instproc adp_subst {content} {
    #my log "--adp_subst in [my name]"
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
                          text item_id content lang_links]
    set __varlist [list]
    set __template_variables__ "<ul>\n"
    foreach __v [lsort [info vars]] {
      if {[lsearch -exact $__ignorelist $__v]>-1} continue
      lappend __varlist $__v
      append __template_variables__ "<li><b>$__v:</b> '[set $__v]'\n"
    }
    append __template_variables__ "</ul>\n"
    regsub -all [template::adp_variable_regexp] $content {\1@\2;noquote@} content
    #my log "--adp before adp_eval '[template::adp_level]'"
    #
    # The adp buffer has limited size. For large pages, it might happen
    # that the buffer overflows. In Aolserver 4.5, we can increase the
    # buffer size. In 4.0.10, we are out of luck.
    #
    set l [string length $content]
    if {[catch {set bufsize [ns_adp_ctl bufsize]}]} {
      set bufsize 0
    }
    if {$bufsize > 0 && $l > $bufsize} {
      # we have aolserver 4.5, we can increase the bufsize
      ns_adp_ctl bufsize [expr {$l + 1024}]
    }
    set template_code [template::adp_compile -string $content]
    set my_parse_level [template::adp_level]
    if {[catch {set template_value [template::adp_eval template_code]} errMsg]} {
      set ::template::parse_level $my_parse_level 
      #my log "--adp after adp_eval '[template::adp_level]' mpl=$my_parse_level"
      return "<div class='errorMsg'>Error in Page $name: $errMsg</div>$content<p>Possible values are$__template_variables__"
    }
    return $template_value
  }

  Page instproc get_description {content} {
    my instvar revision_id
    set description [my set description]
    if {$description eq "" && $content ne ""} {
      set description [ad_html_text_convert -from text/html -to text/plain -- $content]
    }
    if {$description eq "" && $revision_id > 0} {
      set description [db_string [my qn get_description_from_syndication] \
                           "select body from syndication where object_id = $revision_id" \
                           -default ""]
    }
    return $description
  }

  Page instproc get_content {} {
    #my log "--"
    return [my substitute_markup [my set text]]
  }
  Page instproc set_content {text} {
    my text [list [string map [list >> "\n<br />&gt;&gt;" << "&lt;&lt;\n"] \
                       [string trim $text " \n"]] text/html]
  }

  Page instproc get_rich_text_spec {field_name default} {
    my instvar package_id
    set spec ""
    foreach {s widget_spec} [$package_id get_parameter widget_specs] {
      foreach {page_name var_name} [split $s ,] break
      # in case we have no name (edit new page) we use the first value or the default.
      set name [expr {[my exists name] ? [my set name] : $page_name}]
      #ns_log notice "--w T.name = '$name' var=$page_name, $var_name $field_name "
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
    db_dml [my qn delete_references] \
        "delete from xowiki_references where page = $page_id"
    foreach ref $references {
      foreach {r link_type} $ref break
      db_dml [my qn insert_reference] \
          "insert into xowiki_references (reference, link_type, page) \
           values ($r,:link_type,$page_id)"
    }
   }

  Page proc container_already_rendered {field} {
    if {![info exists ::xowiki_page_item_id_rendered]} {
      return ""
    }
    my log "--OMIT and not $field in ([join $::xowiki_page_item_id_rendered ,])"
    return "and not $field in ([join $::xowiki_page_item_id_rendered ,])"
  }

  Page instproc footer {} {
    return ""
  }

  Page instproc render {-update_references:switch} {
    my instvar item_id revision_id references lang render_adp unresolved_references parent_id
    my array set lang_links {found "" undefined ""}
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
    set html [expr {$render_adp ? [my adp_subst $content] : $content}]
    if {![my exists __no_footer]} {append html [my footer]}
    return $html
  }

  Page instproc record_last_visited {-user_id} {
    my instvar item_id package_id
    if {![info exists user_id]} {set user_id [ad_conn user_id]}
    if {$user_id > 0} {
      # only record information for authenticated users
      db_dml [my qn update_last_visisted] \
          "update xowiki_last_visited set time = current_timestamp, count = count + 1 \
           where page_id = $item_id and user_id = $user_id"
      if {[db_resultrows] < 1} {
        db_dml [my qn insert_last_visisted] \
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
    include {([^\\]){{(.+?)}}[ \n\r]}
    anchor  {([^\\])\\\[\\\[([^\]]+?)\\\]\\\]}
    div     {()([^\\])>>([^<]*?)<<}
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
      set l [my regsub-eval $RE(include) $l {my include "\1" "\2" ""}]
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
  File instproc complete_name {name {fn ""}} {
    my instvar mime_type package_id
    switch -glob -- $mime_type {
      image/* {set type image}
      default {set type file}
    }
    if {$name ne ""} {
      set stripped_name $name
      regexp {^(.*):(.*)$} $name _ _t stripped_name
    } else {
      set stripped_name $fn
    }
    return ${type}:[::$package_id normalize_name $stripped_name]
  }
  File instproc full_file_name {} {
    if {![my exists full_file_name]} {
      if {[my exists item_id]} {
        my instvar text mime_type package_id item_id revision_id
        set storage_area_key [db_string [my qn get_storage_key] \
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
    set page_link [$package_id make_link -privilege public [self] download ""]
    #my log "--F page_link=$page_link ---- "
    set t [TableWidget new -volatile \
               -columns {
                 AnchorField name -label [_ xowiki.name]
                 Field mime_type -label "Content Type"
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

  PodcastItem instproc get_content {} {
    set content [next]
    append content <ul>
    foreach i {title subtitle creator pub_date duration keywords} {
      append content "<li><em>$i:</em> [my set $i]\n"
    }
    append content </ul>
    return $content
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

  PageInstance instproc get_short_spec {name} {
    my instvar page_template
    if {[$page_template exists form_constraints]} {
      foreach name_and_spec [$page_template form_constraints] {
        foreach {spec_name short_spec} [split $name_and_spec :] break
        if {$spec_name eq $name} {
          return $short_spec
        }
      }
    }
    return ""
  }
  PageInstance instproc get_field_label {name value} {
    set short_spec [my get_short_spec $name]
    if {$short_spec ne ""} {
      set f [FormField new -volatile -name $name -spec $short_spec]
      return [$f renderValue $value]
    }
    return $value
  }
  PageInstance instproc get_field_type {name default_spec} {
    my instvar page_template
    # get the widget field specifications from the payload of the folder object
    # for a field with a specified name in a specified page template
    set spec $default_spec
    set short_spec [my get_short_spec $name]
    if {$short_spec ne ""} {
      set f [FormField new -volatile -name $name -spec $short_spec]
      return [$f asWidgetSpec]
    }
    set given_template_name [$page_template set name]
    foreach {s widget} [[my set parent_id] get_payload widget_specs] {
      foreach {template_name var_name} [split $s ,] break
      #ns_log notice "--w T.title = '$given_template_name' var=$name"
      if {([string match $template_name $given_template_name] || $given_template_name eq "") &&
          [string match $var_name $name]} {
        set spec $widget
        #ns_log notice "--w using $widget for $name"
      }
    }
    #ns_log notice "--w returning spec $spec"
    return $spec
  }

  PageInstance instproc get_from_template {var} {
    my instvar page_template
    #my log  "-- fetching page_template = $page_template"
    ::Generic::CrItem instantiate -item_id $page_template
    $page_template destroy_on_cleanup
    return [$page_template set $var]
  }

  PageInstance instproc get_content {} {
    set raw_template [my get_from_template text]
    set T  [my adp_subst [lindex $raw_template 0]]
    return [my substitute_markup [list $T [lindex $raw_template 1]]]
  }
  PageInstance instproc template_vars {content} {
    set result [list]
    foreach {_ _ v} [regexp -inline -all [template::adp_variable_regexp] $content] {
      lappend result $v ""
    }
    return $result
  }
  PageInstance instproc adp_subst {content} {
    # initialize template variables (in case, new variables are added to template)
    array set __ia [my template_vars $content]
    # add extra variables as instance attributes
    array set __ia [my set instance_attributes]
    foreach var [array names __ia] {
      #my log "-- set $var [list $__ia($var)]"
      if {[string match "richtext*" [my get_field_type $var text]]} {
        # ignore the text/html info from htmlarea
	set value [lindex $__ia($var) 0]
      } else {
	set value $__ia($var)
      }
      # the value might not be from the form attributes (e.g. title), don't clear it.
      if {$value eq "" && [my exists $var]} continue
      my set $var [my get_field_label $var $value]
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
    #my log "call init mixins=[my info mixin]//[$payload info mixin]"
    $payload init
  }
  Object instproc get_payload {var {default ""}} {
    set payload [self]::payload
    if {![my isobject $payload]} {
      ::xo::Context create $payload -requireNamespace
    }
    expr {[$payload exists $var] ? [$payload set $var] : $default}
  }

  #
  # Methods of ::xowiki::Form
  #
  Form instproc footer {} {
    return [my include_portlet [list form-menu -form_item_id [my item_id]]]
  }

  Page instproc new_name {name} {
    if {$name ne ""} {
      my instvar package_id
      set name [my complete_name $name]
      set name [::$package_id normalize_name $name]
      set suffix ""; set i 0
      set folder_id [my parent_id]
      while {[CrItem lookup -name $name$suffix -parent_id $folder_id] != 0} {
        set suffix -[incr i]
      }
      set name $name$suffix
    }
    return $name
  }

  Page instproc create-new {} {
    my instvar package_id
    set name [my new_name [::xo::cc form_parameter name ""]]
    set class [::xo::cc form_parameter class ::xowiki::Page]
    if {[::xotcl::Object isclass $class] && [$class info heritage ::xowiki::Page] ne ""} { 
      set class [::xo::cc form_parameter class ::xowiki::Page]
      set f [$class new -destroy_on_cleanup \
                 -name $name \
                 -package_id $package_id \
                 -parent_id [my parent_id] \
                 -publish_status "production" \
                 -title [my title] \
                 -text [list [::xo::cc form_parameter content ""] text/html]]
      $f save_new
      $package_id returnredirect \
          [my query_parameter "return_url" [$package_id pretty_link $name]?m=edit]
    }
  }

  Form instproc create-new {} {
    my instvar package_id
    set f [FormInstance new -destroy_on_cleanup \
               -package_id $package_id \
               -parent_id [my parent_id] \
               -publish_status "production" \
               -page_template [my item_id]]
    $f save_new
    $package_id returnredirect \
        [my query_parameter "return_url" [$package_id pretty_link [$f name]]?m=edit]
  }

  Form instproc get_content {} {
    my instvar text
    my log "-- text='$text'"
    if {[lindex $text 0] ne ""} {
      set content [my substitute_markup [my set text]]
    } else {
      set content [lindex [my set form] 0]
    }
    return $content
  }

  Form instproc list {} {
    my view [my include_portlet [list form-instances -form_item_id [my item_id]]]
  }

  #
  # Methods of ::xowiki::FormInstance
  #
  FormInstance instproc footer {} {
    return [my include_portlet [list form-instance-menu]]
  }
  FormInstance instproc set_form_value {att value} {
    my instvar root item_id
    set fields [$root selectNodes "//*\[@name='$att'\]"]
    #my msg "found field = $fields xp=//*\[@name='$att'\]"
    foreach field $fields {
      if {[$field nodeName] ne "input"} continue
      set type [expr {[$field hasAttribute type] ? [$field getAttribute type] : "text"}]
      # the switch should be really different objects ad classes...., but thats HTML, anyhow.
      switch $type {
        checkbox {$field setAttribute checked true}
        radio {
          set inputvalue [$field getAttribute value]
          if {$inputvalue eq $value} {
            $field setAttribute checked true
          }
        }
        text {  $field setAttribute value $value}
        default {my msg "can't handle $type so far $att=$value"}
      }
    }
  }

  FormInstance ad_instproc set_form_data {} {
    Store the instance attributes in the form.
  } {
    foreach {att value} [my instance_attributes] {
      my set_form_value $att $value
    }
  }

  FormInstance ad_instproc get_form_data {} {
    Get the values from the form and store it as
    instance attributes.
  } {
    set form [lindex [my get_from_template form] 0]
    if {$form ne ""} {
      array set __ia [my set instance_attributes]
      # we have a form, we get for the time being all variables
      foreach att [::xo::cc array names form_parameter] {
        switch -- $att {
          __object_name {}
          __name  {my set name [::xo::cc form_parameter $att]}
          __title {my set title [::xo::cc form_parameter $att]}
          default {set __ia($att) [::xo::cc form_parameter $att]}
        }
      }
      my log "--set instance attributes to [array get __ia]"
      my set instance_attributes [array get __ia]
    }
  }

  FormInstance instproc form_attributes {} {
    my instvar page_template
    set dont_edit [concat [[my info class] edit_atts] [list title] \
                       [::Generic::CrClass set common_query_atts]]

    set template [lindex [my get_from_template text] 0]
    set page_instance_form_atts [list]
    if {$template ne ""} {
      foreach {var _} [my template_vars $template] {
	if {[lsearch $dont_edit $var] == -1} {lappend page_instance_form_atts $var}
      }
    } else {
      set form [lindex [my get_from_template form] 0]
      dom parse -simple -html $form doc
      $doc documentElement root
      set fields [$root selectNodes "//*\[@name != ''\]"]
      foreach field $fields {
	if {[$field nodeName] ne "input"} continue
	set att [$field getAttribute name]
	if {[lsearch $page_instance_form_atts $att]} {
	  lappend page_instance_form_atts $att
	}
      }
    }
    return $page_instance_form_atts
  }

  FormInstance instproc get_content {} {
    my instvar doc root package_id page_template
    set text [lindex [my get_from_template text] 0]
    if {$text ne ""} {
      # we have a template
      return [next]
    } else {
      set form [lindex [my get_from_template form] 0]
      dom parse -simple -html $form doc
      $doc documentElement root
      my set_form_data
      return [$root asHTML]
    }
  }


  FormInstance instproc save_data {old_name} {
    my log "-- [self args]"
    my instvar package_id name
    db_transaction {
      #
      # if the newly created item was in production mode, but ordinary entries
      # are not, change on the first save the status to ready
      #
      if {[my publish_status] eq "production" && $old_name eq [my revision_id]} {
        if {![$package_id get_parameter production_mode 0]} {
          my set publish_status "ready"
        }
      }
      my save
      my log "-- old_name $old_name, name $name"
      if {$old_name ne $name} {
        my log "--forminstance renaming"
        db_dml [my qn update_rename] "update cr_items set name = :name \
                where item_id = [my item_id]"
      }
    }
    return [my item_id]
  }

  FormInstance ad_instproc save-form-data {} {
    Method to be called from a submit button of the form
  } {
    my instvar package_id name
    my get_form_data
    my set data [self]  ;# for the time being; change clobbering when validate_name becomes a method
    set ok [::xowiki::validate_name]
    my log "--forminstance name='$name', old_name=[::xo::cc form_parameter __object_name] ok=$ok"
    if {$ok} {
      my save_data [::xo::cc form_parameter __object_name ""]
      my log "--forminstance redirect to [$package_id pretty_link $name]"
      $package_id returnredirect \
          [my query_parameter "return_url" [$package_id pretty_link $name]]
    } else {
      util_user_message -message "Another item with the name name $name exists already"
      set name  [::xo::cc form_parameter __object_name]
      $package_id returnredirect [::xo::cc url]?m=edit
    }
  }

}

source [file dirname [info script]]/xowiki-www-procs.tcl

