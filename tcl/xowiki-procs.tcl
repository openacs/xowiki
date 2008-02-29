ad_library {
    XoWiki - main library classes and objects

    @creation-date 2006-01-10
    @author Gustaf Neumann
    @cvs-id $Id$
}

namespace eval ::xowiki {
  #
  # create classes for different kind of pages
  #
  ::xo::db::CrClass create Page -superclass ::xo::db::CrItem \
      -pretty_name "XoWiki Page" -pretty_plural "XoWiki Pages" \
      -table_name "xowiki_page" -id_column "page_id" \
      -mime_type text/html \
      -slots {
        if {[::xo::db::has_ltree]} {
          ::xo::db::CrAttribute create page_order \
	      -sqltype ltree -validator page_order -default ""
        }
        ::xo::db::CrAttribute create creator
	# The following slots are defined elsewhere, but we override
	# some default values, such as pretty_names, required state, 
	# help text etc.
	::xo::Attribute create name \
	    -required true \
	    -help_text #xowiki.Page-name-help_text# \
	    -validator name
	::xo::Attribute create title \
	    -required true
	::xo::Attribute create descripion \
	    -spec "textarea,cols=80,rows=2" 
	::xo::Attribute create text \
	    -spec "richtext" 
	::xo::Attribute create nls_language \
	    -spec {select,options=[xowiki::locales]}
	::xo::Attribute create publish_date \
	    -spec date
	::xo::Attribute create last_modified \
	    -spec date
	::xo::Attribute create creation_user \
	    -spec user_id
      } \
      -parameter {
        {lang en}
        {render_adp 1}
        {do_substitutions 1}
        {absolute_links 0}
      } \
      -form ::xowiki::WikiForm

  ::xowiki::Page log "--slots [::xo::slotobjects ::xowiki::Page]"
  # TODO: the following slot definitions are not meant to stay this way.
  # when we change to the xotcl 1.5.0+ slots, this will go away
  if {$::xotcl::version < 1.5} {
     if {![::xotcl::Object isobject ::xowiki::Page::slot]} {
        ::xotcl::Object create ::xowiki::Page::slot
     }
     foreach parameter {name title description text nls_language publish_date creation_user last_modified} {
        if {![::xotcl::Object isobject ::xowiki::Page::slot::$parameter]} {
          ::xo::Attribute create ::xowiki::Page::slot::$parameter 
        }
     }
  }

  ::xo::db::CrClass create PlainPage -superclass Page \
      -pretty_name "XoWiki Plain Page" -pretty_plural "XoWiki Plain Pages" \
      -table_name "xowiki_plain_page" -id_column "ppage_id" \
      -mime_type text/plain \
      -form ::xowiki::PlainWikiForm

  ::xo::db::CrClass create File -superclass Page \
      -pretty_name "XoWiki File" -pretty_plural "XoWiki Files" \
      -table_name "xowiki_file" -id_column "file_id" \
      -storage_type file \
      -form ::xowiki::FileForm

  ::xo::db::CrClass create PodcastItem -superclass File \
      -pretty_name "Podcast Item" -pretty_plural "Podcast Items" \
      -table_name "xowiki_podcast_item" -id_column "podcast_item_id" \
      -slots {
	::xo::db::CrAttribute create pub_date \
	    -datatype date \
	    -sqltype timestamp \
	    -spec "date,format=YYYY_MM_DD_HH24_MI"
	::xo::db::CrAttribute create duration \
	    -help_text "#xowiki.PodcastItem-duration-help_text#"
	::xo::db::CrAttribute create subtitle
	::xo::db::CrAttribute create keywords \
	    -help_text "#xowiki.PodcastItem-keywords-help_text#"
      } \
      -storage_type file \
      -form ::xowiki::PodcastForm
  
  ::xo::db::CrClass create PageTemplate -superclass Page \
      -pretty_name "XoWiki Page Template" -pretty_plural "XoWiki Page Templates" \
      -table_name "xowiki_page_template" -id_column "page_template_id" \
      -slots {
        ::xo::db::CrAttribute create anon_instances \
	    -datatype boolean \
            -sqltype boolean -default "f" 
      } \
      -form ::xowiki::PageTemplateForm

  ::xo::db::CrClass create PageInstance -superclass Page \
      -pretty_name "XoWiki Page Instance" -pretty_plural "XoWiki Page Instances" \
      -table_name "xowiki_page_instance"  -id_column "page_instance_id" \
      -slots {
        ::xo::db::CrAttribute create page_template \
            -datatype integer \
	    -references cr_items(item_id)
        ::xo::db::CrAttribute create instance_attributes \
            -sqltype long_text \
	    -default ""
      } \
      -form ::xowiki::PageInstanceForm \
      -edit_form ::xowiki::PageInstanceEditForm

