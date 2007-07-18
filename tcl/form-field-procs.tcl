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
  Class FormField -parameter {
    {required false} 
    {display_field true} 
    {inline false} 
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
  }
  FormField instproc init {} {
    if {![my exists label]} {my label [string totitle [my name]]}
    if {![my exists id]} {my id [my name]}
    if {[my exists id]}  {my set html(id) [my id]}
    if {[my exists default]} {my set value [my default]}
    #my msg "calling config_from_spec '[my spec]'"
    my config_from_spec [my spec]
  }

  FormField instproc validate {obj} {
    my instvar name required value

    if {$required && $value eq ""} {
      my instvar label
      return [_ acs-templating.Element_is_required]
    }
    # todo: value type checker (through subtypes, check only if necessary)
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

  FormField instproc config_from_spec {spec} {
    my instvar type options widget_type

    if {[my info class] eq [self class]} {
      # Check, wether the actual class of the formfield differs from the
      # generic FromField class. If yes, the object was already 
      # reclassed to a concrete form field type. Since config_from_spec
      # can be called multiple times, we want to do the reclassing only
      # once.
      my class [self class]::$type
      ::xotcl::Class::Parameter searchDefaults [self]; # TODO: will be different in xotcl 1.6.*
    }

    foreach s [split $spec ,] {
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
            #my msg "Ignoring unknown spec for entry [my name]: '$s'"
            error [_ xowiki.error-form_constraint-unknown_spec_entry [list name [my name] entry $s x "Unknown spec entry for entry '$s'"]]
          }
        }
      }
    }

    #
    # It is possible, that a default value of a form field is changed through a spec.
    # Since only the configuration might set values, checking value for "" seems safe here.
    #
    if {[my value] eq "" && [my exists default] && [my default] ne ""} {
      # my msg "reset value to [my default]"
      my value [my default]
    }

    if {[lang::util::translator_mode_p]} {
      my mixin "::xo::TRN-Mode"
    }
    my initialize 
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

  FormField ad_instproc get_attributes {
    args
  } {
    Get a list of attribute value pairs
    of instance attributes. It returns only those
    pairs for which a value exists.

    @return flattened list of attribute value pairs
  } {
    set pairs [list]
    foreach attribute $args {
      set l [split $attribute]
      if {[llength $l] > 1} {
        foreach {attribute HTMLattribute} $l break
      } else {
        set HTMLattribute $attribute
      }
      #my msg "[my name] check for $attribute => [my exists $attribute]"
      if {[my exists $attribute]} {
        lappend pairs $HTMLattribute [my set $attribute]
      }
    }
    return $pairs
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
  # ::xowiki::FormField::textarea
  #
  ###########################################################

  Class FormField::textarea -superclass FormField -parameter {
    {rows 2}
    {cols 80}
    {spell false}
    style
    CSSclass
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
    javascript
    {height 350px}
    {style "width: 100%"}
  }
  FormField::richtext instproc initialize {} {
    # Reclass the editor based on the attribute 'editor' if necessary
    # and call initialize again in this case...
    my display_field false
    if {[my editor] eq ""} {
      next
    } elseif {[my info class] ne "[self class]::[my editor]"} {
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
  }
  FormField::richtext::wym instproc initialize {} {
    next
    my set widget_type richtext
    ::xowiki::Page requireCSS "/resources/xowiki/wymeditor/skins/default/screen.css"
    ::xowiki::Page requireJS  "/resources/xowiki/wymeditor/jquery.js"
    ::xowiki::Page requireJS  "/resources/xowiki/wymeditor/jquery.wymeditor.js"
    ::xowiki::Page requireJS {
      var $j = jQuery.noConflict();
      $j(function() {
        $j(".wymeditor").wymeditor();
      });
    }
  }

  ###########################################################
  #
  # ::xowiki::FormField::richtext::xinha
  #
  ###########################################################

  Class FormField::richtext::xinha -superclass FormField::richtext 
  FormField::richtext::xinha instproc initialize {} {
    next
    my set widget_type richtext
    if {![my exists plugins]} {
      my plugins \
          [parameter::get -parameter "XowikiXinhaDefaultPlugins" \
               -default [parameter::get_from_package_key \
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
        #my msg "lsearch {[my value]} $value ==> [lsearch [my value] $value]"
        if {[lsearch [my value] $rep] > -1} {
          lappend atts selected on
        }
        ::html::option $atts {::html::t $label}
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
  # ::xowiki::FormField::month
  #
  ###########################################################

  Class FormField::mon -superclass FormField::select
  FormField::mon instproc initialize {} {
    # localized values are in acs-lang.localization-mon
    my options {
      {Jan 1} {Feb 2} {Mar 3} {Apr  4} {May  5} {Jun  6}
      {Jul 7} {Aug 8} {Sep 9} {Oct 10} {Nov 11} {Dec 12}
    }
    next
  }
  ###########################################################
  #
  # ::xowiki::FormField::month
  #
  ###########################################################

  Class FormField::month -superclass FormField::select
  FormField::month instproc initialize {} {
    # localized values are in acs-lang.localization-mon
    my options {
      {January 1} {February 2} {March 3} {April 4} {May 5} {June 6}
      {July 7} {August 8} {September 9} {October 10} {November 11} {December 12}
    }
    next
  }

  ###########################################################
  #
  # ::xowiki::FormField::YYYY
  #
  ###########################################################

  Class FormField::YYYY -superclass FormField::text -parameter {
    {size 4}
    {maxlength 4}
  }

  ###########################################################
  #
  # ::xowiki::FormField::date
  #
  ###########################################################

  Class FormField::date -superclass FormField -parameter {
    {format "DD MONTH YYYY"}
    {display_format "%Y-%m-%d %T"}
  }
  # The default of a date might be all relative dates
  # supported by clock scan. These include "now", "tomorrow",
  # "yesterday", "next week", .... use _ for blanks

  FormField::date instproc initialize {} {
    my set widget_type date
    my set format [string map [list _ " "] [my format]]
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
    foreach {class code trim_zeros} [my components] {
      #
      # create for each component of the format a subobject named by the class
      #
      ::xowiki::FormField::$class create [self]::$class \
          -name [my name].$class -id [my id].$class 
    }
  }

  FormField::date instproc components {} {
    set components [list]
    foreach c [split [my format]] {
      if {![my exists format_map($c)]} {
        error "Unknown format component: $c. \
		Valid compontents are [my array names format_map]"
      }
      eval lappend components [my set format_map($c)]
    }
    return $components
  }
  
  FormField::date instproc set_compound_value {} {
    set value [my value]
    #my msg "date: value set to '$value'"
    if {$value ne ""} {
      set ticks [clock scan [string map [list _ " "] $value]]
    } else {
      set ticks ""
    }
    # set the value parts for each components
    foreach {class code trim_zeros} [my components] {
      if {$ticks ne ""} {
	set value_part [clock format $ticks -format $code]
	if {$trim_zeros} {
	  set value_part [string trimleft $value_part 0]
	  if {$value_part eq ""} {set value_part 0}
	}
      } else {
	set value_part ""
      }
      [self]::$class value $value_part
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
    if {$year  eq ""} {set year 2000}
    if {$month eq ""} {set month 1}
    if {$day   eq ""} {set day 1}
    if {$hour  eq ""} {set hour 0}
    if {$min   eq ""} {set min 0}
    if {$sec   eq ""} {set sec 0}
    #my msg "$year-$month-$day ${hour}:${min}:${sec}"
    set ticks [clock scan "$year-$month-$day ${hour}:${min}:${sec}"]
    # TODO: TZ???
    return [clock format $ticks -format "%Y-%m-%d %T"]
  }

  FormField::date instproc pretty_value {v} {
    # internally, we have ansi format. For displaying the date, use the display format
    return [clock format [clock scan $v] -format [string map [list _ " "] [my display_format]]]
  }

  FormField::date instproc render_content {} {
    my set_compound_value
    foreach {class code trim_zeros} [my components] {
      [self]::$class render_content
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
