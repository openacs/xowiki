ad_library {
    XoWiki - www procs. These procs are the methods called on xowiki pages via 
    the web interface.

    @creation-date 2006-04-10
    @author Gustaf Neumann
    @cvs-id $Id$
}


namespace eval ::xowiki {
  
  Page instproc htmlFooter {{-content ""}} {
    my instvar package_id description
    if {[my exists __no_footer]} {return ""}

    set footer "<hr/>"

    if {$description eq ""} {
      set description [my get_description $content]
    }
    
    #set ::META(description) $description

    if {[ns_conn isconnected]} {
      set url         "[ns_conn location][::xo::cc url]"
      set package_url "[ns_conn location][$package_id package_url]"
    }

    if {[$package_id get_parameter "with_tags" 1] && 
        ![my exists_query_parameter no_tags] &&
        [::xo::cc user_id] != 0
      } {
      set tag_content "[my include_portlet my-tags]<br>"
      set tag_includelet [my set __last_includelet]
      set tags [$tag_includelet set tags]
    } else {
      set tag_content ""
      set tags ""
    }

    if {[$package_id get_parameter "with_digg" 0] && [info exists url]} {
      append footer "<div style='float: right'>" \
          [my include_portlet [list digg -description $description -url $url]] "</div>\n"
    }

    if {[$package_id get_parameter "with_delicious" 0] && [info exists url]} {
      append footer "<div style='float: right; padding-right: 10px;'>" \
          [my include_portlet [list delicious -description $description -url $url -tags $tags]] \
          "</div>\n"
    }

    if {[$package_id get_parameter "with_yahoo_publisher" 0] && [info exists package_url]} {
      append footer "<div style='float: right; padding-right: 10px;'>" \
          [my include_portlet [list my-yahoo-publisher \
                                   -publisher [::xo::get_user_name [::xo::cc user_id]] \
                                   -rssurl "$package_url?rss"]] \
          "</div>\n"
    }

    append footer [my include_portlet my-references]  <br>
    
    if {[$package_id get_parameter "show_per_object_categories" 1]} {
      append footer [my include_portlet my-categories]  <br>
      set categories_includelet [my set __last_includelet]
    }

    append footer $tag_content

    if {[$package_id get_parameter "with_general_comments" 0] &&
        ![my exists_query_parameter no_gc]} {
      append footer [my include_portlet my-general-comments] <br>
    }

    return  "<div style='clear: both; text-align: left; font-size: 85%;'>$footer</div>\n"
  }

}

namespace eval ::xowiki {
  
