namespace eval ::xowiki {

  ::Generic::CrClass create Page -superclass ::Generic::CrItem \
      -pretty_name "XoWiki Page" -pretty_plural "XoWiki Pages" \
      -table_name "xowiki_page" -id_column "page_id" \
      -mime_type text/html \
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
  ns_log notice "xowiki create"
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
    if {$to_version_name eq "0.19"} {
      ns_log notice "-- upgrading to 0.19"
      ::xowiki::sc::register_implementations
    }
  }

  Class create WikiForm -superclass ::Generic::Form \
      -parameter {
	{field_list {item_id title text description nls_language}} 
	{f.item_id 
	  {item_id:key}}
	{f.title 
	  {title:text {label #xowiki.name#}}}
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
	  {{title {\[::xowiki::validate_title\]} {correcting locale}}}}
	{with_categories true}
	{submit_link view}
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
    upvar title title nls_language nls_language
    if {![regexp {^..:} $title]} {
      if {$nls_language eq ""} {set nls_language [lang::conn::locale]}
      set title [string range $nls_language 0 1]:$title
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
    $data render_adp false
    $data render -update_references
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


  Class create PlainWikiForm -superclass WikiForm \
      -parameter {
	{f.text 
	  {text:text(textarea),nospell,optional 
	    {label #xowiki.content#} 
	    {html {cols 80 rows 10}}}}
  }

  Class create PageInstanceForm -superclass WikiForm \
      -parameter {
	{field_list {item_id title page_template description nls_language}} 
	{f.page_template 
	  {page_template:text(select) 
	    {label "Page Template"}
	    {options \[xowiki::page_templates\]}}
	}
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
    my log "-- new data next DONE item_id=$item_id"
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
 	{field_list {item_id title page_template description nls_language}} 
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
    foreach var $page_instance_form_atts {
      my lappend field_list $var
      my set f.$var "$var:[my textfieldspec]"
    }
    next
    #my log "--fields = [my fields]"
  }

}
 

namespace eval ::xowiki {

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
    } elseif {$arg eq "sidebar"} {
      return "<div id='sidebar' class='column'>"
    } elseif {$arg eq "left-col"} {
      return "<div id='left-col' class='column'>"
    } elseif {$arg eq "right-col"} {
      return "<div id='right-col' class='column'>"
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
      [my info class]  instvar object_type
      if {[regexp {^:(..):(.*)$} $link _ lang stripped]} {
	set lang_item_id [CrItem lookup \
			      -title $lang:$stripped -parent_id $parent_id]
	my log "lang lookup for '$lang:$stripped' returned $lang_item_id"
	if {$lang_item_id} {
	  set css_class "found"
	  set link ./[ad_urlencode $lang:$stripped]
	  #set link [export_vars -base view {{item_id $lang_item_id}}]
	} else {
	  set css_class "undefined"
	  set last_page_id [my set item_id]
	  set link [export_vars -base edit {object_type {title $lang:$stripped} last_page_id}]
	}
	my lappend lang_links \
	    "<a href='$link'><img class='$css_class' style='height='12' \
		src='/resources/xowiki/flags/$lang.png' alt='$lang'></a>"
	return ""
      }
      set link_type link
      regexp {^([^:]+):([^:]+:.*)$} $link _ link_type link
      if {[regexp {^..:(.*)$} $link _ stripped_label]} {
	if {$label eq $arg} {set label $stripped_label}
      } {
	set link [my lang]:$link
      }
      set item_id [::Generic::CrItem lookup \
		       -title $link -parent_id $parent_id]
      if {$item_id} {
	my lappend references [list $item_id $link_type]
	#set link [export_vars -base view {item_id}]
	#return "<a href='$link'>$label</a>"
	return "<a href='./[ad_urlencode $specified_link]'>$label</a>"
      } else {
	my incr unresolved_references
	set link [export_vars -base ../edit {object_type {title $label}}]
	return "<a href='$link'> \[ </a>$label <a href='$link'> \] </a>" 
      }
    }
  }

  Page instproc references {} {
    [my info class] instvar table_name 
    my instvar item_id
    set l [db_list_of_lists references \
	       "SELECT page,ci.name,link_type from xowiki_references, cr_items ci \
		       where reference=$item_id and ci.item_id = page"]
    set refs [list]
    foreach e $l {
      #set link [export_vars -base view {{item_id {[lindex $e 0]}}}]
      set link [lindex $e 1]
      if {[string range $link 0 2] eq "[my lang]:"} {set link [string range $link 3 end]}
      lappend refs "<a href=' ./[ad_urlencode $link]'>$link</a>"
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
    my instvar item_id references lang title render_adp unresolved_references
    my log "-- my class=[my info class]"
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
    my log "-- my class=[my info class]"
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

  PageInstance instproc get_content {} {
    my instvar page_template
    #my log  "-- fetching page_template = $page_template"
    ::Generic::CrItem instantiate -item_id $page_template
    $page_template volatile
    return [my substitute_markup [my adp_subst [$page_template set text]]]
  }
  PageInstance instproc adp_subst {content} {
    # add extra variables as instance variables
    array set __ia [my set instance_attributes]
    foreach var [array names __ia] {
      #my log "-- set $var [list $__ia($var)]"
      my set $var $__ia($var)
    }
    next
  }
}