  ::xo::db::CrClass create Object -superclass PlainPage \
      -pretty_name "XoWiki Object" -pretty_plural "XoWiki Objects" \
      -table_name "xowiki_object"  -id_column "xowiki_object_id" \
      -mime_type text/plain \
      -form ::xowiki::ObjectForm

  ::xo::db::CrClass create Form -superclass PageTemplate \
      -pretty_name "XoWiki Form" -pretty_plural "XoWiki Forms" \
      -table_name "xowiki_form"  -id_column "xowiki_form_id" \
      -slots {
        ::xo::db::CrAttribute create form \
            -sqltype long_text \
	    -default ""
        ::xo::db::CrAttribute create form_constraints \
            -sqltype long_text \
	    -default "" \
            -validator form_constraints \
	    -spec "textarea,cols=100,rows=5"
      } \
      -form ::xowiki::FormForm

  ::xo::db::CrClass create FormPage -superclass PageInstance \
      -pretty_name "XoWiki FormPage" -pretty_plural "XoWiki FormPages" \
      -table_name "xowiki_form_page" -id_column "xowiki_form_page_id" 

  #::xo::db::CrClass create FormInstance -superclass PageInstance \
  #    -pretty_name "XoWiki FormInstance" -pretty_plural "XoWiki FormInstances" \
  #    -table_name "xowiki_form_instance" -id_column "xowiki_form_instance_id" 

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

  # Oracle has a limit of 3118 characters for keys, therefore no text as type for "tag"
  ::xo::db::require table xowiki_tags \
       "item_id integer references cr_items(item_id) on delete cascade,
        package_id integer,
        user_id integer references users(user_id),
        tag     varchar(3000),
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