  Page instproc view {{content ""}} {
    # view is used only for the toplevel call, when the xowiki page is viewed
    # this is not intended for embedded wiki pages
    my instvar package_id item_id 
    $package_id instvar folder_id  ;# this is the root folder
    ::xowiki::Page set recursion_count 0

    set template_file [my query_parameter "template_file" \
                           [::$package_id get_parameter template_file view-default]]

    if {[my isobject ::xowiki::$template_file]} {
      $template_file before_render [self]
    }
    
    if {$content eq ""} {
      set content [my render]
    }
    #my log "--after render"
    set footer [my htmlFooter -content $content]

    set top_portlets ""
    set vp [string trim [$package_id get_parameter "top_portlet" ""]]
    if {$vp ne ""} {
      set top_portlets [my include_portlet $vp]
    }

    if {[$package_id get_parameter "with_user_tracking" 1]} {
      my record_last_visited
    }

    # Deal with the views package (many thanks to Malte for this snippet!)
    if {[$package_id get_parameter with_views_package_if_available 1] 
	&& [apm_package_installed_p "views"]} {
      views::record_view -object_id $item_id -viewer_id [::xo::cc user_id]
      array set views_data [views::get -object_id $item_id]
    }

    # import title, name and text into current scope
    my instvar title name text

    if {[my exists_query_parameter return_url]} {
      set return_url [my query_parameter return_url]
    }
    
    if {[$package_id get_parameter "with_notifications" 1]} {
      if {[::xo::cc user_id] != 0} { ;# notifications require login
        set notifications_return_url [expr {[info exists return_url] ? $return_url : [ad_return_url]}]
        set notification_type [notification::type::get_type_id -short_name xowiki_notif]
        set notification_text "Subscribe the XoWiki instance"
        set notification_subscribe_link \
            [export_vars -base /notifications/request-new \
                 {{return_url $notifications_return_url}
                   {pretty_name $notification_text} 
                   {type_id $notification_type} 
                   {object_id $package_id}}]
        set notification_image \
           "<img style='border: 0px;' src='/resources/xowiki/email.png' \
	    alt='$notification_text' title='$notification_text'>"
      }
    }
    #my log "--after notifications [info exists notification_image]"

    set master [$package_id get_parameter "master" 1]
    #if {[my exists_query_parameter "edit_return_url"]} {
    #  set return_url [my query_parameter "edit_return_url"]
    #}
    my log "--after options"

    if {$master} {
      set context [list $title]
      set autoname    [$package_id get_parameter autoname 0]
      set object_type [$package_id get_parameter object_type [my info class]]
      set rev_link    [$package_id make_link [self] revisions]
      set edit_link   [$package_id make_link [self] edit return_url]
      set delete_link [$package_id make_link [self] delete return_url]
      if {[my istype ::xowiki::FormPage]} {
        set template_id [my page_template]
        set form      [$package_id pretty_link [$template_id name]]
        set new_link  [$package_id make_link -link $form $template_id create-new return_url]
      } else {
        set new_link  [$package_id make_link $package_id edit-new object_type return_url autoname] 
      }
      set admin_link  [$package_id make_link -privilege admin -link admin/ $package_id {} {}] 
      set index_link  [$package_id make_link -privilege public -link "" $package_id {} {}]
      set create_in_req_locale_link ""

      if {[$package_id get_parameter use_connection_locale 0]} {
        $package_id get_name_and_lang_from_path \
            [$package_id set object] req_lang req_local_name
        set default_lang [$package_id default_language]
        if {$req_lang ne $default_lang} {
          set l [Link create new -destroy_on_cleanup \
                     -page [self] -type language -stripped_name $req_local_name \
                     -name ${default_lang}:$req_local_name -lang $default_lang \
                     -label $req_local_name -folder_id $folder_id \
                     -package_id $package_id -init \
                     -return_only undefined]
          $l render
        }
      }

      #my log "--after context delete_link=$delete_link "
      set template [$folder_id get_payload template]
      set page [self]

      if {$template ne ""} {
        set __including_page $page
        set __adp_stub [acs_root_dir]/packages/xowiki/www/view-default
        set template_code [template::adp_compile -string $template]
        if {[catch {set content [template::adp_eval template_code]} errmsg]} {
          ns_return 200 text/html "Error in Page $name: $errmsg<br/>$template"
        } else {
          ns_return 200 text/html $content
        }
      } else {

        # use adp file
        foreach css [$package_id get_parameter extra_css ""] {::xo::Page requireCSS $css}
        # refetch it, since it might have been changed via set-parameter
        set template_file [my query_parameter "template_file" \
                               [::$package_id get_parameter template_file view-default]]

        if {![regexp {^[./]} $template_file]} {
          set template_file /packages/xowiki/www/$template_file
        }
        set header_stuff [::xo::Page header_stuff]
        $package_id return_page -adp $template_file -variables {
          name title item_id context header_stuff return_url
          content footer package_id
          rev_link edit_link delete_link new_link admin_link index_link 
          notification_subscribe_link notification_image 
          top_portlets page
          views_data
        }
      }
    } else {
      ns_return 200 [::xo::cc get_parameter content-type text/html] $content
    }
  }
}


namespace eval ::xowiki {

  Page instproc edit {
    {-new:boolean false} 
    {-autoname:boolean false}
    {-validaton_errors ""}
  } {
    my instvar package_id item_id revision_id
    $package_id instvar folder_id  ;# this is the root folder

    # set some default values if they are provided
    foreach key {name title page_order last_page_id} {
      if {[$package_id exists_query_parameter $key]} {
        my set $key [$package_id query_parameter $key]
      }
    }
    if {$new} {
      my set creator [::xo::get_user_name [::xo::cc user_id]]
      my set nls_language [ad_conn locale]
    }

    set object_type [my info class]
    if {!$new && $object_type eq "::xowiki::Object" && [my set name] eq "::$folder_id"} {
      # if we edit the folder object, we have to do some extra magic here, 
      # since  the folder object has slightly different naming conventions.
      # ns_log notice "--editing folder object ::$folder_id, FLUSH $page"
      ::xo::clusterwide ns_cache flush xotcl_object_cache [self]
      ::xo::clusterwide ns_cache flush xotcl_object_cache ::$folder_id
      my move ::$folder_id
      set page ::$folder_id
      #ns_log notice "--move page=$page"
    } 

    #
    # setting up folder id for file selector (use community folder if available)
    #
    set fs_folder_id ""
    if {[info commands ::dotlrn_fs::get_community_shared_folder] ne ""} {
      set fs_folder_id [::dotlrn_fs::get_community_shared_folder \
                            -community_id [::dotlrn_community::get_community_id]]
    }

    # the following line is like [$package_id url], but works as well with renamed objects
    # set myurl [$package_id pretty_link [my form_parameter name]]

    if {[my exists_query_parameter "return_url"]} {
      set submit_link [my query_parameter "return_url" "."]
      set return_url $submit_link
    } else {
      set submit_link "."
    }
    #my log "--u submit_link=$submit_link qp=[my query_parameter return_url]"

    # we have to do template mangling here; ad_form_template writes form 
    # variables into the actual parselevel, so we have to be in our
    # own level in order to access an pass these
    variable ::template::parse_level
    lappend parse_level [info level]    
    set action_vars [expr {$new ? "{edit-new 1} object_type return_url" : "{m edit} return_url"}]
    #my log "--formclass=[$object_type getFormClass -data [self]] ot=$object_type"
    [$object_type getFormClass -data [self]] create ::xowiki::f1 -volatile \
        -action  [export_vars -base [$package_id url] $action_vars] \
        -data [self] \
        -folderspec [expr {$fs_folder_id ne "" ?"folder_id $fs_folder_id":""}] \
        -submit_link $submit_link \
        -autoname $autoname

    if {[info exists return_url]} {
      ::xowiki::f1 generate -export [list [list return_url $return_url]]
    } else {
      ::xowiki::f1 generate
    }

    ::xowiki::f1 instvar edit_form_page_title context formTemplate
    
    if {[info exists item_id]} {
      set rev_link    [$package_id make_link [self] revisions]
      set view_link   [$package_id make_link [self] view]
    }
    if {[info exists last_page_id]} {
      set back_link [$package_id url]
    }

    set index_link  [$package_id make_link -privilege public -link "" $package_id {} {}]
    set html [$package_id return_page -adp /packages/xowiki/www/edit \
                  -form f1 \
                  -variables {item_id edit_form_page_title context formTemplate
                    view_link back_link rev_link index_link}]
    template::util::lpop parse_level
    #my log "--e html length [string length $html]"
    return $html
  }

