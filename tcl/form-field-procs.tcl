ad_library {
    XoWiki - form fields

    @creation-date 2007-06-22
    @author Gustaf Neumann
    @cvs-id $Id$
}

namespace eval ::xowiki {

  # Second approximation for form fields.
  # FormFields are objects, which can be outputed as well in ad_forms
  # or asHTML included in wiki pages. FormFields support 
  #
  #  - validation
  #  - help_text
  #  - error messages
  #  - internationlized pretty_values
  #
  # and inherit properties of the original datatypes via slots
  # (e.g. for boolean entries). FormFields can be subclassed
  # to ensure tailorability and high reuse.
  # 
  # todo: at some later time, this should go into xotcl-core

  ###########################################################
  #
  # ::xowiki::FormField (Base Class)
  #
  ###########################################################
  Class FormField -superclass ::xo::tdom::Object -parameter {
    {required false} 
    {display_field true} 
    {hide_value false} 
    {inline false}
    CSSclass
    {type text} 
    {label} 
    {name} 
    {id} 
    {value ""} 
    {spec ""} 
    {help_text ""}
    {error_msg ""}
    {validator ""}
    locale
    default
    object
  }
  FormField instproc init {} {
    if {![my exists label]} {my label [string totitle [my name]]}
    if {![my exists id]} {my id [my name]}
    if {[my exists id]}  {my set html(id) [my id]}
    #if {[my exists default]} {my set value [my default]}
    my config_from_spec [my spec]
  }

  FormField instproc validate {obj} {
    my instvar name required value

    if {$required && $value eq ""} {
      my instvar label
      return [_ acs-templating.Element_is_required]
    }
    # 
    #my msg "[my name] [my info class] validator=[my validator]"
    if {[my validator] ne ""} {
      set errorMsg ""
      #
      # The validator might set the variable errorMsg in this scope.
      #
      set success 1
      set validator_method check=[my validator]
      set proc_info [my procsearch $validator_method]
      if {$proc_info ne ""} {
        # we have a slot checker, call it
	#my msg "call field specific validator $validator_method '$value'" 
	set success [my $validator_method $value]
      } 
      if {$success == 1} {
        # the previous check was ok, check now for a validator on the
        # object level
	set validator_method validate=[my validator]
	set proc_info [$obj procsearch $validator_method]
        if {$proc_info ne ""} {
          #my msg "call object level validator $validator_method '$value'" 
          set success [$obj $validator_method $value]
        }
      }
      if {$success == 0} {
        #
        # We have an error message. Get the class name from procsearch and construct
        # a message key based on the class and the name of the validator.
        #
        set cl [namespace tail [lindex $proc_info 0]]
        return [_ xowiki.$cl-validate_[my validator] [list value $value errorMsg $errorMsg]]
      }
    }
    return ""
  }

  FormField instproc reset_parameter {} {
    # reset application specific parameters (defined below ::xowiki::FormField)
    # such that searchDefaults will pick up the new defaults, when a form field
    # is reclassed.
    for {set c [my info class]} {$c ne "::xowiki::FormField"} {set c [$c info superclass]} {
      #my msg "[my name] parameters ($c) = [$c info parameter]"
      foreach p [$c info parameter] {
	set l [split $p]
	if {[llength $l] != 2} continue
	set var [lindex $l 0]
	if {[my exists $var]} {
	  #my msg "[my name] unset  '$var'"
	  my unset $var
	}
      }
    }
  }

  FormField instproc interprete_condition {cond} {
    set package_id [[my object] package_id]
    #set policy [$package_id set policy]
    #set success [$policy check_privilege \
    #                 -user_id [::xo::cc user_id] \
    #                 -package_id $package_id $cond [self] view]
    if {[::xo::cc info methods role=$cond] ne ""} {
      set success [::xo::cc role=$cond \
                       -user_id [::xo::cc user_id] \
                       -package_id $package_id]
    } else {
      set success 0
    }
    return $success
  }
  
  FormField instproc interprete_single_spec {s} {
    if {$s eq ""} return
    
    if {[regexp {^([^=?]+)[?]([^:]*)[:](.*)$} $s _ condition true_spec false_spec]} {
      #my msg "--c=$condition,true_spec=$true_spec,false_spec=$false_spec"
      if {[my interprete_condition $condition]} {
        my interprete_single_spec $true_spec
      } else {
        my interprete_single_spec $false_spec
      }
      return
    }
    switch -glob $s {
      optional    {my set required false}
      required    {my set required true}
      label=*     {my label     [lindex [split $s =] 1]}
      help_text=* {my help_text [lindex [split $s =] 1]}
      *=*         {
        set l [split $s =]
        foreach {attribute value} $l break
        set definition_class [lindex [my procsearch $attribute] 0]
        if {[string match "::xotcl::*" $definition_class] || $definition_class eq ""} {
          error [_ xowiki.error-form_constraint-unknown_attribute [list name [my name] entry $attribute]]
        }
        if {[catch {
          #
          # We want to allow a programmer to use e.g. options=[xowiki::locales] 
          #
          # Note: do not allow users to use [] via forms, since they might
          # execute arbitrary commands. The validator for the form fields 
          # makes sure, that the input specs are free from square brackets.
          #
          if {[string match {\[*\]} $value]} {
            set value [subst $value]
          }
          #my msg "my [lindex $l 0] $value"
          my [lindex $l 0] $value
        } errMsg]} {
          error "Error during setting attribute '[lindex $l 0]' to value '[lindex $l 1]': $errMsg"
        }
      }
      default {
        if {[my isclass [self class]::$s]} {
          my class [self class]::$s
          my reset_parameter
          #my msg "[my name] searchDefaults"
          ::xotcl::Class::Parameter searchDefaults [self]; # TODO: will be different in xotcl 1.6.*
        } else {
          if {$s ne ""} {
            error [_ xowiki.error-form_constraint-unknown_spec_entry \
                       [list name [my name] entry $s x "Unknown spec entry for entry '$s'"]]
          }
        }
      }
    }
  }