  Page set recursion_count 0
  Page array set RE {
    include {([^\\]){{([^<]+?)}}([&<\s]|$)}
    anchor  {([^\\])\\\[\\\[([^\]]+?)\\\]\\\]}
    div     {()([^\\])&gt;&gt;([^&<]*?)&lt;&lt;()([ \n]*)?}
    clean   {[\\](\{\{|&gt;&gt;|\[\[)}
    clean2  { <br */?> *(<div)}
  }

  #
  # templating and CSS
  #

  Page proc quoted_html_content text {
    list [ad_text_to_html $text] text/html
  }

  #
  # Operations on the whole instance
  #

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
    my set __file_content [::base64::encode [::xowiki::read_file $fn]]
    next
  }

  Page instproc demarshall {-parent_id -package_id -creation_user} {
    # this method is the counterpart of marshall
    my set parent_id $parent_id
    my set package_id $package_id 
    my set creation_user $creation_user
    #
    # if we import from an instance without page_orders into an instance
    # with page_orders, we need default values
    if {[::xo::db::has_ltree] && ![my exists page_order]} {
      my set page_order ""
    }
    # in the general case, no more actions required
  }

  File instproc demarshall {args} {
    next
    # we have to care about recoding the file content
    my instvar import_file __file_content
    set import_file [ns_tmpnam]
    ::xowiki::write_file $import_file [::base64::decode $__file_content]
  }

  # set default values. 
  # todo: with slots, it should be easier to set default values
  # for non existing variables
  PageInstance instproc demarshall {args} {
    # some older versions do not have anon_instances
    if {![my exists anon_instances]} {
      my set anon_instances "f"
    }
    next
  }
  Form instproc demarshall {args} {
    # some older versions do not have anon_instances
    if {![my exists anon_instances]} {
      my set anon_instances "t"
    }
    next
  }

  Page instproc condition=match {query_context value} {
    #
    # Conditon for conditional checks in policy rules
    # The match condition is called with an attribute 
    # name and a pattern like in
    #
    #  edit {
    #     {{match {name {*weblog}}} package_id admin} 
    #     {package_id write}
    #  }
    #
    # This example specifies that for a page named
    # *weblog, the method "edit" is only allowed
    # for package admins.
    #
    #my msg "query_context='$query_context', value='$value'"
    if {[llength $value] != 2} {
      error "two arguments for match required, [llength $value] passed (arguments='$value')"
    }
    if {[catch {
      set success [string match [lindex $value 1] [my set [lindex $value 0]]]
    } errorMsg]} {
      my log "error during match: $errorMsg"
      set success 0
    }
    return $success
  }

  Page instproc condition=regexp {query_context value} {
    #
    # Conditon for conditional checks in policy rules
    # The match condition is called with an attribute 
    # name and a pattern like in
    #
    #  edit               {
    #    {{regexp {name {(weblog|index)$}}} package_id admin} 
    #    {package_id write}
    #  }
    #
    # This example specifies that for a page ending with
    # weblog or index, the method "edit" is only allowed
    # for package admins.
    #
    #my msg "query_context='$query_context', value='$value'"
    if {[llength $value] != 2} {
      error "two arguments for regexp required, [llength $value] passed (arguments='$value')"
    }
    if {[catch {
      set success [regexp [lindex $value 1] [my set [lindex $value 0]]]
    } errorMsg]} {
      my log "error during regexp: $errorMsg"
      set success 0
    }
    return $success
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

  Page proc save_tags {
       -package_id:required 
       -item_id:required 
       -revision_id:required 
       -user_id:required 
       tags
     } {
    db_dml [my qn delete_tags] \
        "delete from xowiki_tags where item_id = $item_id and user_id = $user_id"
    foreach tag $tags {
      db_dml [my qn insert_tag] \
          "insert into xowiki_tags (item_id,package_id, user_id, tag, time) \
           values ($item_id, $package_id, $user_id, :tag, current_timestamp)"
    }
    search::queue -object_id $revision_id -event UPDATE
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
  
  Page instproc save args {
    [my package_id] flush_page_fragment_cache
    next
  }

  Page instproc save_new args {
    [my package_id] flush_page_fragment_cache
    next
  }

  Page instproc initialize_loaded_object {} {
    my instvar title
    if {[info exists title] && $title eq ""} {set title [my set name]}
    next
  }

  Page instproc get_instance_attributes {} {
    if {[my exists instance_attributes]} {
      return [my set instance_attributes]
    }
    return ""
  }

  Page instproc regsub_eval {{-noquote:boolean false} re string cmd} {
    if {$noquote} {
      set map { \[ \\[ \] \\] \$ \\$ \\ \\\\}
    } else {
      set map { \" \\\" \[ \\[ \] \\] \$ \\$ \\ \\\\}
    }
#     my msg "re=$re, string=$string cmd=$cmd"
#     set c [regsub -all $re [string map { \[ \\[ \] \\] \
#                                             \$ \\$ \\ \\\\} $string] \
#                "\[$cmd\]"]
#     my msg c=$c
#     set s [subst $c]
#     my msg s=$s
#     return $s
    uplevel [list subst [regsub -all $re [string map $map $string] "\[$cmd\]"]]
  }

  Page instproc error_during_render {msg} {
    return "<div class='errorMsg'>$msg</div>"
  }

  Page instproc error_in_includelet {arg msg} {
    my instvar name
    return [my error_during_render "[_ xowiki.error_in_includelet]<br />\n$msg"]
  }
  
  Page ad_instproc resolve_included_page_name {page_name} {
    Determine the page object for the specified page name.
    The specified page name might have the form 
    //some_other_instance/page_name, in which case the 
    page is resolved from some other package instance.
    If the page_name does not contain a language prefix,
    the language prefix of the including page is used.
  } {
    if {$page_name ne ""} {
      set page ""
      #
      # take a local copy of the package_id, since it is possible
      # that the variable package_id might changed to another instance.
      #
      set package_id [my package_id]
      if {[regexp {^/(/.+)$} $page_name _ url]} {
	#
	# Handle cross package resolve requests
	# Note, that package::initialize might change the package id.
	#
	::xowiki::Package initialize -parameter {{-m view}} -url $url \
	    -actual_query ""
	if {$package_id != 0} {
	  #
	  # For the resolver, we create a fresh context to avoid recursive loops, when
	  # e.g. revision_id is set through a query parameter...
	  #
	  set last_context [expr {[$package_id exists context] ? [$package_id context] : "::xo::cc"}]
	  $package_id context [::xo::Context new -volatile]
	  set object_name [$package_id set object]
	  #
	  # A user might force the language by preceding the
	  # name with a language prefix.
	  #
	  if {![regexp {^..:} $object_name]} {
	    set object_name [my lang]:$object_name
	  }
	  set page [$package_id resolve_page $object_name __m]
	  $package_id context $last_context
	}
      } else {
	set last_context [expr {[$package_id exists context] ? [$package_id context] : "::xo::cc"}]
	$package_id context [::xo::Context new -volatile]
	set page [$package_id resolve_page $page_name __m]
	$package_id context $last_context
      }
      if {$page eq ""} {
	error "Cannot find page '$page_name'"
      }
      $page destroy_on_cleanup
    } else {
      set page [self]
    }
    return $page
  }

  Page instproc instantiate_includelet {arg} {
    # we want to use package_id as proc-local variable, since the 
    # cross package reference might alter it locally
    set package_id [my package_id]

    # do we have a wellformed list?
    if {[catch {set page_name [lindex $arg 0]} errMsg]} {
      # there must be something syntactically wrong
      return [my error_in_includelet $arg [_ xowiki.error-includelet-dash_syntax_invalid]]
    }

    # the include is either a includelet class, or a wiki page
    if {[my isclass ::xowiki::includelet::$page_name]} {
      # direct call, without page, not tailorable
      set page [::xowiki::includelet::$page_name new \
		    -package_id $package_id \
		    -name $page_name \
                    -locale [::xo::cc locale] \
		    -actual_query [::xo::cc actual_query]]
    } else {
      #
      # Include a wiki page, tailorable.
      #
      set page [my resolve_included_page_name $page_name]
      
      if {$page ne "" && ![$page exists __decoration]} {
	# 
	# we use as default decoration for included pages
	# the "portlet" decoration
	#
        $page set __decoration portlet
      }
    }

    if {$page ne ""} {
      $page set __caller_parameters [lrange $arg 1 end] 
      $page destroy_on_cleanup
      my set __last_includelet $page
      $page set __including_page [self]
      if {[$page istype ::xowiki::Includelet]} {
        $page initialize
      }
    }
    return $page
  }

  Page instproc render_includelet {page} {
    #$page set __decoration portlet
    foreach {att value} [$page set __caller_parameters] {
      switch -- $att {
        -decoration {$page set __decoration $value}
        -title {$page set title $value}
      }
    }
    if {[$page exists __decoration] && [$page set __decoration] ne "none"} {
      $page mixin add ::xowiki::includelet::decoration=[$page set __decoration]
    }
    set c [$page info class]
    if {[$c exists cacheable] && [$c cacheable]} {
      $page mixin add ::xowiki::includelet::page_fragment_cache
    }
    
    if {[catch {set html [$page render]} errorMsg]} {
      set page_name [$page name]
      set html [my error_during_render [_ xowiki.error-includelet-error_during_render]]
    }
    #my log "--include includelet returns $html"
    return $html
  }

  Page instproc include_portlet {arg} {
    my log "+++ method [self proc] of [self class] is deprecated"
    return [my include $arg]
  }

  Page ad_instproc include {arg} {
    Include the html of the includelet. The method generates
    an includelet object (might be an other xowiki page) and
    renders it and returns either html or an error message.
  } {
    set page [my instantiate_includelet $arg]
    if {$page eq ""} {
      return [my error_during_render [_ xowiki.error-includelet-unknown]]
    }
    return [my render_includelet $page]
  }

  Page instproc include_content {ch arg ch2} {
    # make recursion depth a global variable to ease the deletion etc.
    if {[catch {incr ::xowiki_inclusion_depth}]} {
      set ::xowiki_inclusion_depth 1
    }
    if {$::xowiki_inclusion_depth > 10} {
      return ${ch}[my error_in_includelet $arg [_ xowiki.error-includelet-nesting_to_deep]]
    }
    if {[regexp {^adp (.*)$} $arg _ adp]} {
      if {[catch {lindex $adp 0} errMsg]} {
        # there is something syntactically wrong
        incr ::xowiki_inclusion_depth -1
        return ${ch}[my error_in_includelet $arg [_ xowiki.error-includelet-adp_syntax_invalid]]
      }
      set adp [string map {&nbsp; " "} $adp]
      set adp_fn [lindex $adp 0]
      if {![string match "/*" $adp_fn]} {set adp_fn /packages/xowiki/www/$adp_fn}
      set adp_args [lindex $adp 1]
      if {[llength $adp_args] % 2 == 1} {
        incr ::xowiki_inclusion_depth -1
        set adp $adp_args
        return ${ch}[my error_in_includelet $arg [_ xowiki.error-includelet-adp_syntax_invalid]]
      }
      lappend adp_args __including_page [self]
      set including_page_level [template::adp_level]
      if {[catch {set page [template::adp_include $adp_fn $adp_args]} errorMsg]} {
        # in case of error, reset the adp_level to the previous value
        set ::template::parse_level $including_page_level 
        incr ::xowiki_inclusion_depth -1
        return ${ch}[my error_in_includelet $arg \
                         [_ xowiki.error-includelet-error_during_adp_evaluation]]
      }

      return $ch$page$ch2
    } else {
      # we have a direct (adp-less include)
      # Some browsers change {{cmd -flag "..."}} into {{cmd -flag &quot;...&quot;}}
      # We have to change this back
      regsub -all {([^\\])&quot;}  $arg "\\1\"" arg
      set html [my include $arg]
      #my log "--include includelet returns $html"
      incr ::xowiki_inclusion_depth -1
      return $ch$html$ch2
    }
  }

  Page instproc div {ch arg} {
    if {$arg eq "content"} {
      return "$ch<div id='content' class='column'>"
    } elseif {[string match "left-col*" $arg] \
              || [string match "right-col*" $arg] \
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
      if {[regsub {^//} $link / link]} {
	#my msg t=[::xowiki::guesstype $link]
	switch -glob -- [::xowiki::guesstype $link] {
	  text/css {
	    ::xo::Page requireCSS $link
	    return $ch
	  }
	  application/x-javascript {
	    ::xo::Page requireJS $link
	    return $ch
	  }
	  image/* {
	    Link create [self]::link \
		-page [self] \
		-type localimage -label $label \
		-href $link
	    eval [self]::link configure $options
	    return $ch[[self]::link render]
	  }
	}
      }
      set l [ExternalLink new -label $label -href $link]
      eval $l configure $options
      set html [$l render]
      $l destroy
      return "$ch$html"
    }

    set name ""
    my instvar parent_id package_id
    if {[regexp {^:(..):(.*)$} $link _ lang stripped_name]} {
      # language link (it starts with a ':')
      set link_type language
    } elseif {[regexp {^(file|image|js|css|swf):(.*)$} $link _ \
		   link_type stripped_name]} {
      # (typed) file links
      set lang ""
      set name file:$stripped_name
    } elseif {[regexp {^:(..):(.*)$} $link _ lang stripped_name]} {
      set link_type language
    } else {
      # do we have a typed link? more than two chars...
      if {[regexp {^([^:][^:][^:]+):((..):)?(.+)$} $link _ \
		link_type _ lang  stripped_name]} {
        set name file:$stripped_name
      } else {
        # must be an untyped link; defaults, in case the second regexp does not match either
        set lang ""
        set stripped_name $link

        regexp {^(..):(.+)$} $link _ lang stripped_name
	switch -glob -- [::xowiki::guesstype $link] {
	  text/css {
	    set link_type css
	    set name file:$stripped_name
	  }
	  application/x-javascript {
	    set link_type js
	    set name file:$stripped_name
	  }
	  application/x-shockwave-flash {
	    set link_type swf
	    set name swf:$stripped_name; # not consistent, but backward compatible
	  }
	  image/* {
	    set link_type image
	    set name image:$stripped_name
	  }
	  default {
	    set link_type link
	    #set name $stripped_name
	  }
	}
      }
    }

    #my msg name=$name,stripped_name=$stripped_name,link_type=$link_type,lang=$lang
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
      return "${ch}<div class='errorMsg'>Error during processing of options [list $options] of link of type [[self]::link info class]:<blockquote>$error</blockquote></div>"
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
    if {![my do_substitutions]} {return [lindex $source 0]}
    set content ""
    set l " "; #use one byte trailer for regexps for escaped content
    foreach l0 [split [lindex $source 0] \n] {
      append l $l0
      if {[string first \{\{ $l] > -1 && [string first \}\} $l] == -1} continue
      set l [my regsub_eval $RE(anchor)  $l {my anchor  "\1" "\2"}]
      set l [my regsub_eval $RE(div)     $l {my div     "\2" "\3"}]
      set l [my regsub_eval $RE(include) $l {my include_content "\\\1" "\2" "\3"}]
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
    set __ignorelist [list RE __defaults name_method object_type_key db_slot]
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
      if {[array exists $__v]} continue ;# don't report  arrays
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

  Page instproc get_description {-nr_chars content} {
    my instvar revision_id
    set description [my set description]
    if {$description eq "" && $content ne ""} {
      set description [ad_html_text_convert -from text/html -to text/plain -- $content]
    }
    if {$description eq "" && $revision_id > 0} {
      set body [db_string [my qn get_description_from_syndication] \
                           "select body from syndication where object_id = $revision_id" \
                           -default ""]
      set description [ad_html_text_convert -from text/html -to text/plain -- $body]
    }
    if {[info exists nr_chars] && [string length $description] > $nr_chars} {
      set description [string range $description 0 $nr_chars]...
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
      #my msg "--w T.name = '$name' var=$page_name, $var_name $field_name "
      if {[string match $page_name $name] &&
          [string match $var_name $field_name]} {
        set spec $widget_spec
	#my msg "setting spec to $spec"
        break
      }
    }
    if {$spec eq ""} {return $default}
    return $field_name:$spec
  }

  Page instproc validate=name {name} {
    upvar nls_language nls_language
    my set data [self]  ;# for the time being; change clobbering when validate_name becomes a method
    set success [::xowiki::validate_name]
    if {$success} {
      # set the instance variable with a potentially prefixed name
      # the classical validators do just an upvar
      my set name $name
    }
    return $success
  }
  Page instproc validate=page_order {value} {
    if {[my exists page_order]} {
      set page_order [string trim $value " ."]
      my page_order $page_order
    }
    return 1
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
    #my log "--OMIT and not $field in ([join $::xowiki_page_item_id_rendered ,])"
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
    if {[::xo::cc get_parameter content-type text/html] eq "text/html"} {
      append html "<DIV class='content-chunk-footer'>"
      if {![my exists __no_footer] && ![::xo::cc get_parameter __no_footer 0]} {
        append html [my footer]
      }
      append html "</DIV>\n"
    }
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
  # Some utility functions, called on different kind of pages
  # 
  Page instproc form_field_index {nodes} {
    set marker ::__computed_form_field_names($nodes)
    if {[info exists $marker]} return

    foreach n $nodes {
      if {![$n istype ::xowiki::FormField]} continue
      set ::_form_field_names([$n name]) $n
      my form_field_index [$n info children]
    }
    set $marker 1
  }

  Page instproc lookup_form_field {
    -name 
    form_fields
  } {
    set key ::_form_field_names($name)
    #my msg "form_fields=$form_fields, search for $name"
    my form_field_index $form_fields

    #my msg "FOUND($name)=[info exists $key]"
    if {[info exists $key]} {
      return [set $key]
    }
    error "No form field with name $name found"
  }

  Page instproc show_fields {form_fields} {
    # this method is for debugging only
    set msg ""
    foreach f $form_fields { append msg "[$f name] [$f info class], " }
    my msg $msg
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
    #my msg "-- my class=[my info class]"
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
      set l [my regsub_eval $RE(anchor)  $l {my anchor  "\1" "\2"}]
      set l [my regsub_eval $RE(div)     $l {my div     "\2" "\3"}]
      set l [my regsub_eval $RE(include) $l {my include "\1" "\2" ""}]
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
      # Internet explorer seems to transmit the full path of the
      # filename. Just use the last part in such cases as name.
      regexp {[/\\]([^/\\]+)$} $stripped_name _ stripped_name
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
    #set page_link [$package_id make_link -privilege public [self] download ""]
    set page_link [$package_id pretty_link  -download true [my name]]
    #my log "--F page_link=$page_link ---- "
    set t [TableWidget new -volatile \
               -columns {
                 AnchorField name -label [_ xowiki.Page-name]
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
    return "$image[$t asHTML]\n<p>$description</p>"
  }

  PodcastItem instproc get_content {} {
    set content [next]
    append content <ul>
    foreach {label var} {
      #xowiki.title# title 
      #xowiki.PodcastItem-subtitle# subtitle 
      #xowiki.Page-creator# creator 
      #xowiki.PodcastItem-pub_date# pub_date 
      #xowiki.PodcastItem-duration# duration 
      #xowiki.PodcastItem-keywords# keywords
    } {
      append content "<li><em>$label:</em> [my set $var]\n"
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
  PageTemplate instproc count_usages {{-all false}} {
    return [::xowiki::PageTemplate count_usages -item_id [my item_id] -all $all]
  }

  PageTemplate proc count_usages {-item_id:required {-all:boolean false}} {
    set publish_status_clause [expr {$all ? "" : " and i.publish_status <> 'production' "}]
    set count [db_string [my qn count_usages] \
		   "select count(page_instance_id) from xowiki_page_instance, cr_items i \ 
			where page_template = $item_id \
                        $publish_status_clause \
                        and page_instance_id = coalesce(i.live_revision,i.latest_revision)"]
    return $count
  }

  #
  # PageInstance methods
  #

  PageInstance proc get_short_spec_from_form_constraints {-name -form_constraints} {
    # for the time being we cache the form_constraints per request as a global
    # variable, which is reclaimed at the end of the connection
    set varname ::xowiki_$form_constraints
    if {![info exists $varname]} {
      foreach name_and_spec $form_constraints {
        regexp {^([^:]+):(.*)$} $name_and_spec _ spec_name short_spec
        set ${varname}($spec_name) $short_spec
      }
    }
    if {[info exists ${varname}($name)]} {
      return [set ${varname}($name)]
    }
    return ""
  }

  PageInstance instproc get_short_spec {name} {
    #my msg "get_short_spec $name"
    my instvar page_template
    # in the old-fashioned 2-form page-instance create, page_template
    # might be non-existant or empty.
    if {[info exists page_template] && $page_template ne "" &&
        [$page_template exists form_constraints]} {
      set short_spec [::xowiki::PageInstance get_short_spec_from_form_constraints \
                          -name $name -form_constraints [$page_template form_constraints]]
      if {$short_spec ne ""} {
        return $short_spec
      }
    }
    return ""
  }

  PageInstance instproc get_field_label {name value} {
    set short_spec [my get_short_spec $name]
    if {$short_spec ne ""} {
      set f [FormField new -volatile -name $name -spec $short_spec]
      return [$f pretty_value $value]
    }
    return $value
  }
  PageInstance instproc widget_spec_from_folder_object {name given_template_name} {
    # get the widget field specifications from the payload of the folder object
    # for a field with a specified name in a specified page template
    foreach {s widget_spec} [[my set parent_id] get_payload widget_specs] {
      foreach {template_name var_name} [split $s ,] break
      #ns_log notice "--w T.title = '$given_template_name' var=$name"
      if {([string match $template_name $given_template_name] || $given_template_name eq "") &&
          [string match $var_name $name]} {
        return $widget_spec
        #ns_log notice "--w using $widget for $name"
      }
    }
    return ""
  }
  PageInstance instproc get_field_type {name default_spec} {
    my instvar page_template
    # get widget spec from folder (highest priority)
    set spec [my widget_spec_from_folder_object $name [$page_template set name]]
    if {$spec ne ""} {
      return $spec
    }
    # get widget spec from attribute definition 
    set f [my create_raw_form_field -name $name -slot [my find_slot $name]]
    if {$f ne ""} {
      return [$f asWidgetSpec]
    }
    # use default widget spec
    return $default_spec
  }

  PageInstance instproc get_from_template {var} {
    my instvar page_template
    if {[info command ::$page_template] eq ""} {
      #my log  "-- fetching page_template = $page_template"
      ::xo::db::CrClass get_instance_from_db -item_id $page_template
      $page_template destroy_on_cleanup
    }
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
      # TODO: just for the lookup, whether a field is a richt text field,
      # there should be a more efficient and easier way...
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
      ::xo::clusterwide ns_cache flush xotcl_object_cache [my item_id]
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
    return [my include [list form-menu -form_item_id [my item_id]]]
  }

  Form proc disable_input_fields {form} {
    dom parse -simple -html $form doc
    $doc documentElement root
    set fields [$root selectNodes "//button | //input | //optgroup | //option | //select | //textarea "]
    foreach field $fields {
      $field setAttribute disabled "disabled"
    }
    return [$root asHTML]
  }

  Form instproc get_content {} {
    my instvar text form
    ::xowiki::Form requireFormCSS

    # we assume, that the richtext is stored as 2-elem list with mime-type
    #my log "-- text='$text'"
    if {[lindex $text 0] ne ""} {
      set content [my substitute_markup [my set text]]
    } elseif {[lindex $form 0] ne ""} {
      set content [[self class] disable_input_fields [lindex $form 0]]
    } else {
      set content ""
    }
    return $content
  }

  Form instproc list {} {
    my view [my include [list form-usages -form_item_id [my item_id]]]
  }


  Form instproc validate=form_constraints {form_constraints} {
    #
    # First check for invalid meta characters for security reasons.
    #
    if {[regexp {[\[\]]} $form_constraints]} {
      my uplevel [list set errorMsg [_ xowiki.error-form_constraint-invalid_characters]]
      return 0
    }
    #
    # Create from fields from all specs and report, if there are any errors
    #
    foreach name_and_spec $form_constraints {
      regexp {^([^:]+):(.*)$} $name_and_spec _ spec_name short_spec
      #foreach {spec_name short_spec} [split $name_and_spec :] break
      if {$spec_name eq "@table" || $spec_name eq "@categories"} continue

      #my msg "checking spec '$short_spec' for form field '$spec_name'"
      if {[catch {
        set f [my create_raw_form_field \
                   -name $spec_name \
                   -slot [my find_slot $spec_name] \
                   -spec $short_spec]
        $f destroy
      } errorMsg]} {
        my uplevel [list set errorMsg $errorMsg]
        #my msg "ERROR: invalid spec '$short_spec' for form field '$spec_name' -- $errorMsg"
        return 0
      }
    }
    return 1
  }

  #
  # Methods of ::xowiki::FormPage
  #
  FormPage instproc footer {} {
    if {[my exists __no_form_page_footer]} {
      next
    } else {
      return [my include [list form-entry-menu]]
    }
  }

  FormPage instproc form_attributes {} {
    #
    # this method returns the form attributes (including _*)
    #
    my instvar page_template
    set allvars [concat [[my info class] array names db_slot] \
                     [::xo::db::CrClass set common_query_atts]]

    set template [lindex [my get_from_template text] 0]
    #set field_names [list _name _title _description _creator _nls_language _page_order]
    set field_names [list]
    set form [lindex [my get_from_template form] 0]
    if {$form eq ""} {
      foreach {var _} [my template_vars $template] {
        #if {[string match _* $var]} continue
	if {[lsearch $allvars $var] == -1} {lappend field_names $var}
      }
      set form_vars 0
    } else {
      foreach {match 1 att} [regexp -all -inline [template::adp_variable_regexp] $form] {
        #if {[string match _* $att]} continue
        lappend field_names $att
      }
      dom parse -simple -html $form doc
      $doc documentElement root
      set fields [$root selectNodes "//*\[@name != ''\]"]
      foreach field $fields {
        set node_name [$field nodeName]
	if {$node_name ne "input" 
            && $node_name ne "textarea" 
            && $node_name ne "select" 
          } continue
	set att [$field getAttribute name]
        #if {[string match _* $att]} continue
	if {[lsearch $field_names $att] == -1} {
	  lappend field_names $att
	}
      }
      set form_vars 1
    }
    return [list $form_vars $field_names]
  }


  FormPage instproc get_content {} {
    my instvar doc root package_id page_template
    set text [lindex [my get_from_template text] 0]
    if {$text ne ""} {
      #my msg "we have a template text='$text'"
      # we have a template
      return [next]
    } else {
      ::xowiki::Form requireFormCSS
      set form [lindex [my get_from_template form] 0]
      foreach {form_vars field_names} [my form_attributes] break
      my array unset field_in_form
      if {$form_vars} {foreach v $field_names {my set field_in_form($v) 1}}
      set form_fields [my create_form_fields $field_names]
      set form [my regsub_eval  \
		    [template::adp_variable_regexp] $form \
		    {my form_field_as_html -mode display "\\\1" "\2" $form_fields}]
      
      dom parse -simple -html $form doc
      $doc documentElement root
      my set_form_data  $form_fields
      return [Form disable_input_fields [$root asHTML]]
    }
  }

  FormPage instproc get_value {before varname} {
    #my msg "varname=$varname"
    array set __ia [my set instance_attributes]
    switch -glob $varname {
      _*      {set value [my set [string range $varname 1 end]]}
      default {
        if {[info exists __ia($varname)]} {
          set value [set __ia($varname)]
        } elseif {[my exists $varname]} {
          set value [my $varname]
        } else {
          my log "**** unknown variable '$varname' ****"
          #my msg "**** [my set instance_attributes]"
          set value ""
        }
      }
    }

    set f [my create_raw_form_field -name $varname \
               -slot [my find_slot [string trimleft $varname _]] \
               -configuration [list -value $value]]
    if {[$f hide_value]} {
      set value ""
    } else {
      set value [$f pretty_value $value]
    }
    return $before$value
  }

  FormPage instproc adp_subst {content} {
    set content [my regsub_eval -noquote true \
                     [template::adp_variable_regexp] " $content" {my get_value "\\\1" "\2"}]
    #regsub -all  $content {\1@\2;noquote@} content
    return [string range $content 1 end]
  }

  Page instproc is_new_entry {old_name} {
    return [expr {[my publish_status] eq "production" && $old_name eq [my revision_id]}]
  }

  Page instproc save_data {{-use_given_publish_date:boolean false} old_name category_ids} {
    #my log "-- [self args]"
    my instvar package_id name
    db_transaction {
      #
      # if the newly created item was in production mode, but ordinary entries
      # are not, change on the first save the status to ready
      #
      if {[my is_new_entry $old_name]} {
        if {![$package_id get_parameter production_mode 0]} {
          my set publish_status "ready"
        }
      }
       # could be optimized, if we do not want to have categories (form constraints?)
      category::map_object -remove_old -object_id [my item_id] $category_ids

      my save -use_given_publish_date $use_given_publish_date
      # my log "-- old_name $old_name, name $name"
      if {$old_name ne $name} {
        my log "--formpage renaming"
        db_dml [my qn update_rename] "update cr_items set name = :name \
                where item_id = [my item_id]"
      }
    }
    return [my item_id]
  }

}

source [file dirname [info script]]/xowiki-www-procs.tcl