  Page instproc find_slot {-start_class name} {
    if {![info exists start_class]} {
      set start_class [my info class]
    }
    foreach cl [concat $start_class [$start_class info heritage]] {
      set slotobj ${cl}::slot::$name
      if {[my isobject $slotobj]} {
        #my msg $slotobj
        return $slotobj
      }
    }
    return ""
  }
  
  Page instproc create_form_field {
    -name 
    {-slot ""} 
    {-spec ""} 
    {-configuration ""}
  } {
    if {$slot eq ""} {
      # We have no slot, so create a minimal slot. This should only happen for instance attributes
      set slot [::xo::Attribute new -pretty_name $name -datatype text -volatile -noinit]
    }

    set spec_list [list]
    if {[$slot exists spec]} {lappend spec_list [$slot set spec]}
    if {$spec ne ""}         {lappend spec_list $spec}
    #my msg "[self args] spec_list $spec_list"
    #my msg "$name, spec_list = '[join $spec_list ,]'"

    if {[$slot exists pretty_name]} {
      set label [$slot set pretty_name]
    } else {
      set label $name
      my log "no pretty_name for variable $name in slot $slot"
    }

    if {[$slot exists default]} {
      #my msg "setting ff $name default = [$slot default]"
      set default [$slot default] 
    } else {
      set default ""
    }
    set f [FormField new -name $name \
               -id        [::xowiki::Portlet html_id F.[my name].$name] \
               -locale    [my nls_language] \
               -label     $label \
               -type      [expr {[$slot exists datatype]  ? [$slot set datatype]  : "text"}] \
               -help_text [expr {[$slot exists help_text] ? [$slot set help_text] : ""}] \
               -validator [expr {[$slot exists validator] ? [$slot set validator] : ""}] \
               -required  [expr {[$slot exists required]  ? [$slot set required]  : "false"}] \
               -default   $default \
               -spec      [join $spec_list ,] \
               -object    [self] \
              ]

    $f destroy_on_cleanup
    eval $f configure $configuration
    return $f
  }

  PageInstance instproc create_form_field {
    -name 
    {-slot ""}
    {-spec ""} 
    {-configuration ""}
  } {
    set short_spec [my get_short_spec $name]
    #my msg "create form field '$name', short_spec = '$short_spec', slot=$slot"
    set spec_list [list]
    if {$spec ne ""}       {lappend spec_list $spec}
    if {$short_spec ne ""} {lappend spec_list $short_spec}
    #my msg "$name: short_spec '$short_spec', spec_list 1 = '[join $spec_list ,]'"
    set f [next -name $name -slot $slot -spec [join $spec_list ,] -configuration $configuration]
    return $f
  }

}

namespace eval ::xowiki {

