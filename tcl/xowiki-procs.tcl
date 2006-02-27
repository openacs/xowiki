ad_library {
    XoWiki - main libraray classes and objects

    @creation-date 2006-01-10
    @author Gustaf Neumann
    @cvs-id $Id$
}

namespace eval ::xowiki {
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

  Object instproc save_new {} {
    #my set text [::Serializer deepSerialize [self]]
    next
  }

}

# the following block is legacy code
# ::Generic::CrClass create CrWikiPage -superclass ::xowiki::Page \
#     -pretty_name "Wiki Page" -pretty_plural "Wiki Pages" \
#     -table_name "generic_cr_wiki_page" -id_column "page_id" \
#     -form ::xowiki::WikiForm -object_type "CrWikiPage"

# ::Generic::CrClass create CrWikiPlainPage -superclass ::xowiki::PlainPage \
#     -pretty_name "Plain Wiki Page" -pretty_plural "Plain Wiki Pages" \
#     -table_name "generic_cr_plain_page" -id_column "ppage_id" \
#     -form ::xowiki::PlainWikiForm -object_type "CrWikiPlainPage"

# ::Generic::CrClass create PageTemplate -superclass ::xowiki::PageTemplate \
#     -pretty_name "Page Template" -pretty_plural "Page Templates" \
#     -table_name "generic_page_template" -id_column "page_template_id" \
#     -form ::xowiki::WikiForm  -object_type "PageTemplate"
 
# ::Generic::CrClass create PageInstance -superclass ::xowiki::PageInstance \
#     -pretty_name "Page Instance" -pretty_plural "Page Instances" \
#     -table_name "generic_page_instance" -id_column "page_instance_id" \
#     -object_type "PageInstance" \
#     -cr_attributes {
#       ::Generic::Attribute new -attribute_name page_template -datatype integer \
# 	  -pretty_name "Page Template"
#       ::Generic::Attribute new -attribute_name instance_attributes -datatype text \
# 	  -pretty_name "Instance Attributes" 
#     } \
#     -form ::xowiki::PageInstanceForm \
#     -edit_form ::xowiki::PageInstanceEditForm
 

if {![db_0or1row check-xowiki-table \
	  "select tablename from pg_tables where tablename = 'xowiki_references'"]} {
  db_dml create-xowiki-table "create table xowiki_references(
	reference integer references cr_items(item_id) on delete cascade, 
        link_type text,
        page      integer references cr_items(item_id) on delete cascade)"
  db_dml create-xowiki-table \
      "create index xowiki_ref_index ON xowiki_references(reference)"
}

namespace eval ::xowiki {

  ad_proc ::xowiki::upgrade_callback {
    {-from_version_name:required}
    {-to_version_name:required}
  } {
    
    Callback for upgrading 

    @author Gustaf Neumann (neumann@wu-wien.ac.at)
  } {
    ns_log notice "-- UPGRADE $from_version_name -> $to_version_name" 

    if {$to_version_name eq "0.13"} {
      ns_log notice "-- upgrading to 0.13"
      set package_id [::Generic::package_id_from_package_key xowiki]
      set folder_id  [::xowiki::Page require_folder \
			 -package_id $package_id \
			 -name xowiki]
      set r [::CrWikiPage instantiate_all -folder_id $folder_id]
      db_transaction {
	array set map {
	  ::CrWikiPage      ::xowiki::Page
	  ::CrWikiPlainPage ::xowiki::PlainPage
	  ::PageTemplate    ::xowiki::PageTemplate
	  ::PageInstance    ::xowiki::PageInstance
	}
	foreach e [$r children] {
	  set oldClass [$e info class]
	  if {[info exists map($oldClass)]} {
	    set newClass $map($oldClass)
	    ns_log notice "-- old class [$e info class] -> $newClass, \
			fetching [$e set item_id] "
	    [$e info class] fetch_object -object $e -item_id [$e set item_id]
	    set oldtitle [$e set title]
	    $e append title " (old)"
	    $e save
	    $e class $newClass
	    $e set title $oldtitle
	    $e save_new
	  } else {
	    ns_log notice "-- no new class for $oldClass"
	  }
	}	
      }
    }

    if {[apm_version_names_compare $from_version_name "0.19"] == -1 &&
	[apm_version_names_compare $to_version_name "0.19"] > -1} {
      ns_log notice "-- upgrading to 0.19"
      ::xowiki::sc::register_implementations
    }

    if {[apm_version_names_compare $from_version_name "0.21"] == -1 &&
	[apm_version_names_compare $to_version_name "0.21"] > -1} {
      ns_log notice "-- upgrading to 0.21"
	db_1row create_att {
	  select content_type__create_attribute(
		'::xowiki::Page','page_title','text',
                'Page Title',null,null,null,'text'	)}
        db_1row create_att {
	  select content_type__create_attribute(
		'::xowiki::Page','creator','text',
                'Creator',null,null,null,'text'  	)}
      db_1row refresh "select content_type__refresh_view('::xowiki::PlainPage') from dual"
      db_1row refresh "select content_type__refresh_view('::xowiki::PageTemplate') from dual"
      db_1row refresh "select content_type__refresh_view('::xowiki::PageInstance') from dual"
      db_1row refresh "select content_type__refresh_view('::xowiki::Object') from dual"
    }
    
    if {[apm_version_names_compare $from_version_name "0.22"] == -1 &&
	[apm_version_names_compare $to_version_name "0.22"] > -1} {
      ns_log notice "-- upgrading to 0.22"
      set folder_ids [list]
      set package_ids [list]
      db_foreach get_xowiki_packages {select * from apm_packages where package_key = 'xowiki'} {
	set folder_id [db_string get_folder_id "select f.folder_id from cr_items c, cr_folders f \
		where c.name = 'xowiki: $package_id' and c.item_id = f.folder_id"]
	if {$folder_id ne ""} {
	  db_dml update_package_id {update cr_folders set package_id = :package_id 
	    where folder_id = :folder_id}
	  lappend folder_ids $folder_id
	  lappend package_ids $package_id
	}
      }
      foreach f $folder_ids p $package_ids {
	db_dml update_context_ids "update acs_objects set context_id = $p where object_id = $f"
      }
    }
  }