  FormField instproc config_from_spec {spec} {
    my instvar type
    if {[my info class] eq [self class]} {
      # Check, wether the actual class of the formfield differs from the
      # generic FromField class. If yes, the object was already 
      # reclassed to a concrete form field type. Since config_from_spec
      # can be called multiple times, we want to do the reclassing only
      # once.
      my class [self class]::$type
      ::xotcl::Class::Parameter searchDefaults [self]; # TODO: will be different in xotcl 1.6.*
    }
    regsub -all {,\s+} $spec , spec
    foreach s [split $spec ,] {
      my interprete_single_spec $s
    }

    my initialize

    #
    # It is possible, that a default value of a form field is changed through a spec.
    # Since only the configuration might set values, checking value for "" seems safe here.
    #
    if {[my value] eq "" && [my exists default] && [my default] ne ""} {
      #my msg "+++ reset value to [my default]"
      my value [my default]
    }

    if {[lang::util::translator_mode_p]} {
      my mixin "::xo::TRN-Mode"
    }

  }

  FormField instproc asWidgetSpec {} {
    my instvar widget_type options label help_text format html display_html
    set spec $widget_type
    if {[my exists spell]} {append spec ",[expr {[my spell] ? {} : {no}}]spell"}

    if {![my required]} {append spec ",optional"}
    append spec " {label " [list $label] "} "

    if {[my exists html]} {
      append spec " {html {" 
      foreach {key value} [array get html] {
        append spec $key " " [list $value] " "
      }
      append spec "}} " 
    }

    if {[my exists options]} {
      append spec " {options " [list $options] "} "
    }
    if {[my exists format]} {
      append spec " {format " [list $format] "} "
    }
    if {$help_text ne ""} {
      if {[string match "#*#" $help_text]} {
        set internationalized [_ [string trim $help_text #]]
        append spec " {help_text {$internationalized}}"
      } else {
        append spec " {help_text {$help_text}}"
      }
    }
    return $spec
  }

  FormField instproc render {} {
    # In case, we use an asHTML of a FormField, we use this
    # render definition 
    if {[my inline]} {
      # with label, error message, help text
      my render_form_widget
    } else {
      # without label, error message, help text
      my render_item
    }
  }
  
  FormField instproc render_form_widget {} {
    # This method provides the form-widget wrapper
    ::html::div -class form-widget { my render_content }
  }

  FormField instproc render_content {} {
    # This is the most general widget content renderer. 
    # If no special renderer is defined, we fall back to this one, 
    # which is in most cases  a simple input fied of type string.
    ::html::input [my get_attributes type size maxlength id name value] {}
  } 
  
  FormField instproc render_error_msg {} {
    if {[my error_msg] ne ""} {
      ::html::div -class form-error {
        my instvar label
        ::html::t [::xo::localize [my error_msg]]
        my render_localizer
        my set error_reported 1
      }
    }
  }

  FormField instproc render_help_text {} {
    set text [my help_text]
    if {$text ne ""} {
      html::div -class form-help-text {
        html::img -src "/shared/images/info.gif" -alt {[i]} -title {Help text} \
            -width "12" -height 9 -border 0 -style "margin-right: 5px" {}
        html::t $text
      }
    }
  }

  FormField instproc render_localizer {} {
    # Just an empty fall-back method.
    # This method will be overloaded in trn mode by a mixin.
  }

  FormField instproc render_item {} {
    ::html::div -class form-item-wrapper {
      ::html::div -class form-label {
        ::html::label -for [my id] {
          ::html::t [my label]
        }
        if {[my required]} {
          ::html::div -class form-required-mark {
            ::html::t " (#acs-templating.required#)"
          }
        }
      }
      my render_form_widget
      my render_help_text
      my render_error_msg
      html::t \n
    }
  }

  FormField instproc localize {v} {
    # We localize in pretty_value the message keys in the 
    # language of the item (not the connection item).
    if {[regexp "^#(.*)#$" $v _ key]} {
      return [lang::message::lookup [my locale] $key]
    }
    return $v
  }

  FormField instproc pretty_value {v} {
    if {[my exists options]} {
      foreach o [my set options] {
        foreach {label value} $o break
        if {$value eq $v} {return [my localize $label]}
      }
    }
    return [string map [list & "&amp;" < "&lt;" > "&gt;" \" "&quot;" ' "&apos;" @ "&#64;"] $v]
  }

  ###########################################################
  #
  # ::xowiki::FormField::submit_button
  #
  ###########################################################

  Class FormField::submit_button -superclass FormField 
  FormField::submit_button  instproc initialize {} {
    my set type submit
  }
  FormField::submit_button instproc render_content {} {
    my set value [::xo::localize [_ xowiki.Form-submit_button]]
    ::html::div -class form-button {
      #::html::br 
      ::html::input [my get_attributes type {CSSclass class} value] {}
      my render_localizer
    }
  }

  ###########################################################
  #
  # ::xowiki::FormField::hidden
  #
  ###########################################################

  Class FormField::hidden -superclass FormField
  FormField::hidden instproc initialize {} {
    my type hidden
    my set widget_type text(hidden)
  }
  FormField::hidden instproc render_item {} {
    # don't render the labels
    my render_form_widget
  }
  FormField::hidden instproc render_help_text {} {
  }

  ###########################################################
  #
  # ::xowiki::FormField::inform
  #
  ###########################################################
  
  Class FormField::inform -superclass FormField
  FormField::inform instproc initialize {} {
    my type hidden
    my set widget_type text(inform)
  }
  FormField::inform instproc render_content {} {
    ::html::t [my value]
    ::html::input [my get_attributes type id name value] {}
  }
  FormField::inform instproc render_help_text {} {
  }

  ###########################################################
  #
  # ::xowiki::FormField::text
  #
  ###########################################################

  Class FormField::text -superclass FormField -parameter {
    {size 80}
    maxlength
  }
  FormField::text instproc initialize {} {
    my set widget_type text
    foreach p [list size maxlength] {if {[my exists $p]} {my set html($p) [my $p]}}
  }

  ###########################################################
  #
  # ::xowiki::FormField::numeric
  #
  ###########################################################

  Class FormField::numeric -superclass FormField::text -parameter {
    {validator numeric}
  }
  FormField::numeric instproc initialize {} {
    my validator numeric
    next
    my set widget_type numeric
  }
  FormField::numeric instproc check=numeric {value} {
    return [string is double $value]
  }

  ###########################################################
  #
  # ::xowiki::FormField::user_id
  #
  ###########################################################

  Class FormField::user_id -superclass FormField::numeric -parameter {
  }
  FormField::user_id instproc pretty_value {v} {
    return [::xo::get_user_name $v]
  }

  ###########################################################
  #
  # ::xowiki::FormField::url
  #
  ###########################################################

  Class FormField::url -superclass FormField::text -parameter {
    {link_label}
  }
  FormField::url instproc pretty_value {v} {
    if {$v ne ""} {
      if {[my exists link_label]} {
        set link_label [my localize [my link_label]]
      } else {
        set link_label $v
      }
      regsub -all & $v "&amp;" v
      return "<a href='$v'>$link_label</a>"
    }
  }

  ###########################################################
  #
  # ::xowiki::FormField::detail_link
  #
  ###########################################################

  Class FormField::detail_link -superclass FormField::url -parameter {
    {link_label "#xowiki.weblog-more#"}
  }
  FormField::detail_link instproc pretty_value {v} {
    if {$v eq ""} {
      return ""
    }
    if {$v ne ""} {
      set link_label [my localize [my link_label]]
      regsub -all & $v "&amp;" v
      return " <span class='more'>\[ <a href='$v'>$link_label</a> \]</span>"
    }
  }

  ###########################################################
  #
  # ::xowiki::FormField::textarea
  #
  ###########################################################

  Class FormField::textarea -superclass FormField -parameter {
    {rows 2}
    {cols 80}
    {spell false}
    style
  }
  FormField::textarea instproc initialize {} {
    my set widget_type text(textarea)
    foreach p [list rows cols style] {if {[my exists $p]} {my set html($p) [my $p]}}
    next
  }

  FormField::textarea instproc render_content {} {
    ::html::textarea [my get_attributes id name cols rows style {CSSclass class}] {
      ::html::t [my value]
    }
  }

  ###########################################################
  #
  # ::xowiki::FormField::richtext
  #
  ###########################################################

  Class FormField::richtext -superclass FormField::textarea -parameter {
    {editor xinha} 
    plugins 
    folder_id
    width
    height
    {validator safe_html}
  }
  FormField::richtext instproc initialize {} {
    # Reclass the editor based on the attribute 'editor' if necessary
    # and call initialize again in this case...
    my display_field false

    if {[my editor] ne "" && [my info class] ne "[self class]::[my editor]"} {
      set editor_class [self class]::[my editor]
      if {![my isclass $editor_class]} {
	set editors [list]
	foreach c [::xowiki::FormField::richtext info subclass] {
	  lappend editors [namespace tail $c]
	}
	error [_ xowiki.error-form_constraint-unknown_editor \
		   [list name [my name] editor [my editor] editors $editors]]
      }
      my class $editor_class
      my reset_parameter
      ::xotcl::Class::Parameter searchDefaults [self]; # TODO: will be different in xotcl 1.6.*
      my initialize
    } else {
      next
    }
  }
  FormField::richtext instproc check=safe_html {value} {
    # don't check if the user has admin permissions on the package
    if {[::xo::cc permission \
                -object_id [::xo::cc package_id] \
                -privilege admin \
                -party_id [::xo::cc user_id]]} {
      set msg ""
    } else {
      set msg [ad_html_security_check $value]
    }
    if {$msg ne ""} {
      my uplevel [list set errorMsg $msg]
      return 0
    }
    return 1
  }
  FormField::richtext instproc pretty_value {v} {
    # for richtext, perform minimal output escaping
    return [string map [list @ "&#64;"] $v]
  }

  ###########################################################
  #
  # ::xowiki::FormField::richtext::wym
  #
  ###########################################################
  Class FormField::richtext::wym -superclass FormField::richtext -parameter {
    {editor wym}
    {CSSclass wymeditor}
    width
    height
  }
  FormField::richtext::wym instproc initialize {} {
    next
    my set widget_type richtext
  }
  FormField::richtext::wym instproc render_content {} {
    ::xo::Page requireCSS "/resources/xowiki/wymeditor/skins/default/screen.css"
    ::xo::Page requireJS  "/resources/xowiki/jquery/jquery.js"
    ::xo::Page requireJS  "/resources/xowiki/wymeditor/jquery.wymeditor.pack.js"
    regsub -all {[.]} [my id] {\\\\.} JID
    set config ""
    if {[my exists height] || [my exists width]} {
      set height_cmd ""
      set width_cmd ""
      if {[my exists height]} {set height_cmd "wym_box.find(wym._options.iframeSelector).css('height','[my height]');"}
      if {[my exists width]}  {set width_cmd "wym_box.css('width', '[my width]');"}
      set postInit [subst -nocommand -nobackslash {
        postInit: function(wym) {
          wym_box = jQuery(".wym_box");
          $height_cmd
          $width_cmd
        }}]
      set config "{
        $postInit
      }"
    }
    ::xo::Page requireJS [subst -nocommand -nobackslash {
      jQuery(function() {
        jQuery("#$JID").wymeditor($config);
      });
    }]

    next
  }
  ###########################################################
  #
  # ::xowiki::FormField::richtext::xinha
  #
  ###########################################################

  Class FormField::richtext::xinha -superclass FormField::richtext -parameter {
    javascript
    {height 350px}
    {style "width: 100%"}
  }
  FormField::richtext::xinha instproc initialize {} {
    next
    my set widget_type richtext
    if {![my exists plugins]} {
      my plugins \
          [parameter::get -parameter "XowikiXinhaDefaultPlugins" \
               -default [::xo::parameter get_from_package_key \
                             -package_key "acs-templating" -parameter "XinhaDefaultPlugins"]]
    }
    my set options [my get_attributes editor plugins width height folder_id javascript]
  }
  FormField::richtext::xinha instproc render_content {} {
    # we use for the time being the initialization of xinha based on 
    # the site master
    set ::acs_blank_master(xinha) 1
    set quoted [list]
    foreach e [my plugins] {lappend quoted '$e'}
    set ::acs_blank_master(xinha.plugins) [join $quoted ", "]
    
    array set o [my set options]
    set xinha_options ""
    foreach e {width height folder_id fs_package_id file_types attach_parent_id} {
      if {[info exists o($e)]} {
        append xinha_options "xinha_config.$e = '$o($e)';\n"
      }
    }
    append xinha_options "xinha_config.package_id = '[::xo::cc package_id]';\n"
    if {[info exists o(javascript)]} {
      append xinha_options $o(javascript) \n
    }
    set ::acs_blank_master(xinha.options) $xinha_options
    lappend ::acs_blank_master__htmlareas [my id]
    next
  }


  ###########################################################
  #
  # ::xowiki::FormField::radio
  #
  ###########################################################

  Class FormField::radio -superclass FormField -parameter {
    {options ""}
    {horizontal false}
  }
  FormField::radio instproc initialize {} {
    my set widget_type text(radio)
  }
  FormField::radio instproc render_content {} {
    set value [my value]
    foreach o [my options] {
      foreach {label rep} $o break
      set atts [list id [my id]:$rep name [my name] type radio value $rep]
      if {$value eq $rep} {lappend atts checked checked}
      ::html::input $atts {}
      html::t "$label  "
      if {![my horizontal]} {html::br}
    }
  }

  ###########################################################
  #
  # ::xowiki::FormField::select
  #
  ###########################################################

  Class FormField::select -superclass FormField -parameter {
    {options ""}
    {multiple "false"}
  }
  FormField::select instproc initialize {} {
    my set widget_type text(select)
  }
  FormField::select instproc render_content {} {
    set atts [my get_attributes id name]
    if {[my multiple]} {lappend atts multiple [my multiple]}
    set options [my options]
    if {![my required]} {
      set options [linsert $options 0 [list "--" ""]]
    }
    ::html::select $atts {
      foreach o $options {
        foreach {label rep} $o break
        set atts [list value $rep]
        #my msg "lsearch {[my value]} $rep ==> [lsearch [my value] $rep]"
        if {[lsearch [my value] $rep] > -1} {
          lappend atts selected on
        }
        ::html::option $atts {::html::t $label}
        ::html::t \n
    }}
  }


  ###########################################################
  #
  # ::xowiki::FormField::DD
  #
  ###########################################################

  Class FormField::DD -superclass FormField -superclass FormField::select
  FormField::DD instproc initialize {} {
    my options {
      {01  1} {02  2} {03  3} {04  4} {05  5} {06  6} {07  7} {08  8} {09  9} {10 10}
      {11 11} {12 12} {13 13} {14 14} {15 15} {16 16} {17 17} {18 18} {19 19} {20 20}
      {21 21} {22 22} {23 23} {24 24} {25 25} {26 26} {27 27} {28 28} {29 29} {30 30}
      {31 31}
    }
    next
  }

  ###########################################################
  #
  # ::xowiki::FormField::HH24
  #
  ###########################################################

  Class FormField::HH24 -superclass FormField -superclass FormField::select
  FormField::HH24 instproc initialize {} {
    my options {
      {00  0} {01  1} {02  2} {03  3} {04  4} {05  5} {06  6} {07  7} {08  8} {09  9} 
      {10 10} {11 11} {12 12} {13 13} {14 14} {15 15} {16 16} {17 17} {18 18} {19 19} 
      {20 20} {21 21} {22 22} {23 23} 
    }
    next
  }

  ###########################################################
  #
  # ::xowiki::FormField::MI
  #
  ###########################################################

  Class FormField::MI -superclass FormField -superclass FormField::select
  FormField::MI instproc value args {
    if {[llength $args] == 0} {return [my set value]} else {
      set v [lindex $args 0]
      if {$v eq ""} {return [my set value ""]} else {
	# round to 5 minutes
	my set value [lindex [my options] [expr {($v + 2) / 5}] 1]
      }
    }
  }
  FormField::MI instproc initialize {} {
    my options {
      {00  0} {05  5} {10 10} {15 15} {20 20} {25 25} 
      {30 30} {35 35} {40 40} {45 45} {50 50} {55 55}
    }
    next
  }

  ###########################################################
  #
  # ::xowiki::FormField::MM
  #
  ###########################################################

  Class FormField::MM -superclass FormField -superclass FormField::select
  FormField::MM instproc initialize {} {
    my options {
      {01  1} {02  2} {03 3} {04 4} {05 5} {06 6} {07 7} {08 8} {09 9} {10 10}
      {11 11} {12 12} 
    }
    next
  }
  ###########################################################
  #
  # ::xowiki::FormField::mon
  #
  ###########################################################

  Class FormField::mon -superclass FormField::select
  FormField::mon instproc initialize {} {
    set values [lang::message::lookup [my locale] acs-lang.localization-abmon]
    if {[lang::util::translator_mode_p]} {set values [::xo::localize $values]}
    set last 0
    foreach m {1 2 3 4 6 7 8 9 10 11 12} {
      lappend options [list [lindex $values $last] $m]
      set last $m
    }
    my options $options
    next
  }
  ###########################################################
  #
  # ::xowiki::FormField::month
  #
  ###########################################################

  Class FormField::month -superclass FormField::select
  FormField::month instproc initialize {} {
    set values [lang::message::lookup [my locale] acs-lang.localization-mon]
    if {[lang::util::translator_mode_p]} {set values [::xo::localize $values]}
    set last 0
    foreach m {1 2 3 4 6 7 8 9 10 11 12} {
      lappend options [list [lindex $values $last] $m]
      set last $m
    }
    my options $options
    next
  }

  ###########################################################
  #
  # ::xowiki::FormField::YYYY
  #
  ###########################################################

  Class FormField::YYYY -superclass FormField::numeric -parameter {
    {size 4}
    {maxlength 4}
  }


  ###########################################################
  #
  # ::xowiki::FormField::image_url
  #
  ###########################################################

  Class FormField::image_url -superclass FormField::text -parameter {
    {validator image_check}
    href cssclass
    {float left} width height 
    padding {padding-right 10px} padding-left padding-top padding-bottom
    margin margin-left margin-right margin-top margin-bottom
    border border-width position top botton left right
  }
  FormField::image_url instproc entry_name {value} {
    if {![regexp -nocase {/([^/]+)[.](gif|jpg|jpeg|png)} $value _ name ext]} {
      return ""
    }
    return image:$name.$ext
  }
  FormField::image_url instproc check=image_check {value} {
    if {$value eq ""} {return 1}
    set entry_name [my entry_name $value]
    if {$entry_name eq ""} {
      my log "--img '$value' does not appear to be an image"
      # no image?
      return 0
    }
    set folder_id [[my object] set parent_id]
    if {[::xo::db::CrClass lookup -name $entry_name -parent_id $folder_id]} {
      my log "--img entry named $entry_name exists already"
      # file exists already
      return 1
    }
    if {[catch {
      set r [::xo::HttpRequest new -url $value -volatile]
      set img [$r set data]
    } errorMsg]} {
      # cannot transfer image
      my log "--img cannot tranfer image '$value' ($errorMsg)"
      return 0
    }
    set import_file [ns_tmpnam]
    ::xowiki::write_file $import_file $img
    set file_object [::xowiki::File new -destroy_on_cleanup \
                         -title $entry_name \
                         -name $entry_name \
                         -parent_id $folder_id \
                         -package_id [[my object] package_id] \
                         -creation_user [::xo::cc user_id] \
                        ]
    $file_object set import_file $import_file
    $file_object save_new
    return 1
  }
  FormField::image_url instproc pretty_value {v} {
    set entry_name [my entry_name $v]
    if {$entry_name eq ""} {
      return ""
    }
    my instvar object
    set l [::xowiki::Link new -destroy_on_cleanup \
               -name $entry_name -page $object -type image -label [my label] \
               -folder_id [$object parent_id] -package_id [$object package_id]]
    foreach option {
        href cssclass
        float width height 
        padding padding-right padding-left padding-top padding-bottom
        margin margin-left margin-right margin-top margin-bottom
        border border-width position top botton left right
    } {
      if {[my exists $option]} {$l set $option [my set $option]}
    }
    set html [$l render]
    return $html
  }

  ###########################################################
  #
  # ::xowiki::CompoundField
  #
  ###########################################################

  Class CompoundField -superclass FormField -parameter {
    {components ""}
  }

  CompoundField instproc value {args} {
    if {[llength $args] == 0} {
      set v [my get_compound_value]
      #my msg "[my name]: reading compound value => '$v'"
      return $v
    } else {
      #my msg "[my name]: setting compound value => '[lindex $args 0]'"
      my set_compound_value [lindex $args 0]
    }
  }

  CompoundField instproc set_compound_value {value} {
    array set {} $value
    # set the value parts for each components
    foreach c [my components] {
      # Set only those parts, for which attribute values pairs are
      # given.  Components might have their own default values, which
      # we do not want to overwrite ...
      if {[info exists ([$c name])]} {
        $c value $([$c name])
      } 
    }
  }
  
  CompoundField instproc get_compound_value {} {
    # Set the internal representation based on the components values.
    set value [list]
    foreach c [my components] {
      #my msg "lappending [$c name] [$c value] "
      lappend value [$c name] [$c value]
    }
    #my msg "[my name]: get_compound_value returns value=$value"
    return $value
  }

  CompoundField instproc get_component {component_name} {
    set key component_index([my name].$component_name)
    if {[my exists $key]} {
      return [my set $key]
    }
    error "no component named $component_name of compound field [my name]"
  }

  CompoundField instproc render_content {} {
    #
    # Render content within in a fieldset, but with labels etc.
    #
    my set style "margin: 0px; padding: 0px;"
    html::fieldset [my get_attributes id style] {
      foreach c [my components] { $c render }
    }
  }

  ###########################################################
  #
  # ::xowiki::FormField::label
  #
  ###########################################################

  Class FormField::label -superclass FormField -parameter {}
  FormField::label instproc initialize {} {next}
  FormField::label instproc render_content {} {
    html::t [my value]
  }

  ###########################################################
  #
  # ::xowiki::FormField::date
  #
  ###########################################################

  Class FormField::date -superclass CompoundField -parameter {
    {format "DD MONTH YYYY"}
    {display_format "%Y-%m-%d %T"}
  }
  # The default of a date might be all relative dates
  # supported by clock scan. These include "now", "tomorrow",
  # "yesterday", "next week", .... use _ for blanks

  FormField::date instproc initialize {} {
    #my msg "DATE has value [my value]"
    my set widget_type date
    my set format [string map [list _ " "] [my format]]
    my array set defaults {year 2000 month 01 day 01 hour 00 min 00 sec 00}
    my array set format_map {
      SS    {SS    %S 1}
      MI    {MI    %M 1}
      HH24  {HH24  %H 1}
      DD    {DD    %e 0}
      MM    {MM    %m 1}
      MON   {mon   %m 1}
      MONTH {month %m 1}
      YYYY  {YYYY  %Y 0}
    }

    foreach element [split [my format]] {
      if {![my exists format_map($element)]} {
        #
        # We add undefined formats as literal texts in the edit form
        #
        set name $element
        set c [::xowiki::FormField::label create [self]::$name \
                   -name [my name].$name -id [my id].$name -locale [my locale] -value $element]
        my lappend components $c
        continue
      }
      foreach {class code trim_zeros} [my set format_map($element)] break
      #
      # create for each component a form field
      #
      set name $class
      set c [::xowiki::FormField::$class create [self]::$name \
               -name [my name].$name -id [my id].$name -locale [my locale]]
      $c set code $code
      $c set trim_zeros $trim_zeros
      my lappend components $c
    }
    #my msg "DATE [my name] has value after initialize '[my value]'"
  }

  FormField::date instproc set_compound_value {value} {
    #my msg "[my name] original value '[my value]' // passed='$value'"
    set value [::xo::db::tcl_date $value tz]
    #my msg "transformed value '$value'"
    if {$value ne ""} {
      set ticks [clock scan [string map [list _ " "] $value]]
    } else {
      set ticks ""
    }
    my set defaults(year)  [clock format $ticks -format %Y]
    my set defaults(month) [clock format $ticks -format %m]
    my set defaults(day)   [clock format $ticks -format %e]
    my set defaults(hour)  [clock format $ticks -format %H]
    my set defaults(min)   [clock format $ticks -format %M]
    #my set defaults(sec)   [clock format $ticks -format %S]

    # set the value parts for each components
    foreach c [my components] {
      if {[$c istype ::xowiki::FormField::label]} continue
      if {$ticks ne ""} {
	set value_part [clock format $ticks -format [$c set code]]
	if {[$c set trim_zeros]} {
	  set value_part [string trimleft $value_part 0]
	  if {$value_part eq ""} {set value_part 0}
	}
      } else {
	set value_part ""
      }
      #my msg "ticks=$ticks $c value $value_part"
      $c value $value_part
    }
  }
  
  FormField::date instproc get_compound_value {} {
    # Set the internal representation of the date based on the components values.
    # Internally, the ansi date format is used.
    set year ""; set month ""; set day ""; set hour ""; set min ""; set sec ""
    if {[my isobject [self]::YYYY]}  {set year  [[self]::YYYY  value]}
    if {[my isobject [self]::month]} {set month [[self]::month value]}
    if {[my isobject [self]::mon]}   {set month [[self]::mon   value]}
    if {[my isobject [self]::MM]}    {set month [[self]::MM    value]}
    if {[my isobject [self]::DD]}    {set day   [[self]::DD    value]}
    if {[my isobject [self]::HH24]}  {set hour  [[self]::HH24  value]}
    if {[my isobject [self]::MI]}    {set min   [[self]::MI    value]}
    if {[my isobject [self]::SS]}    {set sec   [[self]::SS    value]}
    if {"$year$month$day$hour$min$sec" eq ""} {
      return ""
    }
    foreach v [list year month day hour min sec] {
      if {[set $v] eq ""} {set $v [my set defaults($v)]}
    }
    #my msg "$year-$month-$day ${hour}:${min}:${sec}"
    set ticks [clock scan "$year-$month-$day ${hour}:${min}:${sec}"]
    # TODO: TZ???
    #my msg "DATE [my name] get_compound_value returns [clock format $ticks -format {%Y-%m-%d %T}]"
    return [clock format $ticks -format "%Y-%m-%d %T"]
  }

  FormField::date instproc pretty_value {v} {
    #
    # Internally, we use the ansi date format. For displaying the date, 
    # use the specified display format and present the time localized.
    #
    # Drop of the value after the "." we assume to have a date in the local zone
    regexp {^([^.]+)[.]} $v _ v
    #return [clock format [clock scan $v] -format [string map [list _ " "] [my display_format]]]
    return [lc_time_fmt $v [string map [list _ " "] [my display_format]] [my locale]]
  }

  FormField::date instproc render_content {} {
    #
    # render the content inline withing a fieldset, without labels etc.
    #
    my set style "margin: 0px; padding: 0px;"
    html::fieldset [my get_attributes id style] {
      foreach c [my components] { $c render_content }
    }
  }

  ###########################################################
  #
  # ::xowiki::FormField::boolean
  #
  ###########################################################

  Class FormField::boolean -superclass FormField::radio -parameter {
    {default t}
  }
  FormField::boolean instproc initialize {} {
    # should be with cvs head message catalogs:
    # my options {{#acs-kernel.common_No# f} {#acs-kernel.common_Yes# t}}
    my options {{No f} {#acs-kernel.common_Yes# t}}
    next
  }

  ###########################################################
  #
  # ::xowiki::FormField::scale
  #
  ###########################################################

  Class FormField::scale -superclass FormField::radio -parameter {{n 5} {horizontal true}}
  FormField::scale instproc initialize {} {
    my instvar n
    set options [list]
    for {set i 1} {$i <= $n} {incr i} {
      lappend options [list $i $i]
    }
    my options $options
    next
  }



  ###########################################################
  #
  # ::xowiki::FormField::event
  #
  ###########################################################

  Class FormField::event -superclass CompoundField -parameter {
  }

  FormField::event instproc initialize {} {
    #my msg "EVENT has value [my value]"
    my set widget_type event
    my set structure {
      {summary {richtext,required,editor=wym,height=150px,label=#xowiki.event-title_of_lecture#}}
      {dtstart {date,required,format=DD_MONTH_YYYY_#xowiki.event-hour_prefix#_HH24_MI,
                default=now,label=#xowiki.event-start_of_lecture#,display_format=%Q_%X}}
      {dtend   date,format=HH24_MI,default=now,label=#xowiki.event-end_of_lecture#,display_format=%X}
      {location text,label=#xowiki.event-location#}
    }
    foreach entry [my set structure] {
      foreach {name spec} $entry break
      #
      # create for each component a form field
      #
      set c [::xowiki::FormField create [self]::$name \
                 -name [my name].$name -id [my id].$name -locale [my locale] -spec $spec]
      my set component_index([my name].$name) $c
      my lappend components $c
    }
  }

  FormField::event instproc get_compound_value {} {
    set dtstart  [my get_component dtstart]
    set dtend    [my get_component dtend]
    set end_day  [lindex [$dtstart value] 0]
    set end_time [lindex [$dtend value] 1]
    $dtend value "$end_day $end_time"
    #my msg "[$dtend name] set to '$end_day $end_time' ==> $dtend, [$dtend value]"
    next
  }

  FormField::event instproc pretty_value {v} {
    array set {} [my value]
    set dtstart [my get_component dtstart]
    set dtstart_val [$dtstart value]
    set dtstart_iso [::xo::ical clock_to_iso [clock scan $dtstart_val]]

    set dtend [my get_component dtend]
    set dtend_val [$dtend value]
    set dtend_txt ""
    if {$dtend_val ne ""} {
      set dtend_iso [::xo::ical clock_to_iso [clock scan $dtend_val]]
      set dtend_txt " - <abbr class='dtend' title='$dtend_iso'>[$dtend pretty_value $dtend_val]</abbr>"
    }

    set summary_txt "<span class='summary'>[[my get_component summary] value]</span>"

    set location [my get_component location]
    set location_val [$location value]
    set location_txt ""
    if {$location_val ne ""} {
      set location_label [$location label]
      if {[regexp {^#(.+)#$} $location_label _ msg_key]} {
	set location_label [lang::message::lookup [my locale] $msg_key]
      }
      set location_txt "$location_label: <span class='location'>$location_val</span>"
    }

    append result \
        "<div class='vevent'>" \
        $summary_txt " " \
        "<abbr class='dtstart' title='$dtstart_iso'>[$dtstart pretty_value $dtstart_val]</abbr>" \
        $dtend_txt <br> \
        $location_txt \
        "</div>" 
    return $result
  }

  ###########################################################
  #
  # a few test cases
  #
  ###########################################################

  proc ? {cmd expected {msg ""}} {
    ::xo::Timestamp t1
    set r [uplevel $cmd]
    if {$msg eq ""} {set msg $cmd}
    if {$r ne $expected} {
      regsub -all \# $r "" r
      append ::_ "Error: $msg returned \n'$r' ne \n'$expected'\n"
    } else {
      append ::_ "$msg - passed ([t1 diff] ms)\n"
    }
  }
  #
  proc test_form_fields {} {
    set ::_ ""
    set o [Object new -destroy_on_cleanup]
    # mixin methods for create_form_field
    $o mixin ::xowiki::Page

    set f0 [$o create_form_field -name test \
                -slot ::xowiki::Page::slot::name]
    ? {$f0 asWidgetSpec} \
        {text {label #xowiki.Page-name#}  {html {size 80 }}  {help_text {Shortname to identify an entry within a folder, typically lowercase characters}}} \
        "name with help_text"

    set f0 [$o create_form_field -name test \
                -slot ::xowiki::Page::slot::name -spec inform]
    ? {$f0 asWidgetSpec} \
        {text(inform) {label #xowiki.Page-name#}  {help_text {Shortname to identify an entry within a folder, typically lowercase characters}}} \
        "name with help_text + inform"

    set f0 [$o create_form_field -name test \
                -slot ::xowiki::Page::slot::name -spec optional]
    ? {$f0 asWidgetSpec} \
        {text,optional {label #xowiki.Page-name#}  {html {size 80 }}  {help_text {Shortname to identify an entry within a folder, typically lowercase characters}}} \
        "name with help_text + optional"

    set f1 [$o create_form_field -name test \
               -slot ::xowiki::Page::slot::description \
               -spec "textarea,cols=80,rows=2"]
    ? {$f1 asWidgetSpec} \
        {text(textarea),nospell,optional {label #xowiki.Page-description#}  {html {cols 80 rows 2 }} } \
        "textarea,cols=80,rows=2"

    set f2 [$o create_form_field -name test \
                -slot ::xowiki::Page::slot::nls_language \
                -spec {select,options=[xowiki::locales]}]
    ? {$f2 asWidgetSpec} \
        {text(select),optional {label #xowiki.Page-nls_language#}  {options {[xowiki::locales]}} } \
        {select,options=[xowiki::locales]}


    $o mixin ::xowiki::PodcastItem
    set f3 [$o create_form_field -name test \
                -slot ::xowiki::PodcastItem::slot::pub_date]
    ? {$f3 asWidgetSpec} \
        {date,optional {label #xowiki.PodcastItem-pub_date#}  {format {YYYY MM DD HH24 MI}} } \
        {date with format}
  }
}
