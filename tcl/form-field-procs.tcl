ad_library {
    XoWiki - form fields

    @creation-date 2007-06-22
    @author Gustaf Neumann
    @cvs-id $Id$
}

namespace eval ::xowiki::formfield {

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
  Class create FormField -superclass ::xo::tdom::Object -parameter {
    {required false} 
    {display_field true} 
    {hide_value false} 
    {inline false}
    {disabled}
    {show_raw_value}
    CSSclass
    style
    form-widget-CSSclass
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
    slot
    answer
    feedback_answer_correct
    feedback_answer_incorrect
  }
  FormField set abstract 1
  FormField instproc init {} {
    if {![my exists label]} {my label [string totitle [my name]]}
    if {![my exists id]} {my id [my name]}
    if {[my exists id]}  {my set html(id) [my id]}
    #if {[my exists default]} {my set value [my default]}
    my config_from_spec [my spec]
  }

  FormField instproc validate {obj} {
    my instvar name required
    # use the 'value' method to deal e.g. with compound fields
    set value [my value]
    if {$required && $value eq "" && ![my istype ::xowiki::formfield::hidden]} {
      my instvar label
      return [_ acs-templating.Element_is_required]
    }
    # 
    #my msg "++ [my name] [my info class] validator=[my validator] ([llength [my validator]])"
    foreach validator [my validator] {
      set errorMsg ""
      #
      # The validator might set the variable errorMsg in this scope.
      #
      set success 1
      set validator_method check=$validator
      set proc_info [my procsearch $validator_method]
      #my msg "++ [my name]: field-level validator exists '$validator_method' ? [expr {$proc_info ne {}}]"
      if {$proc_info ne ""} {
        # we have a slot checker, call it
	#my msg "++ call-field level validator $validator_method '$value'" 
	set success [my $validator_method $value]
      } 
      if {$success == 1} {
        # the previous check was ok, check now for a validator on the
        # object level
	set validator_method validate=$validator
	set proc_info [$obj procsearch $validator_method]
        #my msg "++ [my name]: page-level validator exists ? [expr {$proc_info ne {}}]"
        if {$proc_info ne ""} {
          #my msg "++ call page-level validator $validator_method '$value'" 
          set success [$obj $validator_method $value]
        }
      }
      if {$success == 0} {
        #
        # We have an error message. Get the class name from procsearch and construct
        # a message key based on the class and the name of the validator.
        #
        set cl [namespace tail [lindex $proc_info 0]]
        return [_ xowiki.$cl-validate_$validator [list value $value errorMsg $errorMsg]]
        #return [::lang::message::lookup "" xowiki.$cl-validate_$validator %errorMsg% [list value $value errorMsg $errorMsg] 1]
      }
    }
    return ""
  }

  FormField instproc reset_parameter {} {
    # reset application specific parameters (defined below ::xowiki::formfield::FormField)
    # such that searchDefaults will pick up the new defaults, when a form field
    # is reclassed.

    if {[my exists per_object_behavior]} {
      # remove per-object mixin from the "behavior"
      my mixin delete [my set per_object_behavior]
      my unset per_object_behavior
    }

    #my msg "reset along [my info precedence]"
    foreach c [my info precedence] {
      if {$c eq "::xowiki::formfield::FormField"} break
      foreach s [$c info slots] {
        if {![$s exists default]} continue
	set var [$s name]
        set key processed($var)
        if {[info exists $key]} continue
        my set $var [$s default]
        set $key 1
      }
    }
    if {[my exists disabled]} {
      my set_disabled 0
    }
  }

  FormField instproc interprete_condition {cond} {
    set package_id [[my object] package_id]
    #set policy [$package_id set policy]
    #set success [$policy check_privilege \
    #                 -user_id [::xo::cc user_id] \
    #                 -package_id $package_id $cond [self] view]
    if {[::xo::cc info methods role=$cond] ne ""} {
      if {$cond eq "creator"} {
	set success [::xo::cc role=$cond \
			 -object [my object] \
			 -user_id [::xo::cc user_id] \
			 -package_id $package_id]
      } else {
	set success [::xo::cc role=$cond \
			 -user_id [::xo::cc user_id] \
			 -package_id $package_id]
      }
    } else {
      set success 0
    }
    return $success
  }
  
  FormField instproc remove_omit {} {
    set m ::xowiki::formfield::omit
    if {[my ismixin $m]} {my mixin delete $m}
  }
  FormField instproc set_disabled {disable} {
    #my msg "[my name] set disabled $disable"
    if {$disable} {
      my set disabled true
    } else {
      my unset -nocomplain disabled
    }
  }