  FormPage instproc create_category_fields {} {
    set category_spec [my get_short_spec @categories]
    foreach f [split $category_spec ,] {
      if {$f eq "off"} {return [list]}
    }
    
    set category_fields [list]
    set container_object_id [my package_id]
    set category_trees [category_tree::get_mapped_trees $container_object_id]
    set category_ids [category::get_mapped_categories [my item_id]]
    #my msg "mapped category ids=$category_ids"

    foreach category_tree $category_trees {
      foreach {tree_id tree_name subtree_id assign_single_p require_category_p} $category_tree break

      set options [list] 
      #if {!$require_category_p} {lappend options [list "--" ""]}
      set value [list]
      foreach category [category_tree::get_tree -subtree_id $subtree_id $tree_id] {
        foreach {category_id category_name deprecated_p level} $category break
        if {[lsearch $category_ids $category_id] > -1} {lappend value $category_id}
        set category_name [ad_quotehtml [lang::util::localize $category_name]]
        if { $level>1 } {
          set category_name "[string repeat {&nbsp;} [expr {2*$level -4}]]..$category_name"
        }
        lappend options [list $category_name $category_id]
      }
      set f [FormField new \
                 -name "__category_${tree_name}_$tree_id" \
                 -locale [my nls_language] \
                 -label $tree_name \
                 -type select \
                 -value $value \
                 -required $require_category_p]
      #my msg "category field [my name] created, value '$value'"
      $f destroy_on_cleanup
      $f options $options
      $f multiple [expr {!$assign_single_p}]
      lappend category_fields $f
    }
    return $category_fields
  }

  FormPage instproc set_form_value {att value} {
    my instvar root item_id
    set fields [$root selectNodes "//*\[@name='$att'\]"]
    #my msg "found field = $fields xp=//*\[@name='$att'\]"
    foreach field $fields {
      # TODO missing: textarea
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
        hidden -
        text {  $field setAttribute value $value}
        default {my msg "can't handle $type so far $att=$value"}
      }
    }
  }
}


namespace eval ::xowiki {

  FormPage ad_instproc set_form_data {} {
    Store the instance attributes in the form.
  } {
    #my msg "set_form_value instance attributes = [my instance_attributes]"
    foreach {att value} [my instance_attributes] {
      #my msg "set_form_value $att '$value'"
      my set_form_value $att $value
    }
  }
}


namespace eval ::xowiki {

  FormPage ad_instproc get_form_data {form_fields} {
    Get the values from the form and store it as
    instance attributes.
  } {
    set validation_errors 0
    set category_ids [list]
    array set containers [list]
    array set __ia [my set instance_attributes]

    # we have a form and get all form variables
      
    foreach att [::xo::cc array names form_parameter] {
      #my msg "getting att=$att"
      switch -glob -- $att {
        __category_* {
          set f [my lookup_form_field -name $att $form_fields]
          set value [$f value [::xo::cc form_parameter $att]]
          foreach v $value {lappend category_ids $v}
        }
        __* {
          # other internal variables (like __object_name) are ignored
        }
        _* {
          # instance attribute fields
          set f     [my lookup_form_field -name $att $form_fields]
          set value [$f value [::xo::cc form_parameter $att]]
          set varname [string range $att 1 end]
          if {![string match *.* $att]} {my set $varname $value}
        }
        default {
          # user form content fields
          set f     [my lookup_form_field -name $att $form_fields]
          set value [$f value [::xo::cc form_parameter $att]]
          # my msg "value of $att is $value"
          if {![string match *.* $att]} {set __ia($att)  $value}
        }
      }
      if {[string match *.* $att]} {
        foreach {container component} [split $att .] break
        lappend containers($container) $component
      }
    }

    #
    # In a second iteration, combine the values from the components 
    # of a container to the value of the container.
    #
    foreach c [array names containers] {
      switch -glob -- $c {
        __* {}
        _* {
          set f  [my lookup_form_field -name $c $form_fields]
          my set [string range $c 1 end] [$f get_compound_value]
        }
        default {
          set f  [my lookup_form_field -name $c $form_fields]
          set __ia($c) [$f get_compound_value]
        }
      }
    }
    
    #
    # Run validators
    #
    foreach f $form_fields {
      set validation_error [$f validate [self]]
      #my msg "validation of [$f name] with value '[$f value]' returns $validation_error"
      if {$validation_error ne ""} {
        $f error_msg $validation_error
        incr validation_errors
      }
    }
    #my log "--set instance attributes to [array get __ia]"
    my set instance_attributes [array get __ia]
    return [list $validation_errors $category_ids]
  }

  FormPage instproc form_field_as_html {{-mode edit} before name form_fields} {
    set found 0
    foreach f $form_fields {
      if {[$f name] eq $name} {set found 1; break}
    } 
    if {!$found} {
      set f [my create_form_field -name $name -slot [my find_slot $name]]
    }
    #my msg "$name mode=$mode type=[$f set type]"
    if {$mode eq "edit" || [$f display_field]} {
      set html [$f asHTML]
    } else {
      set html @$name@
    }
    #my msg "$name $html"
    return ${before}$html
  }
}

namespace eval ::xowiki {

