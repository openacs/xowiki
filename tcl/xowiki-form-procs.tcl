ad_library {
    XoWiki - form classes

    @creation-date 2006-04-10
    @author Gustaf Neumann
    @cvs-id $Id$
}

namespace eval ::xowiki {

  #
  # Application specific forms
  #

  Class create WikiForm -superclass ::Generic::Form \
      -parameter {
	{field_list {item_id name title creator text description nls_language}}
	{f.page_order
	  {page_order:text,optional {label #xowiki.order#} {html {align right}} }}
	{f.item_id
	  {item_id:key}}
	{f.name
	  {name:text {label #xowiki.name#} {html {size 80}} }}
	{f.title
	  {title:text {label #xowiki.title#} {html {size 80}} }}
	{f.creator
	  {creator:text,optional {label #xowiki.creator#}  {html {size 80}} }}
	{f.text
	  {text:richtext(richtext),nospell,optional
	    {label #xowiki.content#}
	    {options {editor xinha plugins {
[parameter::get -parameter "XowikiXinhaDefaultPlugins" -default [parameter::get_from_package_key -package_key "acs-templating" -parameter "XinhaDefaultPlugins"]]
	    } height 350px 
            }}
            {html {rows 15 cols 50 style {width: 100%}}}}
        }
        {f.description
          {description:text(textarea),nospell,optional 
            {label #xowiki.description#} {html {cols 80 rows 2}}}
        }
        {f.nls_language
          {nls_language:text(select),optional {label #xowiki.Language#}
            {options \[xowiki::locales\]}}}
        {validate
          {{name {\[::xowiki::validate_name\]} {Another item with this name exists \
                already in this folder}}}}
        {with_categories true}
        {submit_link "view"}
        {folderspec ""}
        {autoname 0}
      }

  WikiForm instproc show_page_order {} {
    my instvar data
    return [expr {[::xo::db::has_ltree] && [[$data package_id] get_parameter display_page_order 1]}]
  }

  WikiForm instproc mkFields {} {
    my instvar data autoname
    set __fields ""
    set field_list [my field_list]
    if {[my show_page_order]} {set field_list [linsert $field_list 2 page_order]}
    if {$autoname} {
      my f.name {name:text(hidden),optional}
    }
    foreach __field $field_list {
      set __spec [my set f.$__field]
      if {[string first "richtext" [lindex $__spec 0]] > -1} {
        # we have a richtext widget; get special configuration is specified
        set __spec [$data get_rich_text_spec $__field $__spec]
        if {[my folderspec] ne ""} {
          # append the folder spec to its options
          set __newspec [list [lindex $__spec 0]]
          foreach __e [lrange $__spec 1 end] {
            foreach {__name __value} $__e break
            if {$__name eq "options"} {eval lappend __value [my folderspec]}
            lappend __newspec $__name $__value
          }
          my log "--F rewritten spec is '$__newspec'"
          set __spec $__newspec
        }
        # ad_form does a subst. escape esp. the javascript stuff
        set __spec [string map {\[ \\[ \] \\] \$ \\$ \\ \\\\} $__spec]
      }
      #my log "--F field <$__field> = $__spec"
      append __fields [list $__spec] \n
    }
    my set fields $__fields
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
               -select_attributes {name}]
    db_foreach get_page_templates $q {
      lappend lpairs [list $name $item_id]
    } if_no_rows {
      lappend lpairs [list "(No Page Template available)" ""]
    }
    return $lpairs
  }

  #
  # this should be OO-ified -gustaf
  proc ::xowiki::validate_file {} {
    #my log "--F validate_file data=[my exists data]"
    my instvar data
    my get_uploaded_file
    #my log "--F validate_file returns [$data exists import_file]"
    upvar title title
    if {$title eq ""} {set title [$data set upload_file]}
    return [$data exists import_file]
  }

  proc ::xowiki::guesstype {fn} {
    set mime [ns_guesstype $fn]
    if {$mime eq "*/*"} {
      # ns_guesstype was failing
      switch [file extension $fn] {
        .mp3 {set mime audio/mpeg}
        .cdf {set mime application/x-netcdf}
      }
    }
    return $mime
  }

  proc ::xowiki::validate_name {} {
    upvar name name nls_language nls_language folder_id folder_id \
        object_type object_type mime_type mime_type
    my instvar data
    my log "--F validate_name ot=$object_type data=[my exists data]"
    $data instvar package_id
    if {$object_type eq "::xowiki::File" && [$data exists mime_type]} {
      #my get_uploaded_file
      #my log "--mime validate_name ot=$object_type data=[my exists data] MIME [$data set mime_type]"
      set mime [$data set mime_type]
      set fn [$data set upload_file]
      #my log "--mime=$mime"
      switch -- $mime {
        application/force-download {
          set mime [::xowiki::guesstype $fn]
          $data set mime_type $mime
        }
      }
      #my log "--mime 2 = $mime"
      switch -glob -- $mime {
        image/* {set type image}
        default {set type file}
      }
      if {$name ne ""} {
        regexp {^(.*):(.*)$} $name _ _t stripped_name
        if {![info exists stripped_name]} {set stripped_name $name}
      } else {
        set stripped_name $fn
      }
      set name ${type}:[::$package_id normalize_name $stripped_name]
    } else {
      if {![regexp {^..:} $name]} {
        if {![info exists nls_language]} {set nls_language ""}
        if {$nls_language eq ""} {set nls_language [lang::conn::locale]}
        if {$name ne ""} {
          # prepend the language prefix only, if the entry is not empty
          set name [string range $nls_language 0 1]:$name
        }
      }
      set name [::$package_id normalize_name $name]
    }

    # check, if we try to create a new item with an existing name
    if {[$data form_parameter __new_p] 
        || [$data form_parameter __object_name] ne $name
      } {
      return [expr {[CrItem lookup -name $name -parent_id $folder_id] == 0}]
    }
    return 1
  }

  WikiForm instproc data_from_form {{-new 0}} {
    my instvar data
    if {[$data exists_form_parameter text.format]} {
      $data set mime_type [$data form_parameter text.format]
    }
    if {$new && [[$data set package_id] get_parameter production_mode 0]} {
      $data set publish_status production
    }
  }
  WikiForm instproc update_references {} {
    my instvar data
    if {![my istype PageInstanceForm]} {
      ### danger: update references does an ad_eval, which breaks the [template::adp_level]
      ### ad_form! don't do it in pageinstanceforms.
      $data render_adp false
      $data render -update_references
    }
    # delete the link cache entries for this item 
    # could be made more intelligent to delete entries is more rare cases, like
    # in case the file was renamed
    my instvar folder_id
    ##### why is ns_cache names xowiki_cache *pattern*   not working??? 
    ##### upgrade ns_cache from CVS !
    foreach entry [ns_cache names xowiki_cache link-*-$folder_id] {
      array set tmp [ns_cache get xowiki_cache $entry]
      if {$tmp(item_id) == [$data set item_id]} {
        ns_cache flush xowiki_cache $entry
      }
    }
    if {![$data istype ::xowiki::Object] &&
        ![$data istype ::xowiki::PageTemplate] } {
      if {[$data istype ::xowiki::PageInstance]} {
        if {[$data set instance_attributes] ne ""} {
          # fieldless page instances are not notified. problem?
          # my log "--i instance_attributes = <[$data set instance_attributes]>"
          ::xowiki::notification::do_notifications -page $data
        }
      } else {
        ::xowiki::notification::do_notifications -page $data
      }
    }

    #my log "v=[ad_acs_version] 5.2] compare: [apm_version_names_compare [ad_acs_version] 5.2]"
    if {[apm_version_names_compare [ad_acs_version] 5.2.99] == 1} {
      application_data_link::update_links_from \
          -object_id [$data set item_id] \
          -text [$data set text]
    }
  }
  
    
  WikiForm instproc new_request {} {
    my instvar data
    $data set creator [::xo::get_user_name [ad_conn user_id]]
    next
  }

  WikiForm instproc edit_request args {
    my instvar data
    if {[$data set creator] eq ""} {
      $data set creator [::xo::get_user_name [ad_conn user_id]]
    }
    next
  }

  WikiForm instproc new_data {} {
    my instvar data
    my data_from_form -new 1 
    $data set __autoname_prefix [string range [$data set nls_language] 0 1]:
    set item_id [next]
    $data set creation_user [ad_conn user_id]
    my update_references
    return $item_id
  }

  WikiForm instproc edit_data {} {
    my data_from_form -new 0
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
  # File Form
  #

  Class create FileForm -superclass WikiForm \
      -parameter {
        {html { enctype multipart/form-data }} \
        {field_list {item_id name text title creator description}}
        {f.name    
          {name:text,nospell,optional 
            {help_text {Can be obtained from the name of the uploaded file}}}}
        {f.title
          {title:text,optional {label #xowiki.title#} {html {size 80}} }}
        {f.text
          {upload_file:file(file) 
            {label #xowiki.content#}
            {html {size 30}} }}
        {validate {
          {upload_file {\[::xowiki::validate_file\]} {For new entries, \
                                                          a upload file must be provided}}
          {name {\[::xowiki::validate_name\]} {Another item with this name exists \
                                                   already in this folder}}
          }}
        }

  FileForm instproc get_uploaded_file {} {
    my instvar data
    #my log "--F... [ns_conn url] [ns_conn query] form vars = [ns_set array [ns_getform]]"
    set upload_file [$data form_parameter upload_file]
    #my log "--F... upload_file = $upload_file"
    if {$upload_file ne ""} {
      $data set upload_file  $upload_file
      $data set import_file [$data form_parameter upload_file.tmpfile]
      $data set mime_type   [$data form_parameter upload_file.content-type]
    } else {
      #my log "--F no upload_file provided [lsort [$data info vars]]"
      if {[$data exists mime_type]} {
        my log "--mime_type=[$data set mime_type]"
        #my log "   text=[$data set text]"
        regexp {^[^:]+:(.*)$} [$data set name] _ upload_file
        $data set upload_file $upload_file
        $data set import_file [$data full_file_name]
        #my log "   import_type=[$data set import_file]"
      }
    }
  }
  FileForm instproc new_data {} {
    #my get_uploaded_file
    return [next]
  }
  FileForm instproc edit_data {} {
    #my get_uploaded_file
    return [next]
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
    if {[$data exists name]} {
      # don't call validate on the folder object, don't let people change its name
      set name [$data set name]
      if {$name eq "::[$data set parent_id]"} {
        my f.name  {name:text(inform) {label #xowiki.name#}}
        my validate {{name {1} {dummy}} }
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
    my f.name {{name:text {label #xowiki.name#}}}
    permission::require_permission \
        -party_id [ad_conn user_id] -object_id [$data set parent_id] \
        -privilege "admin"
    next
  }

  ObjectForm instproc edit_data {} {
    [my data] initialize_loaded_object
    next
  }

  #
  # PageInstance Forms
  #

  Class create PageInstanceForm -superclass WikiForm \
      -parameter {
        {field_list {item_id name page_template description nls_language}}
        {f.page_template
          {page_template:text(select)
            {label "Page Template"}
            {options \[xowiki::page_templates\]}}
        }
        {with_categories  false}
      }
  PageInstanceForm instproc set_submit_link_edit {} {
    my instvar folder_id data
    set object_type [[$data info class] object_type]
    #my log "-- data=$data cl=[$data info class] ot=$object_type"
    set item_id [$data set item_id]
    set page_template [$data form_parameter page_template]
    if {[$data exists_query_parameter return_url]} {
      set return_url [$data query_parameter return_url]
    }
    set link [::[$data set package_id] pretty_link [$data set name]]
    #my submit_link [export_vars -base edit {folder_id object_type item_id page_template return_url}]
    my submit_link [export_vars -base $link {{m edit} page_template return_url item_id}]
    my log "-- submit_link = [my submit_link]"
  }

  PageInstanceForm instproc new_data {} {
    my instvar data
    set item_id [next]
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
        {field_list {item_id name title creator page_template description nls_language}}
        {f.name           {name:text(inform)}}
        {f.page_template  {page_template:text(hidden)}}
        {f.nls_language   {nls_language:text(hidden)}}
        {with_categories  true}
        {textfieldspec    {text(textarea),nospell {html {cols 60 rows 5}}}}
      }

  PageInstanceEditForm instproc new_data {} {
    my instvar data
    set __vars {folder_id item_id page_template return_url}
    set object_type [[$data info class] object_type]
    #my log "-- cl=[[my set data] info class] ot=$object_type $__vars"
    foreach __v $__vars {set $__v [$data from_parameter $__v] ""}
    set item_id [next]

    set link [::[$data set package_id] pretty_link [$data set name]]
    my submit_link [export_vars -base $link {{m edit} $__vars}]
    #my submit_link [export_vars -base edit $__vars]
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
    set item_id [$data form_parameter item_id]
    set page_template [$data form_parameter page_template ""]
    if {$page_template eq ""} {
      set page_template [$data set page_template]
      #my log  "-- page_template = $page_template"
    }
    #my log  "-- calling page_template = $page_template"
    set template [::Generic::CrItem instantiate -item_id $page_template]
    $template volatile
    set dont_edit [concat [[$data info class] edit_atts] [list title] \
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