  FormField instproc behavior {mixin} {
    #
    # Specify the behavior of a form field via 
    # per object mixins
    #
    set obj [my object]
    set pkgctx [[$obj package_id] context]
    if {[$pkgctx exists embedded_context]} {
      set ctx [$pkgctx set embedded_context]
      set classname ${ctx}::$mixin
      #my msg ctx=$ctx-viewer=$mixin,found=[my isclass $classname]
      # TODO: search different places for the mixin. Special namespace?
      if {[my isclass $classname]} {
        if {[my exists per_object_behavior]} {
          my mixin delete [my set per_object_behavior]
        }
        my mixin add $classname
        my set per_object_behavior $classname
      } else {
        my msg "Could not find mixin '$mixin'"
      }
    }
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
      required    {my set required true; my remove_omit}
      omit        {my mixin add ::xowiki::formfield::omit}
      noomit      {my remove_omit}
      disabled    {my set_disabled true}
      enabled     {my set_disabled false}
      label=*     {my label     [lindex [split $s =] 1]}
      help_text=* {my help_text [lindex [split $s =] 1]}
      *=*         {
        set p [string first = $s]
        set attribute [string range $s 0 [expr {$p-1}]]
        set value [string range $s [expr {$p+1}] end]
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
          my $attribute $value
        } errMsg]} {
          error "Error during setting attribute '$attribute' to value '$value': $errMsg"
        }
      }
      default {
        # Check, if the spec value $s is a class. 
        set old_class [my info class]
        # Don't allow to use namespaced values, since we would run 
        # into a recursive loop for richtext::wym (could be altered there as well).
        if {[my isclass ::xowiki::formfield::$s] && ![string match "*:*" $s]} {
          my class ::xowiki::formfield::$s
	  my remove_omit
          if {$old_class ne [my info class]} {
            #my msg "reset class from $old_class to [my info class]"
            my reset_parameter
            my initialize
          }
          #my msg "[my name] [self] [my info class] before searchDefaults, validator='[my validator]'"
          #::xotcl::Class::Parameter searchDefaults [self]; # TODO: will be different in xotcl 1.6.*
          #my msg "[my name] [self] [my info class] after searchDefaults, validator='[my validator]'"
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
    #my log "spec=$spec [my info class] [[my info class] exists abstract]"
    my instvar type
    if {[[my info class] exists abstract]} {
      # had earlier here: [my info class] eq [self class]
      # Check, wether the actual class is a concrete class (mapped to
      # concrete field type) or an abstact class.  Since
      # config_from_spec can be called multiple times, we want to do
      # the reclassing only once.
      if {[my isclass ::xowiki::formfield::$type]} {
        my class ::xowiki::formfield::$type
      } else {
        my class ::xowiki::formfield::text
      }
      # TODO: reset_parameter? needed?
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
    set class form-widget
    if {[my exists form-widget-CSSclass]} {append class " [my form-widget-CSSclass]"}
    ::html::div -class $class { my render_input }
  }

  FormField instproc render_input {} {
    # This is the most general widget content renderer. 
    # If no special renderer is defined, we fall back to this one, 
    # which is in most cases  a simple input fied of type string.
    ::html::input [my get_attributes type size maxlength id name value disabled {CSSclass class}] {}
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

  FormField instproc localize {v} {
    # We localize in pretty_value the message keys in the 
    # language of the item (not the connection item).
    if {[regexp "^#(.*)#$" $v _ key]} {
      return [lang::message::lookup [my locale] $key]
    }
    return $v
  }

  FormField instproc value_if_nothing_is_returned_from_from {default} {
    return $default
  }

  FormField instproc pretty_value {v} {
    #my log "mapping $v"
    return [string map [list & "&amp;" < "&lt;" > "&gt;" \" "&quot;" ' "&apos;" @ "&#64;"] $v]
  }

  FormField instproc field_value {v} {
    if {[my exists show_raw_value]} {
      return $v
    } else {
      return [my pretty_value]
    }
  }

  ###########################################################
  #
  # helper method for extending slots: 
  # either, we make a meta class for form-fields, or this should 
  # should go into xotcl-core
  #
  ###########################################################

  ::Serializer exportMethods {
    ::xotcl::Class instproc extend_slot 
  }
  Class instproc extend_slot {name value} {
    # create a mirroring slot and add the specified value to the default
    foreach c [my info heritage] {
      if {[info command ${c}::slot::$name] ne ""} {
        set value [concat $value [${c}::slot::$name default]]
        break
      }
    }
    my slots [list Attribute validator -default $value]
  }

  ###########################################################
  #
  # ::xowiki::formfield::submit_button
  #
  ###########################################################

  Class submit_button -superclass FormField 
  submit_button  instproc initialize {} {
    my set type submit
    my set value [::xo::localize [_ xowiki.Form-submit_button]]
  }
  submit_button instproc render_input {} {
    # don't disable submit buttons
    if {[my type] eq "submit"} {my unset -nocomplain disabled}
    ::html::input [my get_attributes name type {CSSclass class} value disabled] {}
    my render_localizer
  }

  ###########################################################
  #
  # ::xowiki::formfield::hidden
  #
  ###########################################################

  Class hidden -superclass FormField
  hidden instproc initialize {} {
    my type hidden
    my set widget_type text(hidden)
    # remove mixins in case of retyping
    my mixin ""
  }
  hidden instproc render_item {} {
    # don't render the labels
    my render_form_widget
  }
  hidden instproc render_help_text {} {
  }

  ###########################################################
  #
  # ::xowiki::formfield::omit
  #
  ###########################################################

  Class omit -superclass FormField
  omit instproc render_item {} {
    # don't render the labels
    #my render_form_widget
  }
  omit instproc render_help_text {} {
  }

  ###########################################################
  #
  # ::xowiki::formfield::inform
  #
  ###########################################################
  
  Class inform -superclass FormField
  inform instproc initialize {} {
    my type hidden
    my set widget_type text(inform)
  }
  inform instproc render_input {} {
    ::html::t [my value]
    ::html::input [my get_attributes type id name value disabled {CSSclass class}] {}
  }
  inform instproc render_help_text {} {
  }

  ###########################################################
  #
  # ::xowiki::formfield::text
  #
  ###########################################################

  Class text -superclass FormField -parameter {
    {size 80}
    maxlength
  }
  text instproc initialize {} {
    my type text
    my set widget_type text
    foreach p [list size maxlength] {if {[my exists $p]} {my set html($p) [my $p]}}
  }
  ###########################################################
  #
  # ::xowiki::formfield::password
  #
  ###########################################################

  Class password -superclass text 
  password instproc initialize {} {
    next
    my set widget_type password
    my type password
  }
  ###########################################################
  #
  # ::xowiki::formfield::numeric
  #
  ###########################################################

  Class numeric -superclass text \
      -extend_slot validator numeric
  numeric instproc initialize {} {
    next
    my set widget_type numeric
  }
  numeric instproc check=numeric {value} {
    return [string is double $value]
  }

  ###########################################################
  #
  # ::xowiki::formfield::user_id
  #
  ###########################################################

  Class user_id -superclass numeric -parameter {
  }
  user_id instproc initialize {} {
    next
    my set is_party_id 1
  }
  user_id instproc pretty_value {v} {
    return [::xo::get_user_name $v]
  }

 ###########################################################
  #
  # ::xowiki::formfield::party_id
  #
  ###########################################################

  Class party_id -superclass user_id \
      -extend_slot validator party_id_check
  party_id instproc check=party_id_check {value} {
    if {$value eq ""} {return 1}
    return [db_0or1row dbq..check_party "select 1 from parties where party_id = :value"]
  }

  ###########################################################
  #
  # ::xowiki::formfield::url
  #
  ###########################################################

  Class url -superclass text -parameter {
    {link_label}
  }
  url instproc pretty_value {v} {
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
  # ::xowiki::formfield::detail_link
  #
  ###########################################################

  Class detail_link -superclass url -parameter {
    {link_label "#xowiki.weblog-more#"}
  }
  detail_link instproc pretty_value {v} {
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
  # ::xowiki::formfield::textarea
  #
  ###########################################################

  Class textarea -superclass FormField -parameter {
    {rows 2}
    {cols 80}
    {spell false}
  }
  textarea instproc initialize {} {
    my set widget_type text(textarea)
    foreach p [list rows cols style] {if {[my exists $p]} {my set html($p) [my $p]}}
    if {![my istype ::xowiki::formfield::richtext] && [my exists editor]} {
      # downgrading
      #my msg "downgrading [my info class]"
      foreach m [my info mixin] {if {[$m exists editor_mixin]} {my mixin delete $m}}
      foreach v {editor options} {if {[my exists $v]} {my unset $v}}
    }
    next
  }

  textarea instproc render_input {} {
    ::html::textarea [my get_attributes id name cols rows style {CSSclass class} disabled] {
      ::html::t [my value]
    }
  }

  ###########################################################
  #
  # ::xowiki::formfield::richtext
  #
  ###########################################################

  Class richtext -superclass textarea \
      -extend_slot validator safe_html \
      -parameter {
        plugins 
        folder_id
        width
        height
        {wiki false}
      }
  
  richtext instproc editor {args} {
    #
    # TODO: this should be made a slot setting
    #
    #my msg "setting editor for [my name], args=$args,[llength $args]"
    if {[llength $args] == 0} {return [my set editor]}
    set editor [lindex $args 0]
    if {[my exists editor] && $editor eq [my set editor] && [my exists __initialized]} return

    set editor_class [self class]::$editor
    if {$editor ne "" && ![my hasclass $editor_class]} {
      if {![my isclass $editor_class]} {
	set editors [list]
	foreach c [::xowiki::formfield::richtext info subclass] {
          if {![$c exists editor_mixin]} continue
	  lappend editors [namespace tail $c]
	}
	error [_ xowiki.error-form_constraint-unknown_editor \
		   [list name [my name] editor [my editor] editors $editors]]
      }
      foreach m [my info mixin] {if {[$m exists editor_mixin]} {my mixin delete $m}}
      my mixin add $editor_class
      #my msg "MIXIN $editor: [my info precedence]"
      my reset_parameter
      my set __initialized 1
    } 
    my set editor $editor
  }

  richtext instproc initialize {} {
    my display_field false
    next
    if {![my exists editor]} {my set editor xinha} ;# set the default editor
    if {![my exists __initialized]} {
      # Mixin the editor based on the attribute 'editor' if necessary
      # and call initialize again in this case...
      my editor [my set editor]
      my initialize
    }
  }

  richtext instproc render_richtext_as_div {} {
    #my msg "[my get_attributes id style {CSSclass class}]"
    ::html::div [my get_attributes id style {CSSclass class}] {
      if {[my wiki]} {
        [my object] set unresolved_references 0
        [my object] set __unresolved_references [list]
        ::html::t -disableOutputEscaping [[my object] substitute_markup  [list [my value] text/html]]
      } else {
        ::html::t -disableOutputEscaping [my value]
      }
    }
    ::html::div
  }

  richtext instproc check=safe_html {value} {
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
  richtext instproc pretty_value {v} {
    # for richtext, perform minimal output escaping
    return [string map [list @ "&#64;"] $v]
  }

  ###########################################################
  #
  # ::xowiki::formfield::richtext::wym
  #
  ###########################################################
  Class richtext::wym -superclass richtext -parameter {
    {editor wym}
    {CSSclass wymeditor}
    width
    height
  }
  richtext::wym set editor_mixin 1
  richtext::wym instproc initialize {} {
    next
    my set widget_type richtext
  }
  richtext::wym instproc render_input {} {
    set disabled [expr {[my exists disabled] && [my disabled] ne "false"}]
    if {![my istype ::xowiki::formfield::richtext] || $disabled} {
      my render_richtext_as_div
    } else {
      ::xo::Page requireCSS "/resources/xowiki/wymeditor/skins/default/screen.css"
      ::xo::Page requireJS  "/resources/xowiki/jquery/jquery.js"
      ::xo::Page requireJS  "/resources/xowiki/wymeditor/jquery.wymeditor.pack.js"
      regsub -all {[.:]} [my id] {\\\\&} JID
      set config [list "skin: 'default'"]
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
        lappend config $postInit
      }
      if {$config ne ""} {
	set config \{[join $config ,]\}
      }
      ::xo::Page requireJS [subst -nocommand -nobackslash {
        jQuery(function() {
          jQuery("#$JID").wymeditor($config);
        });
      }]
      
      next
    }
  }
  ###########################################################
  #
  # ::xowiki::formfield::richtext::xinha
  #
  ###########################################################

  Class richtext::xinha -superclass richtext -parameter {
    javascript
    {height}
    {style}
  }
  richtext::xinha set editor_mixin 1
  richtext::xinha instproc initialize {} {
    next
    my set widget_type richtext
    if {![my exists plugins]} {
      my plugins \
          [parameter::get -parameter "XowikiXinhaDefaultPlugins" \
               -default [::xo::parameter get_from_package_key \
                             -package_key "acs-templating" -parameter "XinhaDefaultPlugins"]]
    }
    my set options [my get_attributes editor plugins width height folder_id javascript]
    # for the time being, we can't set the defaults via parameter, 
    # but only manually, since the editor is used as a mixin, the parameter
    # would have precedence over the defaults of subclasses
    if {![my exists height]} {my set height 350px}
    if {![my exists style]} {my set style "width: 100%;"}
  }
  richtext::xinha instproc render_input {} {
    set disabled [expr {[my exists disabled] && [my disabled] ne "false"}]
    if {![my istype ::xowiki::formfield::richtext] || $disabled} {
      my render_richtext_as_div
    } else {
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
  }

  ###########################################################
  #
  # ::xowiki::formfield::enumeration
  #
  ###########################################################

  # abstract superclass for select and radio
  Class enumeration -superclass FormField -parameter {
    {options}
    {category_tree}
  }
  enumeration set abstract 1
  enumeration instproc initialize {} {
    if {[my exists category_tree]} {
      my config_from_category_tree [my category_tree]
    }
  }
  enumeration abstract instproc render_input {}

  enumeration instproc pretty_value {v} {
    if {[my exists category_label($v)]} {
      return [my set category_label($v)]
    }
    if {[my exists multiple] && [my set multiple]} {
      foreach o [my set options] {
        foreach {label value} $o break
        set labels($value) [my localize $label]
      }
      set values [list]
      foreach i $v {lappend values $labels($i)}
      return [join $values {, }]
    } else {
      foreach o [my set options] {
        foreach {label value} $o break
        if {$value eq $v} {return [my localize $label]}
      }
    }
  }
  enumeration instproc config_from_category_tree {tree_name} {
    # Get the options of a select or rado from the specified
    # category tree.
    #
    # We could config as well from the mapped category tree,
    # and get required and multiple from there....
    #
    # The usage of the label does not seem to be very useful.
    #
    #set tree_id [category_tree::get_id $tree_name [my locale]]
    set tree_id [category_tree::get_id $tree_name]
    if {$tree_id eq ""} {
      my msg "cannot lookup category tree name '$tree_name'"
      return
    }
    #
    # In case there are multiple trees with the same named map,
    # take the first one to avoid confusions.
    #
    #my msg tree_id=$tree_id
    set tree_id [lindex $tree_id 0]
    set subtree_id ""
    set options [list] 

    foreach category [category_tree::get_tree -subtree_id $subtree_id $tree_id] {
      foreach {category_id category_name deprecated_p level} $category break
      #if {[lsearch $category_ids $category_id] > -1} {lappend value $category_id}
      #lappend value $category_id
      set category_name [ad_quotehtml [lang::util::localize $category_name]]
      my set category_label($category_id) $category_name
      if { $level>1 } {
        set category_name "[string repeat {&nbsp;} [expr {2*$level-4}]]..$category_name"
      }
      lappend options [list $category_name $category_id]
    }
    my options $options
    my set is_category_field 1
    # my msg label_could_be=$tree_name,existing=[my label]
    # if {![my exists label]} {
    #    my label $tree_name
    # }
  }

  ###########################################################
  #
  # ::xowiki::formfield::radio
  #
  ###########################################################

  Class radio -superclass enumeration -parameter {
    {horizontal false}
  }
  radio instproc initialize {} {
    my set widget_type text(radio)
    next
  }
  radio instproc render_input {} {
    set value [my value]
    foreach o [my options] {
      foreach {label rep} $o break
      set atts [my get_attributes disabled {CSSclass class}]
      lappend atts id [my id]:$rep name [my name] type radio value $rep
      if {$value eq $rep} {lappend atts checked checked}
      ::html::input $atts {}
      html::t "$label  "
      if {![my horizontal]} {html::br}
    }
  }


  ###########################################################
  #
  # ::xowiki::formfield::select
  #
  ###########################################################

  Class select -superclass enumeration -parameter {
    {multiple "false"}
  }

  select instproc initialize {} {
    my set widget_type text(select)
    next
    if {![my exists options]} {my options [list]}
  }
  select instproc render_input {} {
    set atts [my get_attributes id name disabled]
    if {[my multiple]} {lappend atts multiple [my multiple]}
    set options [my options]
    if {![my required]} {
      set options [linsert $options 0 [list "--" ""]]
    }
    ::html::select $atts {
      foreach o $options {
        foreach {label rep} $o break
        set atts [my get_attributes disabled]
        lappend atts value $rep
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
  # ::xowiki::formfield::abstract_page
  #
  ###########################################################
  Class abstract_page -superclass select -parameter {
    {as_box false}
  }
  abstract_page set abstract 1

  abstract_page instproc initialize {} {
    my compute_options
    next
  }
  
  abstract_page instproc pretty_value {} {
    my instvar package_prefix package_id

    if {[my multiple]} {
      foreach o [my set options] {
        foreach {label value} $o break
        set href [$package_id pretty_link $value]
        set labels($value) "<a href='$href'>$label</a>"
      }
      set values [list]
      foreach i $v {
        if {[catch {lappend values $labels($i)}]} {
          my msg "can't determine label for value '$i'"
          lappend values $i
        }
      }
      return [join $values {, }]
    } else {
      foreach o [my set options] {
        foreach {label value} $o break
        if {$value eq $v} {
          if {[my as_box]} {
            return [[my object] include [list $package_prefix$value -decoration rightbox]] 
          }
          set href [$package_id pretty_link $value]
          return "<a href='$href'>$label</a>"
        }
      }
    }
  }

  ###########################################################
  #
  # ::xowiki::formfield::form_page
  #
  ###########################################################
  Class form_page -superclass abstract_page -parameter {
    {form}
    {where}
  }
  form_page instproc compute_options {} {
    my instvar form_obj package_prefix where
    
    if {![my exists form]} {
      return
    }
    set form_name [my form]

    set form_obj [[my object] resolve_included_page_name $form_name]
    if {$form_obj eq ""} {error "Cannot lookup Form '$form_name'"}

    set package_prefix ""
    regexp {^(//[^/]+/)} $form_name _ package_prefix

    array set wc {tcl true h "" vars "" sql ""}
    if {[info exists where]} {
      array set wc [::xowiki::FormPage filter_expression $where &&]
      #my msg "where '$where' => wc=[array get wc]"
    }
    set options [list]    
    set items [::xowiki::FormPage get_children \
                   -base_item_id [$form_obj item_id] \
                   -form_fields [list] \
                   -publish_status ready \
                   -always_queried_attributes [list _name _title _last_modified _creation_user] \
                   -h_where [array get wc] \
                   -package_id [$form_obj package_id]]
    foreach i [$items children] {lappend options [list [$i title] [$i name]]}
    my options $options
  }

  form_page instproc pretty_value {v} {
    if {![my exists form_obj]} {
      error "No form specified for form_field [my name]"
    }
    my set package_id [$form_obj package_id]
    next
  }


  ###########################################################
  #
  # ::xowiki::formfield::page
  #
  ###########################################################
  Class page -superclass abstract_page -parameter {
    {type ::xowiki::Page}
    {with_subtypes false}
    {glob}
  }
  page instproc compute_options {} {
    my instvar type with_subtypes glob package_prefix
    # We could use the package_prefix like in form_page when refering to pages 
    # in different packages. 
    set package_prefix ""

    set extra_where_clause ""
    if {[my exists glob]} {
      set glob [string map [list * %] $glob]
      set extra_where_clause " and ci.name like '$glob'"
    }

    set package_id [[my object] package_id]
    set options [list]
    db_foreach instance_select \
        [$type instance_select_query \
             -folder_id [$package_id folder_id] \
             -with_subtypes $with_subtypes \
             -select_attributes [list title] \
             -from_clause ", xowiki_page p" \
             -where_clause "p.page_id = bt.revision_id $extra_where_clause" \
             -orderby ci.name \
            ] {
              lappend options [list $name $name]
            }
    my options $options
  }

  page instproc pretty_value {v} {
    my set package_id [[my object] package_id]
    next
  }



  ###########################################################
  #
  # ::xowiki::formfield::DD
  #
  ###########################################################

  Class DD -superclass FormField -superclass select
  DD instproc initialize {} {
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
  # ::xowiki::formfield::HH24
  #
  ###########################################################

  Class HH24 -superclass FormField -superclass select
  HH24 instproc initialize {} {
    my options {
      {00  0} {01  1} {02  2} {03  3} {04  4} {05  5} {06  6} {07  7} {08  8} {09  9} 
      {10 10} {11 11} {12 12} {13 13} {14 14} {15 15} {16 16} {17 17} {18 18} {19 19} 
      {20 20} {21 21} {22 22} {23 23} 
    }
    next
  }

  ###########################################################
  #
  # ::xowiki::formfield::MI
  #
  ###########################################################

  Class MI -superclass FormField -superclass select
  MI instproc value args {
    if {[llength $args] == 0} {return [my set value]} else {
      set v [lindex $args 0]
      if {$v eq ""} {return [my set value ""]} else {
	# round to 5 minutes
	my set value [lindex [my options] [expr {($v + 2) / 5}] 1]
      }
    }
  }
  MI instproc initialize {} {
    my options {
      {00  0} {05  5} {10 10} {15 15} {20 20} {25 25} 
      {30 30} {35 35} {40 40} {45 45} {50 50} {55 55}
    }
    next
  }

  ###########################################################
  #
  # ::xowiki::formfield::MM
  #
  ###########################################################

  Class MM -superclass FormField -superclass select
  MM instproc initialize {} {
    my options {
      {01  1} {02  2} {03 3} {04 4} {05 5} {06 6} {07 7} {08 8} {09 9} {10 10}
      {11 11} {12 12} 
    }
    next
  }
  ###########################################################
  #
  # ::xowiki::formfield::mon
  #
  ###########################################################

  Class mon -superclass select
  mon instproc initialize {} {
    set values [lang::message::lookup [my locale] acs-lang.localization-abmon]
    if {[lang::util::translator_mode_p]} {set values [::xo::localize $values]}
    set last 0
    foreach m {1 2 3 4 5 6 7 8 9 10 11 12} {
      lappend options [list [lindex $values $last] $m]
      set last $m
    }
    my options $options
    next
  }
  ###########################################################
  #
  # ::xowiki::formfield::month
  #
  ###########################################################

  Class month -superclass select
  month instproc initialize {} {
    set values [lang::message::lookup [my locale] acs-lang.localization-mon]
    if {[lang::util::translator_mode_p]} {set values [::xo::localize $values]}
    set last 0
    foreach m {1 2 3 4 5 6 7 8 9 10 11 12} {
      lappend options [list [lindex $values $last] $m]
      set last $m
    }
    my options $options
    next
  }

  ###########################################################
  #
  # ::xowiki::formfield::YYYY
  #
  ###########################################################

  Class YYYY -superclass numeric -parameter {
    {size 4}
    {maxlength 4}
  }

  ###########################################################
  #
  # ::xowiki::formfield::image_url
  #
  ###########################################################

  Class image_url -superclass text \
      -extend_slot validator image_check \
      -parameter {
        href cssclass
        {float left} width height 
        padding {padding-right 10px} padding-left padding-top padding-bottom
        margin margin-left margin-right margin-top margin-bottom
        border border-width position top botton left right
      }
  image_url instproc entry_name {value} {
    set value [string map [list %2e .] $value]
    if {![regexp -nocase {/([^/]+)[.](gif|jpg|jpeg|png)} $value _ name ext]} {
      return ""
    }
    return image:$name.$ext
  }
  image_url instproc check=image_check {value} {
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
  image_url instproc pretty_value {v} {
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
  } -extend_slot validator compound

  CompoundField instproc check=compound {value} {
    #my msg "check compound in [my components]"
    foreach c [my components] {
      set error [$c validate [self]]
      if {$error ne ""} {
	set msg "[$c label]: $error"
	my uplevel [list set errorMsg $msg]
	#util_user_message -message "Error in compound field [$c name]: $error"
	return 0
      }
    }
    return 1
  }

  CompoundField instproc set_disabled {disable} {
    #my msg "[my name] set disabled $disable"
    if {$disable} {
      my set disabled true
    } else {
      my unset -nocomplain disabled
    }
    foreach c [my components] {
      $c set_disabled $disable
    }
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

  CompoundField instproc render_input {} {
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
  # ::xowiki::formfield::label
  #
  ###########################################################

  Class label -superclass FormField -parameter {
    {disableOutputEscaping false}
  }
  label instproc initialize {} {next}
  label instproc render_item {} {
    # sanity check; required and label do not fit well together
    if {[my required]} {my required false}
    next
  }
  label instproc render_input {} {
    if {[my disableOutputEscaping]} {
      ::html::t -disableOutputEscaping [my value]
    } else {
      ::html::t [my value]
    }
  }

  ###########################################################
  #
  # ::xowiki::formfield::date
  #
  ###########################################################

  Class date -superclass CompoundField -parameter {
    {format "DD MONTH YYYY"}
    {display_format "%Y-%m-%d %T"}
  }
  # The default of a date might be all relative dates
  # supported by clock scan. These include "now", "tomorrow",
  # "yesterday", "next week", .... use _ for blanks

  date instproc initialize {} {
    #my msg "DATE has value [my value]//d=[my default] format=[my format] disabled?[my exists disabled]"
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
        set c [::xowiki::formfield::label create [self]::$name \
                   -name [my name].$name -id [my id].$name -locale [my locale] -value $element]
        $c set_disabled [my exists disabled]
        if {[lsearch [my components] $c] == -1} {my lappend components $c}
        continue
      }
      foreach {class code trim_zeros} [my set format_map($element)] break
      #
      # create for each component a form field
      #
      set name $class
      set c [::xowiki::formfield::$class create [self]::$name \
               -name [my name].$name -id [my id].$name -locale [my locale]]
      $c set_disabled [my exists disabled]
      $c set code $code
      $c set trim_zeros $trim_zeros
      if {[lsearch [my components] $c] == -1} {my lappend components $c}
    }
  }

  date instproc set_compound_value {value} {
    #my msg "[my name] original value '[my value]' // passed='$value' disa?[my exists disabled]"
    if {$value eq ""} {return}
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
      if {[$c istype ::xowiki::formfield::label]} continue
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
  
  date instproc get_compound_value {} {
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
    # Validation happens after the value is retrieved.
    # To avoid errors in "clock scan", fix the year if necessary
    if {![string is integer $year]} {set year 0}

    foreach v [list year month day hour min sec] {
      if {[set $v] eq ""} {set $v [my set defaults($v)]}
    }
    #my msg "$year-$month-$day ${hour}:${min}:${sec}"
    set ticks [clock scan "$year-$month-$day ${hour}:${min}:${sec}"]
    # TODO: TZ???
    #my msg "DATE [my name] get_compound_value returns [clock format $ticks -format {%Y-%m-%d %T}]"
    return [clock format $ticks -format "%Y-%m-%d %T"]
  }

  date instproc pretty_value {v} {
    #
    # Internally, we use the ansi date format. For displaying the date, 
    # use the specified display format and present the time localized.
    #
    # Drop of the value after the "." we assume to have a date in the local zone
    regexp {^([^.]+)[.]} $v _ v
    #return [clock format [clock scan $v] -format [string map [list _ " "] [my display_format]]]
    return [lc_time_fmt $v [string map [list _ " "] [my display_format]] [my locale]]
  }

  date instproc render_input {} {
    #
    # render the content inline withing a fieldset, without labels etc.
    #
    my set style "margin: 0px; padding: 0px;"
    html::fieldset [my get_attributes id style] {
      foreach c [my components] { $c render_input }
    }
  }

  ###########################################################
  #
  # ::xowiki::boolean
  #
  ###########################################################

  Class boolean -superclass radio -parameter {
    {default t}
  }
  boolean instproc value_if_nothing_is_returned_from_from {default} {
    return f
  }
  boolean instproc initialize {} {
    # should be with cvs head message catalogs:
    # my options {{#acs-kernel.common_No# f} {#acs-kernel.common_Yes# t}}
    my options {{No f} {#acs-kernel.common_Yes# t}}
    next
  }

  ###########################################################
  #
  # ::xowiki::formfield::scale
  #
  ###########################################################

  Class scale -superclass radio -parameter {{n 5} {horizontal true}}
  scale instproc initialize {} {
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
  # ::xowiki::formfield::form
  #
  ###########################################################

  Class form -superclass richtext -parameter {
    {height 200}
  } -extend_slot validator form

  form instproc check=form {value} {
    set form $value
    #my msg form=$form
    dom parse -simple -html $form doc
    $doc documentElement root
    set rootNodeName ""
    if {$root ne ""} {set rootNodeName [$root nodeName]}
    return [expr {$rootNodeName eq "form"}]
  }

  ###########################################################
  #
  # ::xowiki::formfield::form_constraints
  #
  ###########################################################

  Class form_constraints -superclass textarea -parameter {
    {rows 5}
  } -extend_slot validator form_constraints
  # the form_constraints checker is defined already on the ::xowiki::Page level


  ###########################################################
  #
  # ::xowiki::formfield::event
  #
  ###########################################################

  Class event -superclass CompoundField -parameter {
  }

  event instproc initialize {} {
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
      set c [::xowiki::formfield::FormField create [self]::$name \
                 -name [my name].$name -id [my id].$name -locale [my locale] -spec $spec]
      my set component_index([my name].$name) $c
      my lappend components $c
    }
  }

  event instproc get_compound_value {} {
    set dtstart  [my get_component dtstart]
    set dtend    [my get_component dtend]
    set end_day  [lindex [$dtstart value] 0]
    set end_time [lindex [$dtend value] 1]
    $dtend value "$end_day $end_time"
    #my msg "[$dtend name] set to '$end_day $end_time' ==> $dtend, [$dtend value]"
    next
  }

  event instproc pretty_value {v} {
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
    # mixin methods for create_raw_form_field
    $o mixin ::xowiki::Page

    set f0 [$o create_raw_form_field -name test \
                -slot ::xowiki::Page::slot::name]
    ? {$f0 asWidgetSpec} \
        {text {label #xowiki.Page-name#}  {html {size 80 }}  {help_text {Shortname to identify an entry within a folder, typically lowercase characters}}} \
        "name with help_text"

    set f0 [$o create_raw_form_field -name test \
                -slot ::xowiki::Page::slot::name -spec inform]
    ? {$f0 asWidgetSpec} \
        {text(inform) {label #xowiki.Page-name#}  {help_text {Shortname to identify an entry within a folder, typically lowercase characters}}} \
        "name with help_text + inform"

    set f0 [$o create_raw_form_field -name test \
                -slot ::xowiki::Page::slot::name -spec optional]
    ? {$f0 asWidgetSpec} \
        {text,optional {label #xowiki.Page-name#}  {html {size 80 }}  {help_text {Shortname to identify an entry within a folder, typically lowercase characters}}} \
        "name with help_text + optional"

    set f1 [$o create_raw_form_field -name test \
               -slot ::xowiki::Page::slot::description \
               -spec "textarea,cols=80,rows=2"]
    ? {$f1 asWidgetSpec} \
        {text(textarea),nospell,optional {label #xowiki.Page-description#}  {html {cols 80 rows 2 }} } \
        "textarea,cols=80,rows=2"

    set f2 [$o create_raw_form_field -name test \
                -slot ::xowiki::Page::slot::nls_language \
                -spec {select,options=[xowiki::locales]}]
    ? {$f2 asWidgetSpec} \
        {text(select),optional {label #xowiki.Page-nls_language#}  {options {[xowiki::locales]}} } \
        {select,options=[xowiki::locales]}


    $o mixin ::xowiki::PodcastItem
    set f3 [$o create_raw_form_field -name test \
                -slot ::xowiki::PodcastItem::slot::pub_date]
    ? {$f3 asWidgetSpec} \
        {date,optional {label #xowiki.PodcastItem-pub_date#}  {format {YYYY MM DD HH24 MI}} } \
        {date with format}
  }
}