  FormPage instproc create_form_fields {field_names} {

    set form_fields   [my create_category_fields]
    set cr_field_spec [my get_short_spec @cr_fields]
    set field_spec    [my get_short_spec @fields]

    foreach att $field_names {
      switch -glob -- $att {
        __* {}
        _* {
          set varname [string range $att 1 end]
          lappend form_fields [my create_form_field -name $att \
                                   -spec $cr_field_spec \
                                   -slot [my find_slot $varname]]
        }
        default {
          lappend form_fields [my create_form_field -name $att \
                                   -spec $field_spec \
                                   -slot [my find_slot $att]]
        }
      }
    }
    return $form_fields
  }

  FormPage instproc edit {
    {-validation_errors ""}
  } {
    my instvar page_template doc root package_id
    
    ::xowiki::Form requireFormCSS
    
    set form [lindex [my get_from_template form] 0]
    set anon_instances [my get_from_template anon_instances]

    if {$form eq ""} {
      #
      # Since we have no form, we create it on the fly
      # from the template variables and the form field specifications.
      #
      set form "<FORM></FORM>"
      set formgiven 0
    } else {
      set formgiven 1
    }

    foreach {form_vars needed_attributes} [my form_attributes] break
    #my msg "form_vars=$form_vars needed_attributes=$needed_attributes"
    if {$form_vars} {foreach v $needed_attributes {set field_in_form($v) 1}}
    
    # 
    # Remove the fields already included in auto_fields form the needed_attributes.
    # The final list field_names determines the order of the fields in the form.
    #
    set auto_fields [list _name _page_order _creator _title _text _description _nls_language]
    set reduced_attributes $needed_attributes

    foreach f $auto_fields {
      set p [lsearch $reduced_attributes $f]
      if {$p > -1} {
	#if {$form_vars} {
	  #set auto_field_in_form($f) 1
	#}
        set reduced_attributes [lreplace $reduced_attributes $p $p]
      } 
    }
    #my msg reduced_attributes=$reduced_attributes 
    #my msg fields_from_form=[array names field_in_form]

    set field_names [list _name]
    if {[$package_id show_page_order]}  { lappend field_names _page_order }
    lappend field_names _title _creator
    foreach fn $reduced_attributes                     { lappend field_names $fn }
    foreach fn [list _text _description _nls_language] { lappend field_names $fn }
    #my msg field_names=$field_names

    set form_fields [my create_form_fields $field_names]

    # check name field: 
    #  - if it is not required, hide it,
    #  - if it is required but hidden, show it anyway 
    #    (might happen, when e.g. set via @cr_fields ... hidden)
    set name_field [my lookup_form_field -name _name $form_fields]
    if {$anon_instances} {
      $name_field config_from_spec hidden
    } else {
      if {[$name_field istype ::xowiki::FormField::hidden]} {
        $name_field config_from_spec text,required
        $name_field type text
      }
    }

    # include _text only, if explicitely needed (in form or template)
    if {[lsearch $needed_attributes _text] == -1} {
      #my msg "setting text hidden"
      set f [my lookup_form_field -name _text $form_fields]
      $f config_from_spec hidden
    }
    #my show_fields $form_fields

    if {[my form_parameter __form_action ""] eq "save-form-data"} {
      #my msg "we have to validate"
      #
      # we have to valiate and save the form data
      #
      foreach {validation_errors category_ids} [my get_form_data $form_fields] break
      if {$validation_errors != 0} {
        #my msg "$validation_errors errors in $form_fields"
        #foreach f $form_fields { my msg "$f: [$f name] '[$f set value]' err: [$f error_msg] " }
        # reset the name in error cases to the original one
        my set name [my form_parameter __object_name]
      } else {
        #
        # we have no validation erros, so we can save the content
        #
        my save_data [::xo::cc form_parameter __object_name ""] $category_ids
        #my log "--forminstance redirect to [$package_id pretty_link [my name]]"
        $package_id returnredirect \
            [my query_parameter "return_url" [$package_id pretty_link [my name]]]
        return
      }
    } else {
      # 
      # display the current values
      #

      if {[my is_new_entry [my name]]} {
	my set creator [::xo::get_user_name [::xo::cc user_id]]
	my set nls_language [ad_conn locale]
	#my set name [$package_id query_parameter name ""]
	# TODO: maybe use __object_name to for POST url to make code 
	# more straightworward
        set n [$package_id query_parameter name \
		   [::xo::cc form_parameter __object_name ""]]
        if {$n ne ""} { my set name $n }
      }

      array set __ia [my set instance_attributes]
      foreach att $field_names {
        switch -glob $att {
          __* {}
          _* {
            set f [my lookup_form_field -name $att $form_fields]
            set varname [string range $att 1 end]
            $f value [my set $varname]
          }
          default {
            set f [my lookup_form_field -name $att $form_fields]
            if {[info exists __ia($att)]} {
              $f value $__ia($att)
            }
          }
        }
	set ff($att) $f
      }

      # for named entries, just set the entry fields to empty,
      # without changing the instance variables
      if {[my is_new_entry [my name]]} {
	if {![$ff(_title) istype ::xowiki::FormField::hidden]} {
	  $ff(_title) value ""
	}
	if {!$anon_instances} {$ff(_name) value ""}
        foreach var {title detail_link text} {
          if {[my exists_query_parameter $var]} {
            set value [my query_parameter $var]
            switch -- $var {
              detail_link {
                set f [my lookup_form_field -name $var $form_fields]
                $f value $value
              }
              title - text {
                set f [my lookup_form_field -name _$var $form_fields]
              }
            }
            $f value $value
          }
        }
      }
    }
    
    # The following command would be correct, but does not work due to a bug in 
    # tdom.
    # set form [my regsub_eval  \
    #              [template::adp_variable_regexp] $form \
    #              {my form_field_as_html "\\\1" "\2" $form_fields}]
    # Due to this bug, we program around and replace the at-character 
    # by \x003 to avoid conflict withe the input and we replace these
    # magic chars finally with the fields resulting from tdom.

    set form [string map [list @ \x003] $form]
    #my msg form=$form

    dom parse -simple -html $form doc
    $doc documentElement root

    ::require_html_procs
    $root firstChild fcn
    #
    # prepend some fields above the HTML contents of the form
    #
    $root insertBeforeFromScript {
      ::html::input -type hidden -name __object_name -value [my name]
      ::html::input -type hidden -name __form_action -value save-form-data

      # insert automatic form fields on top 
      foreach att $field_names {
        #if {$formgiven && ![string match _* $att]} continue
        if {[info exists field_in_form($att)]} continue
        set f [my lookup_form_field -name $att $form_fields]
	#my msg "insert auto_field $att"
        $f render_item
      }
    } $fcn
    #
    # append some fields after the HTML contents of the form 
    #
    set submit_button_class ""
    $root appendFromScript {    
      # append category fields
      foreach f $form_fields {
        if {[string match "__category_*" [$f name]]} {
          $f render_item
        } elseif {[$f info class] eq "::xowiki::FormField::richtext::wym"} {
          set submit_button_class "wymupdate"
        }
      }

      # insert unreported errors and add a submit field at bottom
      foreach f $form_fields {
        if {[$f set error_msg] ne "" && ![$f exists error_reported]} {
          $f render_error_msg
        }
      }
      set f [::xowiki::FormField::submit_button new -destroy_on_cleanup \
                 -name __form_button_ok \
                 -CSSclass $submit_button_class]
      $f render_content
    }
    set form [lindex [$root selectNodes //form] 0]
    if {$form eq ""} {
      my msg "no form found in page [$page_template name]"
    } else {
      if {[my exists_query_parameter "return_url"]} {
	set return_url [my query_parameter "return_url"]
      }
      set url [export_vars -base [$package_id pretty_link [my name]] {{m "edit"} return_url}] 
      $form setAttribute action $url method POST
      set oldCSSClass [expr {[$form hasAttribute class] ? [$form getAttribute class] : ""}]
      $form setAttribute class [string trim "$oldCSSClass margin-form"]
    }
    my set_form_data
    set html [$root asHTML]
    
    set html [my regsub_eval  \
                  {(^|[^\\])\x003([a-zA-Z0-9_:]+)\x003} $html \
                  {my form_field_as_html "\\\1" "\2" $form_fields}]

    #my msg result=$html
    my view $html
  }



  File instproc download {} {
    my instvar text mime_type package_id item_id revision_id
    $package_id set mime_type $mime_type
    set use_bg_delivery [expr {![catch {ns_conn contentsentlength}] && 
                               [info command ::bgdelivery] ne ""}]
    $package_id set delivery \
        [expr {$use_bg_delivery ? "ad_returnfile_background" : "ns_returnfile"}]
    #my log "--F FILE=[my full_file_name]"
    return [my full_file_name]
  }

  Page instproc revisions {} {
    my instvar package_id name item_id
    set context [list [list [$package_id url] $name ] [_ xotcl-core.revisions]]
    set title "[_ xotcl-core.revision_title] '$name'"
    set content [next]
    $package_id return_page -adp /packages/xowiki/www/revisions -variables {
      content context {page_id $item_id} title
    }
  }

  Page instproc make-live-revision {} {
    my instvar revision_id item_id package_id
    #my log "--M set_live_revision($revision_id)"
    ::xo::db::sql::content_item set_live_revision -revision_id $revision_id
    set page_id [my query_parameter "page_id"]
    ::xo::clusterwide ns_cache flush xotcl_object_cache ::$item_id
    ::$package_id returnredirect [my query_parameter "return_url" \
              [export_vars -base [$package_id url] {{m revisions}}]]
  }
  

  Page instproc delete-revision {} {
    my instvar revision_id package_id item_id 
    db_1row [my qn get_revision] "select latest_revision,live_revision from cr_items where item_id = $item_id"
    ::xo::clusterwide ns_cache flush xotcl_object_cache ::$item_id
    ::xo::clusterwide ns_cache flush xotcl_object_cache ::$revision_id
    ::xo::db::sql::content_revision del -revision_id $revision_id
    set redirect [my query_parameter "return_url" \
                      [export_vars -base [$package_id url] {{m revisions}}]]
    if {$live_revision == $revision_id} {
      # latest revision might have changed by delete_revision, so we have to fetch here
      db_1row [my qn get_revision] "select latest_revision from cr_items where item_id = $item_id"
      if {$latest_revision eq ""} {
        # we are out of luck, this was the final revision, delete the item
        my instvar package_id name
        $package_id delete -name $name -item_id $item_id
      } else {
        ::xo::db::sql::content_item set_live_revision -revision_id $latest_revision
      }
    }
    if {$latest_revision ne ""} {
      # otherwise, "delete" did already the redirect
      ::$package_id returnredirect [my query_parameter "return_url" \
                                      [export_vars -base [$package_id url] {{m revisions}}]]
    }
  }

  Page instproc delete {} {
    my instvar package_id item_id name

    # delete always via package
    $package_id delete -item_id $item_id -name $name

    #[my info class] delete -item_id $item_id
    #::$package_id flush_references -item_id $item_id -name $name
    #::$package_id returnredirect \
#	[my query_parameter "return_url" [$package_id package_url]]
  }

  Page instproc save-tags {} {
    my instvar package_id item_id revision_id
    ::xowiki::Page save_tags \
	-user_id [::xo::cc user_id] \
	-item_id $item_id \
	-revision_id $revision_id \
        -package_id $package_id \
	[my form_parameter new_tags]

    ::$package_id returnredirect \
        [my query_parameter "return_url" [$package_id url]]
  }

  Page instproc popular-tags {} {
    my instvar package_id item_id parent_id
    set limit       [my query_parameter "limit" 20]
    set weblog_page [$package_id get_parameter weblog_page weblog]
    set href        [$package_id pretty_link $weblog_page]?summary=1

    set entries [list]
    db_foreach [my qn get_popular_tags] \
        [::xo::db::sql select \
	     -vars "count(*) as nr, tag" \
	     -from "xowiki_tags" \
	     -where "item_id=$item_id" \
	     -groupby "tag" \
	     -orderby "nr" \
	     -limit $limit] {
           lappend entries "<a href='$href&ptag=[ad_urlencode $tag]'>$tag ($nr)</a>"
         }
    ns_return 200 text/html "[_ xowiki.popular_tags_label]: [join $entries {, }]"
  }

  Page instproc diff {} {
    my instvar package_id
    set compare_id [my query_parameter "compare_revision_id" 0]
    if {$compare_id == 0} {
      return ""
    }
    set my_page [::xowiki::Package instantiate_page_from_id -revision_id [my set revision_id]]
    $my_page volatile

    set html1 [$my_page render]
    set text1 [ad_html_text_convert -from text/html -to text/plain -- $html1]
    set user1 [::xo::get_user_name [$my_page set creation_user]]
    set time1 [$my_page set creation_date]
    set revision_id1 [$my_page set revision_id]
    regexp {^([^.]+)[.]} $time1 _ time1

    set other_page [::xowiki::Package instantiate_page_from_id -revision_id $compare_id]
    $other_page volatile
    #$other_page absolute_links 1

    set html2 [$other_page render]
    set text2 [ad_html_text_convert -from text/html -to text/plain -- $html2]
    set user2 [::xo::get_user_name [$other_page set creation_user]]
    set time2 [$other_page set creation_date]
    set revision_id2 [$other_page set revision_id]
    regexp {^([^.]+)[.]} $time2 _ time2

    set title "Differences for [my set name]"
    set context [list $title]

    set content [::xowiki::html_diff $text2 $text1]
    $package_id return_page -adp /packages/xowiki/www/diff -variables {
      content title context
      time1 time2 user1 user2 revision_id1 revision_id2
    }
  }

  proc html_diff {doc1 doc2} {
    set out ""
    set i 0
    set j 0
    
    #set lines1 [split $doc1 "\n"]
    #set lines2 [split $doc2 "\n"]
    
    regsub -all \n $doc1 " <br/>" doc1
    regsub -all \n $doc2 " <br/>" doc2
    set lines1 [split $doc1 " "]
    set lines2 [split $doc2 " "]
    
    foreach { x1 x2 } [list::longestCommonSubsequence $lines1 $lines2] {
      foreach p $x1 q $x2 {
        while { $i < $p } {
          set l [lindex $lines1 $i]
          incr i
          #puts "R\t$i\t\t$l"
          append out "<span class='removed'>$l</span>\n"
        }
        while { $j < $q } {
          set m [lindex $lines2 $j]
          incr j
          #puts "A\t\t$j\t$m"
          append out "<span class='added'>$m</span>\n"
        }
        set l [lindex $lines1 $i]
        incr i; incr j
        #puts "B\t$i\t$j\t$l"
      append out "$l\n"
      }
    }
    while { $i < [llength $lines1] } {
      set l [lindex $lines1 $i]
      incr i
      puts "$i\t\t$l"
      append out "<span class='removed'>$l</span>\n"
    }
    while { $j < [llength $lines2] } {
      set m [lindex $lines2 $j]
      incr j
      #puts "\t$j\t$m"
      append out "<span class='added'>$m</span>\n"
    }
    return $out
  }


#   Page instproc new_name {name} {
#     if {$name ne ""} {
#       my instvar package_id
#       set name [my complete_name $name]
#       set name [::$package_id normalize_name $name]
#       set suffix ""; set i 0
#       set folder_id [my parent_id]
#       while {[::xo::db::CrClass lookup -name $name$suffix -parent_id $folder_id] != 0} {
#         set suffix -[incr i]
#       }
#       set name $name$suffix
#     }
#     return $name
#   }

#   Page instproc create-new {} {
#     my instvar package_id
#     set name [my new_name [::xo::cc form_parameter name ""]]
#     set class [::xo::cc form_parameter class ::xowiki::Page]
#     if {[::xotcl::Object isclass $class] && [$class info heritage ::xowiki::Page] ne ""} { 
#       set class [::xo::cc form_parameter class ::xowiki::Page]
#       set f [$class new -destroy_on_cleanup \
#                  -name $name \
#                  -package_id $package_id \
#                  -parent_id [my parent_id] \
#                  -publish_status "production" \
#                  -title [my title] \
#                  -text [list [::xo::cc form_parameter content ""] text/html]]
#       $f save_new
#       $package_id returnredirect \
#           [my query_parameter "return_url" [$package_id pretty_link $name]?m=edit]
#     }
#   }

  PageTemplate instproc delete {} {
    my instvar package_id item_id name
    set count [my count_usages -all true]
    #my msg count=$count
    if {$count > 0} {
      append error_msg \
          [_ xowiki.error-delete_entries_first [list count $count]] \
          <p> \
          [my include_portlet [list form-usages -all true -form_item_id [my item_id]]] \
          </p>
      $package_id error_msg $error_msg
    } else {
      next
    }
  }

  Form instproc create-new {} {
    my instvar package_id
    set f [FormPage new -destroy_on_cleanup \
               -package_id $package_id \
               -parent_id [my parent_id] \
               -publish_status "production" \
               -page_template [my item_id]]

    set source_item_id [$package_id query_parameter source_item_id ""]
    if {$source_item_id ne ""} {
      set source [FormPage get_instance_from_db -item_id $source_item_id]
      $source destroy_on_cleanup
      $f copy_content_vars -from_object $source
      #$f set __autoname_prefix "[my name] - "
      $f set name ""
      regexp {^.*:(.*)$} [$source set name] _ name
    } else {
      # set some default values if they are provided
      foreach key {name title page_order last_page_id} {
	if {[$package_id exists_query_parameter $key]} {
	  $f set $key [$package_id query_parameter $key]
	}
      }
    }
    $f set __title_prefix [my title]

    $f save_new
    if {[my exists_query_parameter "return_url"]} {
      set return_url [my query_parameter "return_url"]
    }
    if {[my exists_query_parameter "template_file"]} {
      set template_file [my query_parameter "template_file"]
    }
    foreach var {return_url template_file title detail_link text} {
      if {[my exists_query_parameter $var]} {
        set $var [my query_parameter $var]
      }
    }
    $package_id returnredirect \
        [export_vars -base [$package_id pretty_link [$f name]] \
	     {{m edit} return_url name template_file title detail_link text}]
  }


  if {[apm_version_names_compare [ad_acs_version] 5.3.0] == 1} {
    ns_log notice "Zen-state: 5.3.2 or newer"
    Form set extraCSS ""
  } else {
    ns_log notice "Zen-state: pre 5.3.1, use backward compatible form css file"
    Form set extraCSS "zen-forms-backward-compatibility.css"
  }
  Form proc requireFormCSS {} {
    #my msg requireFormCSS
    set css [my set extraCSS]
    if {$css ne ""} {
      ::xo::Page requireCSS $css
    }
  }

}