  Class create WikiForm -superclass ::Generic::Form \
      -parameter {
	{field_list {item_id title page_title creator text description nls_language}} 
	{f.item_id 
	  {item_id:key}}
	{f.title 
	  {title:text {label #xowiki.name#} {html {size 80}} }}
	{f.page_title
	  {page_title:text {label #xowiki.title#} {html {size 80}} }}
	{f.creator
	  {creator:text,optional {label #xowiki.creator#}  {html {size 80}} }}
	{f.text 
	  {text:richtext(richtext),nospell,optional 
	    {label #xowiki.content#} 
	    {options {editor xinha plugins {
	      GetHtml CharacterMap ContextMenu FullScreen
	      ListType TableOperations EditTag LangMarks Abbreviation OacsFs
	    } height 350px \$::xowiki::folderspec}}
	    {html {rows 15 cols 50 style {width: 100%}}}}
	}
	{f.description 
	  {description:text,optional {label #xowiki.description#}}
	}
	{f.nls_language 
	  {nls_language:text(select),optional {label Language} 
	    {options \[xowiki::locales\]}}}
	{validate 
	  {{title {\[::xowiki::validate_title\]} {Item with this name exists already}}}}
	{with_categories true}
	{submit_link "view"}
      }

  WikiForm instproc folderspec {value} {
     set ::xowiki::folderspec $value
  }
  WikiForm instproc mkFields {} {
    set fields ""
    foreach field [my field_list] {
      append fields [list [my set f.$field]] \n
    }
    my set fields $fields
  }

  proc ::xowiki::locales {} {
    set locales [lang::system::get_locales]
    set defpos [lsearch $locales [lang::conn::locale]]
    set locales [linsert [lreplace $locales $defpos $defpos] 0 \
		     [lang::conn::locale]]
    foreach l $locales {lappend lpairs [list $l $l]}
    return $lpairs
  }

  proc ::xowiki::page_templates {} {
    ::xowiki::f1 instvar data folder_id  ;# form has to be named ::xowiki::f1
    # transitional code begin
    set object_type [[$data info class] object_type]
    if {[string match "::xowiki::*" $object_type]} {
      set templateclass ::xowiki::PageTemplate
    } else {
      set templateclass ::PageTemplate
    }
    # transitional code end
    set q [$templateclass instance_select_query \
	       -folder_id $folder_id \
	       -select_attributes {title}]
    db_foreach get_page_templates $q {
      lappend lpairs [list $title $item_id]
    } if_no_rows {
      lappend lpairs [list "(No Page Template available)" ""]
    }
    return $lpairs
  }

  proc ::xowiki::validate_title {} {
    upvar title title nls_language nls_language folder_id folder_id
    if {![regexp {^..:} $title]} {
      if {$nls_language eq ""} {set nls_language [lang::conn::locale]}
      set title [string range $nls_language 0 1]:$title
    }
    if {[ns_set get [ns_getform] __new_p]} {
      return [expr {[CrItem lookup -title $title -parent_id $folder_id] == 0}]
    }
    return 1
  }

  WikiForm instproc handle_enhanced_text_from_form {} {
    my instvar data
    array set __tmp [ns_set array [ns_getform]]
    if {[info exists __tmp(text.format)]} {	
      $data set mime_type $__tmp(text.format) 
    }
  }
  WikiForm instproc update_references {} {
    my instvar data
    if {![my istype PageInstanceForm]} {
      ### danger: update references does an ad_eval, which breaks the  [template::adp_level] 
      ### ad_form! don't do it here. 
      $data render_adp false
      $data render -update_references
    }
    my set submit_link [::xowiki::Page pretty_link [$data set title]]?
  }

  WikiForm instproc new_request {} {
    my instvar data
    $data set creator [$data get_name [ad_conn user_id]]
    next
  }

  WikiForm instproc edit_request args {
    my instvar data
    if {[$data set creator] eq ""} {
      $data set creator [$data get_name [ad_conn user_id]]
    }
    next
  }

  WikiForm instproc new_data {} {
    my handle_enhanced_text_from_form
    set item_id [next]
    my update_references
    return $item_id
  }

  WikiForm instproc edit_data {} {
    my handle_enhanced_text_from_form
    set item_id [next]
    my update_references
    return $item_id
  }

  #
  # PlainWiki Form
  #

  Class create PlainWikiForm -superclass WikiForm \
      -parameter {
	{f.text 
	  {text:text(textarea),nospell,optional 
	    {label #xowiki.content#} 
	    {html {cols 80 rows 10}}}}
  }

  #
  # Object Form
  #

  Class create ObjectForm -superclass PlainWikiForm \
      -parameter {
	{f.text 
	  {text:text(textarea),nospell,optional 
	    {label #xowiki.content#} 
	    {html {cols 80 rows 15}}}}
	{with_categories  false}
      }

  ObjectForm instproc init {} {
    my instvar data
    if {[$data exists title]} {
      # don't call validate on the folder object, don't let people change its name
      set title [$data set title]
      if {$title eq "::[$data set parent_id]"} {
	my f.title  {title:text(inform) {label #xowiki.name#}}
	my validate {{title {1} {dummy}} }
	#my log "--e don't validate folder id - parent_id = [$data set parent_id]"
      }
    }
    next
  }

  ObjectForm instproc new_request {} {
    my instvar data
    permission::require_permission \
	-party_id [ad_conn user_id] -object_id [$data set parent_id] \
	-privilege "admin"
    next
  }

  ObjectForm instproc edit_request {item_id} {
    my instvar data
    my log "--e setting f.title"
    my f.title {{title:text {label #xowiki.name#}}}
    permission::require_permission \
	-party_id [ad_conn user_id] -object_id [$data set parent_id] \
	-privilege "admin"
    next
  }
      
  ObjectForm instproc edit_data {} {
    my instvar data
    $data set_payload [$data set text]
    next
  }

  #
  # PageInstance Forms
  #

  Class create PageInstanceForm -superclass WikiForm \
      -parameter {
	{field_list {item_id title page_template description nls_language}} 
	{f.page_template 
	  {page_template:text(select) 
	    {label "Page Template"}
	    {options \[xowiki::page_templates\]}}
	}
	{with_categories  false}
      }
  PageInstanceForm instproc set_submit_link_edit {} {
    my instvar folder_id data
    set __vars {folder_id item_id page_template}
    set object_type [[$data info class] object_type]
    my log "-- data=$data cl=[$data info class] ot=$object_type"    
    set item_id [$data set item_id]
    set page_template [ns_set get [ns_getform] page_template]
    my submit_link [export_vars -base edit {folder_id object_type item_id page_template}]
    my log "-- submit_link = [my submit_link]"
  }
  PageInstanceForm instproc new_data {} {
    my instvar data
    my log "-- 1 $data, cl=[$data info class] [[$data info class] object_type]"
    set item_id [next]
    my log "-- 2 $data, cl=[$data info class] [[$data info class] object_type]"
    my set_submit_link_edit
    return $item_id
  }

  PageInstanceForm instproc edit_data {} {
    set item_id [next]
    my log "-- edit_data item_id=$item_id"
    return $item_id
  }

  Class create PageInstanceEditForm -superclass WikiForm \
      -parameter {
 	{field_list {item_id title page_title creator page_template description nls_language}} 
 	{f.title          {title:text(inform)}}
 	{f.page_template  {page_template:text(hidden)}}
 	{f.nls_language   {nls_language:text(hidden)}}
	{with_categories  true}
	{textfieldspec    {text(textarea),nospell {html {cols 60 rows 5}}}}
      }

  PageInstanceEditForm instproc new_data {} {
    set __vars {folder_id item_id page_template}
    set object_type [[[my set data] info class] object_type]
    my log "-- cl=[[my set data] info class] ot=$object_type"    
    foreach __v $__vars {set $__v [ns_queryget $__v]} 
    set item_id [next]
    my submit_link [export_vars -base edit $__vars]
    my log "-- submit_link = [my submit_link]"
    return $item_id
  }

  PageInstanceEditForm instproc edit_request {item_id} {
    my log "-- "
    my instvar page_instance_form_atts data
    next
    array set __ia [$data set instance_attributes]
    foreach var $page_instance_form_atts {
      if {[info exists __ia($var)]} {my var $var [list $__ia($var)]}
    }
  }


  PageInstanceEditForm instproc edit_data {} {
    my log "-- "
    my instvar page_instance_form_atts data
    array set __ia [$data set instance_attributes]
    foreach var $page_instance_form_atts {
      set __ia($var) [my var $var]
    }
    my log "-- set instance_attributes [array get __ia]"
    $data set instance_attributes [array get __ia]
    set item_id [next]
    my log "-- edit_data item_id=$item_id"
    return $item_id
  }

  PageInstanceEditForm instproc init {} {
    my instvar data page_instance_form_atts 
    set item_id [ns_queryget item_id]
    set page_template [ns_queryget page_template]
    if {$page_template eq ""} {
      set page_template [$data set page_template]
      my log  "-- page_template = $page_template"
    }
    my log  "-- calling page_template = $page_template"
    set template [::Generic::CrItem instantiate -item_id $page_template]
    $template volatile
    set dont_edit [concat [[$data info class] edit_atts] [list page_title] \
		       [::Generic::CrClass set common_query_atts]]
    set page_instance_form_atts [list]
    foreach {_1 _2 var} [regexp -all -inline \
			     [template::adp_variable_regexp] \
			     [$template set text]] {
      if {[lsearch $dont_edit $var] == -1} {lappend page_instance_form_atts $var}
    }

    foreach __var $page_instance_form_atts {
      my lappend field_list $__var
      my set f.$__var "$__var:[$data get_field_type $__var $template [my textfieldspec]]"
    }
    next
    #my log "--fields = [my fields]"
  }

}
 

namespace eval ::xowiki {
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

  Page instproc get_name {uid} {
    if {$uid ne "" && $uid != 0} {
      acs_user::get -user_id $uid -array user
      return "$user(first_names) $user(last_name)"
    } else {
      return nobody
    }
  }

  Page proc pretty_link {-lang title} {
    my instvar url_prefix
    if {![info exists lang]} {
      regexp {^(..):(.*)$} $title _ lang title
    }
    if {[info exists lang]} {
      return ${url_prefix}pages/$lang/[ad_urlencode $title]
    } else {
      return ${url_prefix}pages/[ad_urlencode $title]
    }
  }

  Page instproc initialize_loaded_object {} {
    my instvar page_title creator
    if {[info exists page_title] && $page_title eq ""} {set page_title [my set title]}
    #if {$creator eq ""} {set creator [my get_name [my set creation_user]]}
    next
  }

  Page ad_proc require_folder_object {
    -folder_id
    -package_id:required 
  } {
  } {
    if {![::xotcl::Object isobject ::$folder_id]} {
      set item_id [ns_cache eval xotcl_object_type_cache item-of-$folder_id {
	set item_id [CrItem lookup -title ::$folder_id -parent_id $folder_id]
      }]
      if {$item_id != 0} {
	#my log "--f fetch folder object -object ::$folder_id -item_id $item_id"
	set o [::xowiki::Object fetch_object -object ::$folder_id -item_id $item_id]
      } else {
	ns_cache flush xotcl_object_type_cache item-of-$folder_id
	#my log "--f save new folder object"
	set o [::xowiki::Object create ::$folder_id]
	$o set text "# this is the payload of the folder object\n\nset index_page \"\"\n"
	$o set parent_id $folder_id
	$o set title ::$folder_id
	$o save_new
	$o initialize_loaded_object
      }
      #$o proc destroy {} {my log "--f "; next}
      $o set package_id $package_id
      #my log "--f package_id set, exists $o -> [::xotcl::Object isobject $o]"
      uplevel #0 [list $o volatile]
    } else {
      #my log "--f reuse folder object $folder_id [::Serializer deepSerialize ::$folder_id]"
    }
  }

  Page proc import {-user_id -package-id -folder-id {-replace 0} -objects} {
    set object_type [self]
    if {![info exists folder_id]}  {set folder_id [$object_type require_folder -name xowiki]}
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
      set item [CrItem lookup -title [$o set title] -parent_id $folder_id]
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
	  set item [CrItem lookup -title [$o set title] -parent_id $folder_id]
	  if {$item != 0 && $replace} { ;# we delete the original
	    ::Generic::CrItem delete -item_id $item 
	    set item 0
	    incr replaced
	  }
	  if {$item == 0} {  ;# the item does not exist -> update reference and save
	    set old_template_id [$o set page_template]
	    set template [CrItem lookup \
			      -title [$old_template_id set title] \
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
  # data definitions
  #

  Page parameter {
    page_id 
    {revision_id 0}
    object_type 
    {folder_id -100} 
    {lang_links ""} 
    {lang de}
    {render_adp 1}
  }
  Page set recursion_count 0
  Page array set RE {
    include {{{(.+)}}[ \n\r]*(<br */*>)?} 
    anchor {\\\[\\\[([^\]]+)\\\]\\\]}
    div    { *(<br */*> *)?&gt;&gt;([^&]*)&lt;&lt;}
  }

  PlainPage parameter {
    {render_adp 0}
  }
  PlainPage array set RE {
    include {{{(.+)}}[ \n\r]} 
    anchor {\\\[\\\[([^\]]+)\\\]\\\]}
    div    {()>>([^<]*)<<}
  }

  PageTemplate parameter {
    {render_adp 0}
  }

  #
  # method definitions
  #

  Page instproc regsub-eval {re string cmd} {
    subst [regsub -all $re [string map {\[ \\[ \] \\] \$ \\$ \\ \\\\} $string] \
	       "\[$cmd\]"]
  }

  Page instproc include arg {
    [self class] instvar recursion_depth
    if {[regexp {^adp (.*)$} $arg _ adp]} {
      set adp_fn [lindex $adp 0] 
      if {![string match "/*" $adp_fn]} {set adp_fn /packages/xowiki/www/$adp_fn}
      set adp_args [concat [lindex $adp 1] [list __including_page [self]]]
      return [template::adp_include $adp_fn $adp_args]
    }
  }
  Page instproc div arg {
    if {$arg eq "content"} {
      return "<div id='content' class='column'>"
    } elseif {[lsearch [list \
			    left-col  left-col25  left-col30 \
			    right-col right-col25 right-col30 right-col70] \
		   $arg] > -1} {
      return "<div id='$arg' class='column'>"
    } elseif {$arg eq "box"} {
      return "<div class='box'>"
    } elseif {$arg eq ""} {
      return "</div>"
    }
  }
  Page instproc anchor arg {
    set label $arg
    set link $arg
    regexp {^(.*)[|](.*)$} $arg _ link label
    if {[string match "http*//*" $link]} {
      return "<a class='external' href='$link'>$label</a>"
    } else {
      set specified_link $link
      my instvar parent_id 
      Page instvar url_prefix
      [my info class]  instvar object_type
      if {[regexp {^:(..):(.*)$} $link _ lang stripped]} {
	set lang_item_id [CrItem lookup \
			      -title $lang:$stripped -parent_id $parent_id]
	#my log "lang lookup for '$lang:$stripped' returned $lang_item_id"
	if {$lang_item_id} {
	  set css_class "found"
	  set link [Page pretty_link -lang $lang $stripped]
	  #set link [export_vars -base view {{item_id $lang_item_id}}]
	} else {
	  set css_class "undefined"
	  set last_page_id [my set item_id]
	  set link [export_vars -base ${url_prefix}edit {object_type {title $lang:$stripped} last_page_id}]
	}
	my lappend lang_links \
	    "<a href='$link'><img class='$css_class' style='height='12' \
		src='/resources/xowiki/flags/$lang.png' alt='$lang'></a>"
	return ""
      }
      set link_type link
      regexp {^([^:]+):([^:]+:.*)$} $link _ link_type link
      if {[regexp {^(..):(.*)$} $link _ lang stripped_name]} {
	if {$label eq $arg} {set label $stripped_name}
	set name $link
      } {
	set stripped_name $link
	set name [my lang]:$link
	set lang [my lang]
      }
      set item_id [::Generic::CrItem lookup -title $name -parent_id $parent_id]
      if {$item_id} {
	my lappend references [list $item_id $link_type]
	#set link [export_vars -base view {item_id}]
	#return "<a href='$link'>$label</a>"
	return "<a href='[Page pretty_link -lang $lang $stripped_name]'>$label</a>"
      } else {
	my incr unresolved_references
	set link [export_vars -base ${url_prefix}edit {object_type {title $label}}]
	return "<a href='$link'> \[ </a>$label <a href='$link'> \] </a>" 
      }
    }
  }

  Page instproc references {} {
    [my info class] instvar table_name 
    my instvar item_id url_prefix
    set l [db_list_of_lists references \
	       "SELECT page,ci.name,link_type from xowiki_references, cr_items ci \
		       where reference=$item_id and ci.item_id = page"]
    set refs [list]
    foreach e $l {
      #set link [export_vars -base view {{item_id {[lindex $e 0]}}}]
      set link [lindex $e 1]
      lappend refs "<a href='[Page pretty_link $link]'>$link</a>"
    }
    return [join $refs ", "]
  }

  Page instproc substitute_markup {source} {
    set baseclass [expr {[[my info class] exists RE] ? [my info class] : [self class]}]
    $baseclass instvar RE
    #my log "-- baseclass for RE = $baseclass"
    if {[my set mime_type] eq "text/enhanced"} {
      set source [ad_enhanced_text_to_html $source]
    }
    set content ""
    foreach l [split [lindex $source 0] \n] {
      set l [my regsub-eval $RE(include) $l {my include "\1"}]
      set l [my regsub-eval $RE(anchor)  $l {my anchor "\1"}]
      set l [my regsub-eval $RE(div)     $l {my div "\2"}]
      append content $l \n
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
    if {[catch {set template_value [template::adp_eval template_code]} errmsg]} {
      return "Error in Page $title: $errmsg<br>$content<p>Possible values are$__template_variables__"
    }
    return $template_value
  }

  Page instproc get_content {} {
    my log "--"
    set content [my substitute_markup [my set text]]
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

    set package_id [$parent_id set package_id]
    Page set url_prefix [site_node::get_url_from_object_id -object_id $package_id]
    set title [my set title]
    regexp {^(..):(.*)$} $title _ lang title
    set references [list]
    set unresolved_references 0
    set content [my get_content]
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

  #
  # Plain Page methods
  #

  PlainPage instproc get_content {} {
    #my log "-- my class=[my info class]"
    return [my substitute_markup [my set text]]
  }

  PlainPage instproc substitute_markup {source} {
    [self class] instvar RE
    set content ""
    foreach l [split $source \n] {
      set l [my regsub-eval $RE(include) $l {my include "\1"}]
      set l [my regsub-eval $RE(anchor)  $l {my anchor "\1"}]
      set l [my regsub-eval $RE(div)     $l {my div "\2"}]
      append content $l \n
    }
    return $content
  }

  #
  # Page Instance methods
  #

  PageInstance instproc get_field_type {name template default_spec} {
    # get the widget field specifications from the payload of the folder object 
    # for a field with a specified name in a specified page template
    set spec $default_spec
    foreach {s widget} [[my set parent_id] get_payload widget_specs] {
      foreach {template_name var_name} [split $s ,] break
      #ns_log notice "--w T.title = '[$template set title]' var=$name"
      if {[string match $template_name [$template set title]] &&
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
    uplevel #0 [list $page_template volatile]
    #return [my substitute_markup [my adp_subst [$page_template set text]]]
    if {[my set instance_attributes] eq ""} {
      return [my adp_subst [$page_template set text]]
    }
    set T [my adp_subst [$page_template set text]]
    #my log T=$T
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
  # Methods of the object Object
  #

  Object instproc get_content {} {
    if {[[self]::payload info procs content] ne ""} {
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
    if {![my isobject $payload]} {::xotcl::Object create $payload -requireNamespace}
    if {[catch {$payload eval $cmd} error ]} {
      ns_log error "XoWiki folder object: content lead to error: $error"
    }
  }
  Object instproc get_payload {var} {
    set payload [self]::payload
    if {![my isobject $payload]} {::xotcl::Object create $payload -requireNamespace}
    expr {[$payload exists $var] ? [$payload set $var] : ""}
  }
}