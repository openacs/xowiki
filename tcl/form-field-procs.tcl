::xo::library doc {
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
  # todo: at some later time, this could go into xotcl-core

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
    {mode edit}
    {disabled}
    {show_raw_value}
    {CSSclass}
    {style}
    {type text} 
    {label} 
    {name} 
    {id} 
    {title}
    {value ""} 
    {spec ""} 
    {help_text ""}
    {error_msg ""}
    {validator ""}
    {validate_via_ajax}

    {autocomplete}
    {autofocus}
    {formnovalidate}
    {multiple}
    {pattern}
    {placeholder}
    {readonly}

    locale
    default
    object
    slot
    answer
    correct_when
    feedback_answer_correct
    feedback_answer_incorrect
  }
  FormField set abstract 1

  FormField proc fc_encode {string} {
    return [string map [list , __COMMA__] $string]
  }
  FormField proc fc_decode {string} {
    return [string map [list __COMMA__ ,] $string]
  }
  #FormField proc fc_decode_colon {string} {
  #  return [string map [list __COLON__ :] $string]
  #}

  FormField proc get_from_name {object name} {
    #
    # Get a form field via name. The provided names are unique for a
    # form. If multiple forms should be rendered simultaneously, we
    # have to extend the addressing mechanism.
    #
    # todo: we could speed this up by an index if needed
    foreach f [::xowiki::formfield::FormField info instances -closure] {
      if {[$f name] eq $name} {
        if {![$f exists object]} {
          my msg "strange, $f [$f name] was created without object but fits name"
          return $f
        } elseif {$object eq [$f object]} {
          return $f
        }
      }
    }
    #my msg not-found-$object-$name
    return ""
  }


  #FormField instproc destroy {} {
  #  my log "=== FormField DESTROY ====="
  #  next
  #}

  FormField instproc init {} {
    if {![my exists label]} {my label [string totitle [my name]]}
    if {![my exists id]} {my id [my name]}
    my set html(id) [my id]
    #if {[my exists default]} {my set value [my default]}
    my config_from_spec [my spec]
  }

  #
  # Basic initialze method, doing nothing; should be subclassed by the
  # application classes
  FormField instproc initialize {} {next}

  FormField instproc same_value {v1 v2} {
    if {$v1 eq $v2} {return 1}
    return 0
  }

  FormField instproc validation_check {validator_method value} {
    return [my uplevel [list my $validator_method $value]]
  }

  FormField instproc validate {obj} {
    my instvar name required

    # use the 'value' method to deal e.g. with compound fields
    set value [my value]
    #my msg "[my info class] value=$value req=$required // [my set value] //"

    if {$required && $value eq "" && ![my istype ::xowiki::formfield::hidden]} {
      my instvar label
      return [_ acs-templating.Element_is_required]
    }
    # 
    #my msg "++ [my name] [my info class] validator=[my validator] ([llength [my validator]]) value=$value"
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
        set success [my validation_check $validator_method $value]
      } 
      if {$success == 1} {
        # the previous check was ok, check now for a validator on the
        # object level
        set validator_method validate=$validator
        set proc_info [$obj procsearch $validator_method]
        #my msg "++ [my name]: page-level validator exists ? [expr {$proc_info ne {}}]"
        if {$proc_info ne ""} {
          set success [$obj $validator_method $value]
          #my msg "++ call page-level validator $validator_method '$value' returns $success" 
        }
      }
      if {$success == 0} {
        #
        # We have an error message. Get the class name from procsearch and construct
        # a message key based on the class and the name of the validator.
        #
        set cl [namespace tail [lindex $proc_info 0]]
        #my msg "__langPkg?[info exists __langPkg]"
        if {![info exists __langPkg]} {set __langPkg "xowiki"}
        return [_ $__langPkg.$cl-validate_$validator [list value $value errorMsg $errorMsg]]
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

  FormField proc interprete_condition {-package_id -object cond} {
    if {[::xo::cc info methods role=$cond] ne ""} {
      if {$cond eq "creator"} {
        set success [::xo::cc role=$cond \
                         -object $object \
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
  
  FormField set cond_regexp {^([^=?]+)[?]([^:]*)[:](.*)$}

  FormField proc get_single_spec {-package_id -object string} {
    if {[regexp [my set cond_regexp] $string _ condition true_spec false_spec]} {
      if {[my interprete_condition -package_id $package_id -object $object $condition]} {
        return [my get_single_spec -package_id $package_id -object $object $true_spec]
      } else {
        return [my get_single_spec -package_id $package_id -object $object $false_spec]
      }
    }
    return $string
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

    set object [my object]
    set package_id [$object package_id]
    set s [::xowiki::formfield::FormField get_single_spec -object $object -package_id $package_id $s]

    switch -glob -- $s {
      optional    {my set required false}
      required    {my set required true; my remove_omit}
      omit        {my mixin add ::xowiki::formfield::omit}
      noomit      {my remove_omit}
      disabled    {my set_disabled true}
      readonly    {my readonly true}
      enabled     {my set_disabled false}
      label=*     {my label     [lindex [split $s =] 1]}
      help_text=* {my help_text [lindex [split $s =] 1]}
      *=*         {
        set p [string first = $s]
        set attribute [string range $s 0 $p-1]
        set value [string range $s $p+1 end]
        set definition_class [lindex [my procsearch $attribute] 0]
        set method [my info methods $attribute]
        if {[string match "::xotcl::*" $definition_class] || $method eq ""} {
          error [_ xowiki.error-form_constraint-unknown_attribute [list class [my info class] name [my name] entry $attribute]]
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
            #my msg "[my name]: reset class from $old_class to [my info class]"
            my reset_parameter
            my set __state reset
            #my log "INITIALIZE [my name] due to reclassing old $old_class to new [my info class]"
            my initialize
          }
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
    #my log "config_from_spec [my name] spec <$spec> [my info class] [[my info class] exists abstract]"
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
      # set missing instance vars with defaults
      my set_instance_vars_defaults
    }
    regsub -all {,\s+} $spec , spec
    foreach s [split $spec ,] {
      my interprete_single_spec [FormField fc_decode $s]
    }

    #my msg "[my name]: after specs"
    my set __state after_specs
    #my log "INITIALIZE [my name] due to config_from_spec"
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
      my mixin add "::xo::TRN-Mode"
    }

  }

  FormField instproc asWidgetSpec {} {
    my instvar widget_type options label help_text format html display_html
    set spec $widget_type
    if {[my exists spell]} {append spec ",[expr {[my spell] ? {} : {no}}]spell"}

    if {![my required]} {append spec ",optional"}
    if {[my exists editor]} {append spec " {options {editor [my set editor]}} "}
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
        set internationalized [my localize $help_text]
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
    my set __rendered 1
  }
  
  FormField instproc render_form_widget {} {
    # This method provides the form-widget wrapper
    set CSSclass [my form_widget_CSSclass]
    if {[my error_msg] ne ""} {append CSSclass " form-widget-error"}
    set atts [list class $CSSclass]
    if {[my inline]} {lappend atts style "display: inline;"}
    ::html::div $atts { my render_input }
  }

  FormField instproc booleanAttributes {args} {
    #
    # Special handling of HTML boolean attributes, since they require a
    # different coding; it would be nice, if tdom would care for this.
    #
    set pairs ""
    foreach att $args {
      if {[my exists $att] && [my set $att]} {
        my set __#$att $att
        lappend pairs [list __#$att $att]
      }
    }
    return $pairs
  }

  FormField instproc resetBooleanAttributes {atts} {
    #
    # Unset the temporary boolean attributes which were set by method
    # "booleanAttributes".
    #
    foreach att $atts {
      lassign $att var value
      if {[my exists $var]} {my unset $var}
    }
  }

  FormField instproc render_input {} {
    #
    # This is the most general widget content renderer. 
    # If no special renderer is defined, we fall back to this one, 
    # which is in most cases  a simple input fied of type string.
    #
    if {[my mode] ne "edit"} {
      html::t -disableOutputEscaping [my pretty_value [my value]]
      return
    }
    if {[my exists validate_via_ajax] && [my validator] ne ""} {
      set ajaxhelper 1
      ::xowiki::Includelet require_YUI_JS -ajaxhelper 0 "yahoo/yahoo-min.js"
      ::xowiki::Includelet require_YUI_JS -ajaxhelper 0 "dom/dom-min.js"
      ::xowiki::Includelet require_YUI_JS -ajaxhelper 0 "event/event-min.js"
      ::xowiki::Includelet require_YUI_JS -ajaxhelper 0 "connection/connection-min.js"
      ::xo::Page requireJS  "/resources/xowiki/yui-form-field-validate.js"
      set package_url [[[my object] package_id] package_url]
      ::xo::Page requireJS  "YAHOO.xo_form_field_validate.add('[my id]','$package_url');"
    }

    set booleanAtts [my booleanAttributes required readonly disabled multiple \
                         formnovalidate autofocus]
    ::html::input [my get_attributes type size maxlength id name value pattern \
                   placeholder {CSSclass class} {*}$booleanAtts] {}
    my resetBooleanAttributes $booleanAtts


    #
    # Disabled fieds are not returned by the browsers. For some
    # fields, we require to be sent. therefore we include in these
    # cases the value in an additional hidden field. Maybe we should
    # change in the future the "name" of the disabled entry to keep
    # some hypothetical html-checker quiet.
    #
    if {[my exists disabled] && [my exists transmit_field_always]} {
      ::html::input [list type hidden name [my name] value [my set value]] {}
    }
    my set __rendered 1
  } 

  FormField instproc render_item {} {
    ::html::div -class [my form_item_wrapper_CSSclass] {
      if {[my error_msg] ne ""} {
        set CSSclass form-label-error
      } else {
        set CSSclass form-label
      }
      ::html::div -class $CSSclass {
        ::html::label -for [my id] {
          ::html::t [my label]
        }
        if {[my required] && [my mode] eq "edit"} {
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
    if {[my error_msg] ne "" && ![my exists error_reported]} {
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
      html::div -class [my form_help_text_CSSclass] {
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

  FormField instproc value_if_nothing_is_returned_from_form {default} {
    return $default
  }

  FormField instproc pretty_value {v} {
    #my log "mapping $v"
    return [string map [list & "&amp;" < "&lt;" > "&gt;" \" "&quot;" ' "&#39;" @ "&#64;"] $v]
  }

  FormField instproc has_instance_variable {var value} {
    if {[my exists $var] && [my set $var] eq $value} {return 1}
    return 0
  }
  FormField instproc convert_to_internal {} {
    # to be overloaded
  }
  FormField instproc convert_to_external {value} {
    # to be overloaded
    return $value
  }

  FormField instproc answer_check=eq {} {
    my instvar value
    set arg1 [lindex [my correct_when] 1]
    return [expr {$value eq $arg1}]
  }
  FormField instproc answer_check=gt {} {
    my instvar value
    set arg1 [lindex [my correct_when] 1]
    return [expr {$value > $arg1}]
  }
  FormField instproc answer_check=ge {} {
    my instvar value
    set arg1 [lindex [my correct_when] 1]
    return [expr {$value >= $arg1}]
  }
  FormField instproc answer_check=lt {} {
    my instvar value
    set arg1 [lindex [my correct_when] 1]
    return [expr {$value < $arg1}]
  }
  FormField instproc answer_check=le {} {
    my instvar value
    set arg1 [lindex [my correct_when] 1]
    return [expr {$value <= $arg1}]
  }
  FormField instproc answer_check=btwn {} {
    my instvar value
    set arg1 [lindex [my correct_when] 1]
    set arg2 [lindex [my correct_when] 2]
    return [expr {$value >= $arg1 && $value <= $arg2}]
  }
  FormField instproc answer_check=in {} {
    my instvar value
    set values [lrange [my correct_when] 1 end]
    return [expr {$value in $values}]
  }
  FormField instproc answer_check=match {} {
    return [string match [lindex [my correct_when] 1] [my value]]
  }
  FormField instproc answer_check=answer_words {} {
    set value [regsub -all { +} [my value] " "]
    if {[string match "*lower*" [lindex [my correct_when] 1]]} {
      set value [string tolower $value]
    }
    return [expr {$value eq [my answer]}]
  }

  FormField instproc answer_is_correct {} {
    #my msg "[my name] ([my info class]): value=[my value], answer=[expr {[my exists answer]?[my set answer]:{NONE}}]"
    if {[my exists correct_when]} {
      set op [lindex [my correct_when] 0]
      if {[my procsearch answer_check=$op] ne ""} {
        set r [my answer_check=$op]
        if {$r == 0} {return -1} {return 1}
      } else {
        error "invalid operator '$op'"
      }
    } elseif {![my exists answer]} {
      return 0
    } elseif {[my value] ne [my answer]} {
      #my msg "v='[my value]' NE a='[my answer]'"
      return -1
    } else {
      return 1
    }
  }

  FormField instproc set_is_repeat_template {is_template} {
    # my msg "[my name] set is_repeat_template $is_template"
    if {$is_template} {
      my set is_repeat_template true
    } else {
      my unset -nocomplain is_repeat_template
    }
  }

  FormField instproc field_value {v} {
    if {[my exists show_raw_value]} {
      return $v
    } else {
      return [my pretty_value $v]
    }
  }

  FormField instproc pretty_image {-parent_id:required entry_name} {
    if {$entry_name eq ""} return
    if {[my set value] eq ""} return
    my instvar object value
    
    array set "" [$object item_ref -default_lang [$object lang] -parent_id $parent_id $entry_name]

    set label [my label] ;# the label is used for alt und title
    if {$label eq $(stripped_name)} {
      # The label is apparently the default. For Photo.form instances,
      # this is always "image". In such cases, use the title of the
      # parent object as label.
      set label [[my object] title]
    }
    
    set l [::xowiki::Link create new -destroy_on_cleanup \
               -page $object -type "image" -lang $(prefix) \
               [list -stripped_name $(stripped_name)] [list -label $label] \
               -parent_id $(parent_id) -item_id $(item_id)]

    if {[my istype file]} {
      set revision_id [my get_from_value $value revision_id]
      if {$revision_id ne ""} {
        $l revision_id $revision_id
      }
    }

    foreach option {
      href cssclass
      float width height 
      padding padding-right padding-left padding-top padding-bottom
      margin margin-left margin-right margin-top margin-bottom
      border border-width position top botton left right
      geometry
    } {
      if {[my exists $option]} {$l set $option [my set $option]}
    }
    set html [$l render]
    return $html
  }

  ###########################################################
  #
  # helper method for extending slots: 
  # either, we make a meta class for form-fields, or this should 
  # should go into xotcl-core
  #
  ###########################################################

  ::Serializer exportMethods {
    ::xotcl::Class instproc extend_slot_default 
  }
  Class instproc extend_slot_default {name value} {
    # Search for the slot. If the slot exists, extend it's default
    # value with the new value
    foreach c [my info heritage] {
      if {[info command ${c}::slot::$name] ne ""} {
        set value [concat $value [${c}::slot::$name default]]
        break
      }
    }
    # create a mirroring slot with the maybe extended default
    my slots [list Attribute create $name -default $value]
  }


  ###########################################################
  #
  # ::xowiki::formfield::submit_button
  #
  ###########################################################

  Class create submit_button -superclass FormField 
  submit_button  instproc initialize {} {
    my set type submit
    my set value [::xo::localize [_ xowiki.Form-submit_button]]
  }
  submit_button instproc render_input {} {
    # don't disable submit buttons
    if {[my type] eq "submit"} {my unset -nocomplain disabled}
    ::html::button [my get_attributes name type {form_button_CSSclass class} title disabled] {
      ::html::t [my set value]
    }
    #::html::input [my get_attributes name type {form_button_CSSclass class} value title disabled] {}
    my render_localizer
  }

  ###########################################################
  #
  # ::xowiki::formfield::file
  #
  ###########################################################

  Class create file -superclass FormField \
      -extend_slot_default validator virus \
      -parameter {
        {size 40}
        {viruscheck true}
        {sticky false}
        link_label
      }
  file instproc check=virus {value} {
    if {[my viruscheck] && $value ne "" && [::xowiki::virus check [my set tmpfile]]} {
      #util_user_message -message "uploaded file contains a virus; upload rejected"
      return 0
    }
    return 1
  }
  file instproc tmpfile {value}      {my set [self proc] $value}
  file instproc content-type {value} {my set [self proc] $value}
  file instproc initialize {} {
    my type file
    my set widget_type file(file)
    next
  }
  file instproc entry_info {value} {
    return [list name file:[my name] parent_id [[my object] item_id]]
  }
  file instproc get_from_value {value attribute {raw ""}} {
    #
    # The value of of a form entry might be:
    # - an atomic list element
    # - a list with attribute value pairs
    #
    # This function tries to obtain the queried attribute from the
    # attribute value pair notation. If this fails, it returns a
    # default value.
    #
    set valueLength [llength $value]
    if {$valueLength > 1 && $valueLength %2 == 0} {
      array set "" $value
      if {[info exists ($attribute)]} {
        return $($attribute)
      }
    }
    return [lindex $raw 0]
  }

  file instproc no_value_provided {} {
    expr {[my set value] eq ""}
  }

  file instproc get_old_value {} {
    return [[my object] form_parameter __old_value_[my name] ""]
  }

  file instproc value {args} {
    if {[llength $args] == 0} {
      if {[my no_value_provided]} {
        return [my get_old_value]
      }
      return [my set value]
    } 
    return [next]
  }

  file instproc convert_to_internal {} {
    my instvar value

    if {[my no_value_provided]} {
      [my object] set_property -new 1 [my name] [my get_old_value]
      return
    }
    #my msg "[my name]: got value '$value'"
    regsub -all {\\+} $value {/} value  ;# fix IE upload path
    set value [::file tail $value]
    [my object] set_property -new 1 [my name] $value

    set package_id [[my object] package_id]
    array set entry_info [my entry_info $value]

    set content_type [my set content-type]
    if {$content_type eq "application/octetstream" 
        || $content_type eq "application/force-download"
      } {
      set content_type [::xowiki::guesstype $value]
    }
    #my msg "mime_type of $entry_info(name) = [::xowiki::guesstype $value] // [my set content-type] ==> $content_type"
    set file_object [$package_id get_page_from_name -name $entry_info(name) -parent_id $entry_info(parent_id)]
    if {$file_object ne ""} {
      # file entry exists already, create a new revision
      #my msg "new revision (value $value)"
      $file_object set import_file [my set tmpfile]
      $file_object set mime_type $content_type
      $file_object set title $value
      $file_object save
    } else {
      # create a new file 
      #my msg "new file"
      set file_object [::xowiki::File new -destroy_on_cleanup \
                           -title $value \
                           -name $entry_info(name) \
                           -parent_id $entry_info(parent_id) \
                           -mime_type $content_type \
                           -package_id [[my object] package_id] \
                           -creation_user [::xo::cc user_id] ]
      $file_object set import_file [my set tmpfile]
      $file_object save_new
    }
    #
    # Update the value with the attribute value pair list containing
    # the revision_id. TODO: clear revision_id on export.
    #
    set newValue [list name $value revision_id [$file_object revision_id]]
    [my object] set_property -new 1 [my name] $newValue
    my set value $newValue
  }

  file instproc label_or_value {v} {
    if {[my exists link_label]} {
      return [my localize [my link_label]]
    }
    return $v
  }

  file instproc pretty_value {v} {
    if {$v ne ""} {
      my instvar object
      array set "" [my entry_info $v]
      array set "" [$object item_ref -default_lang [[my object] lang] -parent_id $(parent_id) $(name)]
      #my msg "pretty value name '$(stripped_name)'"
      set l [::xowiki::Link create new -destroy_on_cleanup \
                 -page $object -type "file" -lang $(prefix) \
                 [list -stripped_name $(stripped_name)] [list -label [my label]] \
                 [list -extra_query_parameter [list [list filename [my get_from_value $v name $v]]]] \
                 -parent_id $(parent_id) -item_id $(item_id)]
      return [$l render]
    }
  }

  file instproc render_input {} {

    my instvar value
    set package_id [[my object] package_id]

    array set entry_info [my entry_info $value]
    set fn [my get_from_value $value name $value]
    #my msg "[my name]: [list my get_from_value <$value> name] => '$fn'"
    set href [$package_id pretty_link -download 1 -parent_id $entry_info(parent_id) $entry_info(name)]

    if {![my istype image]} {
      append href ?filename=[ns_urlencode $fn]
      set revision_id [my get_from_value $value revision_id ""]
      if {$revision_id ne ""  && [string is integer $revision_id]} {
        append href &revision_id=$revision_id
      }
    }
    
    #
    # The HTML5 handling of "required" would force us to upload in
    # every form the file again. To implement the sticky option, we
    # set temporarily the "required" attribute to false
    #
    if {[my exists required]} {
      set reset_required 1
      my set required false
    }
    next

    if {[info exists reset_required]} {
      my set required true
    }

    ::html::t " "
    set id __old_value_[my name]
    ::html::input -type hidden -name $id -id $id -value $value
    ::html::span -class file-control -id __a$id {
      ::html::a -href $href {::html::t [my label_or_value $fn] }
      
      # Show the clear button just when
      # - there is something to clear, and
      # - the formfield is not disabled, and
      # - the form-field is not sticky (default)
      
      set disabled [expr {[my exists disabled] && [my disabled] != "false"}]
      if {$value ne "" && !$disabled && ![my sticky] } {
        ::html::input -type button -value [_ xowiki.clear] \
            -onClick "document.getElementById('$id').value = ''; document.getElementById('__a$id').style.display = 'none';"
      }
    }
  }

  ###########################################################
  #
  # ::xowiki::formfield::import_archive
  #
  ###########################################################

  Class create import_archive -superclass file -parameter {
    {cleanup false}
  }
  import_archive instproc initialize {} {
    next
    if {[my help_text] eq ""} {my help_text "#xowiki.formfield-import_archive-help_text#"}
  }
  import_archive instproc pretty_value {v} {
    my instvar object
    set package_id [$object package_id]
    set parent_id  [$object parent_id]
    if {$v eq ""} {return ""}
    array set "" [my entry_info $v]
    set fn [my get_from_value $v name $v]
    #
    # Get the file object of the imported file to obtain is full name and path
    #
    set file_id [$package_id lookup -parent_id [$object item_id] -name $(name)]
    ::xo::db::CrClass get_instance_from_db -item_id $file_id
    set full_file_name [$file_id full_file_name]
    #
    # Call the archiver to unpack and handle the archive
    #
    set f [::xowiki::ArchiveFile new -file $full_file_name -name $fn -parent_id $parent_id]
    if {[$f unpack]} {
      #
      # So, all the hard work is done. We take a hard measure here to
      # cleanup the entry in case everything was imported
      # successful. Note that setting "cleanup" without thought might
      # lead to maybe unexpected deletions of the form-page
      #
      if {[my cleanup]} {
        set return_url [$package_id query_parameter "return_url" [$parent_id pretty_link]]
        $package_id returnredirect [export_vars -base [$object pretty_link] [list {m delete} return_url]]
      }
    }
  }

  ###########################################################
  #
  # ::xowiki::formfield::image
  #
  ###########################################################

  Class create image -superclass file -parameter {
    href cssclass
    float width height 
    padding padding-right padding-left padding-top padding-bottom
    margin margin-left margin-right margin-top margin-bottom
    border border-width position top botton left right
  }
  image instproc pretty_value {v} {
    array set "" [my entry_info $v]

    return [my pretty_image -parent_id $(parent_id) $(name)]
  }

  ###########################################################
  #
  # ::xowiki::formfield::hidden
  #
  ###########################################################

  Class create hidden -superclass FormField
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

  Class create omit -superclass FormField
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
  
  Class create inform -superclass FormField
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

  Class create text -superclass FormField -parameter {
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
  # ::xowiki::formfield::color
  #
  ###########################################################

  Class create color -superclass text 
  color instproc initialize {} {
    next
    my type color
  }

  ###########################################################
  #
  # ::xowiki::formfield::datetime
  #
  ###########################################################

  Class create datetime -superclass text 
  datetime instproc initialize {} {
    next
    my type datetime
  }

  ###########################################################
  #
  # ::xowiki::formfield::h5date
  #
  #  HTML 5 input type "date", to avoid naming conflict with
  #  pre-existing formfield of type "date"
  ###########################################################
  Class create h5date -superclass text 
  h5date instproc initialize {} {
    next
    my type date
  }

  ###########################################################
  #
  # ::xowiki::formfield::h5time
  #
  #  HTML 5 input type "time", to avoid naming conflict with
  #  pre-existing formfield of type "time"
  ###########################################################
  Class create h5time -superclass text 
  h5time instproc initialize {} {
    next
    my type time
  }


  ###########################################################
  #
  # ::xowiki::formfield::datetime-local
  #
  ###########################################################

  Class create datetime-local -superclass text 
  datetime-local instproc initialize {} {
    next
    my type datetime-local
  }

  ###########################################################
  #
  # ::xowiki::formfield::time
  #
  ###########################################################

  Class create time -superclass text 
  time instproc initialize {} {
    next
    my type time
  }

  ###########################################################
  #
  # ::xowiki::formfield::week
  #
  ###########################################################

  Class create week -superclass text 
  week instproc initialize {} {
    next
    my type datetime
  }

  ###########################################################
  #
  # ::xowiki::formfield::email
  #
  ###########################################################

  Class create email -superclass text 
  email instproc initialize {} {
    next
    my type email
  }

  ###########################################################
  #
  # ::xowiki::formfield::search
  #
  ###########################################################

  Class create search -superclass text 
  search instproc initialize {} {
    next
    my type search
  }
  ###########################################################
  #
  # ::xowiki::formfield::tel
  #
  ###########################################################

  Class create tel -superclass text 
  tel instproc initialize {} {
    next
    my type tel
  }

  ###########################################################
  #
  # ::xowiki::formfield::number
  #
  ###########################################################

  Class create number -superclass FormField -parameter {
    min max step value
  }
  number instproc initialize {} {
    my type number
    my set widget_type text
  }
  number instproc render_input {} {
    ::html::input [my get_attributes type id name value disabled {CSSclass class} min max step value \
                       autofocus formnovalidate multiple pattern placeholder readonly required] {}
  }

  ###########################################################
  #
  # ::xowiki::formfield::range
  #
  ###########################################################

  Class create range -superclass FormField -parameter {
    min max step value
  }
  range instproc initialize {} {
    my type range
    my set widget_type text
  }
  range instproc render_input {} {
    ::html::input [my get_attributes type id name value disabled {CSSclass class} min max step value \
                       autofocus formnovalidate multiple pattern placeholder readonly required] {}
  }


  ###########################################################
  #
  # ::xowiki::formfield::password
  #
  ###########################################################

  Class create password -superclass text 
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

  Class create numeric -superclass text -parameter {
    {format %.2f}
  } -extend_slot_default validator numeric 
  numeric instproc initialize {} {
    next
    my set widget_type numeric
    # check, if we we have an integer format
    my set is_integer [regexp {%[0-9.]*d} [my format]]
  }
  numeric instproc convert_to_external value {
    if {$value ne ""} {
      if { [catch "lc_numeric $value [my format] [my locale]" result] } {
        util_user_message -message "[my label]: $result (locale=[my locale])"
        #my msg [list lc_numeric $value [my format] [my locale]]
        set converted_value $value
        if {[catch {scan $value [my format] converted_value}]} {
          return $value
        } else {
          return $converted_value
        }
      }
      return $result
    }
    return $value
  }
  numeric instproc convert_to_internal {} {
    if {[my value] ne ""} {
      set value [lc_parse_number [my value] [my locale] [my set is_integer]]
      [my object] set_property -new 1 [my name] [expr {$value}]
      return
    }
  }
  numeric instproc check=numeric {value} {
    return [expr {[catch {lc_parse_number $value [my locale] [my set is_integer]}] == 0}]
  }
  numeric instproc pretty_value value {
    return [my convert_to_external $value]
  }
  numeric instproc answer_check=eq {} {
    # use numeric equality
    return [expr {[my value] == [lindex [my correct_when] 1]}]
  }

  ###########################################################
  #
  # ::xowiki::formfield::user_id
  #
  ###########################################################

  Class create user_id -superclass numeric -parameter {
    {format %d}
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
  # ::xowiki::formfield::author
  #
  ###########################################################

  Class create author -superclass user_id -parameter {
    {photo_size 54}
    {with_photo true}
    {with_user_link false}
    {label #xowiki.formfield-author#}
  }
  author instproc pretty_value {v} {
    if {$v ne ""} {
      my instvar object
      acs_user::get -user_id $v -array user
      if {[my with_photo]} {
        set portrait_id [acs_user::get_portrait_id -user_id $v]
        if {$portrait_id == 0} {
          package require md5
          set md5 [string tolower [md5::Hex [md5::md5 -- $user(email)]]]
          set src http://www.gravatar.com/avatar/$md5?size=[my photo_size]&d=mm
        } else {
          set src "/shared/portrait-bits.tcl?user_id=$v"
        }
        set photo "<img width='[my photo_size]' class='photo' src='$src'>"
        set photo_class "photo"
      } else {
        set photo ""
        set photo_class ""
      }
      set date_field [::xowiki::FormPage get_table_form_fields \
                          -base_item $object \
                          -field_names _last_modified \
                          -form_constraints ""]
      set date [$date_field pretty_value [$object property _last_modified]]

      if {[my with_user_link]} {
        set user_link_begin "<a href='/shared/community-member?user_id=$v'>"
        set user_link_end "</a>"
      } else {
        set user_link_begin ""
        set user_link_end ""
      }

      return [subst {
        <div class="cite $photo_class">$photo
        <p class="author">$user_link_begin$user(first_names) $user(last_name)$user_link_end</p>
        <p class="date">$date</p>
        </div>
      }]
    }
    return ""
  }

  ###########################################################
  #
  # ::xowiki::formfield::party_id
  #
  ###########################################################

  Class create party_id -superclass user_id \
      -extend_slot_default validator party_id_check
  party_id instproc check=party_id_check {value} {
    if {$value eq ""} {return 1}
    return [::xo::dc 0or1row check_party {select 1 from parties where party_id = :value}]
  }

  ###########################################################
  #
  # ::xowiki::formfield::url
  #
  ###########################################################

  Class create url -superclass text \
      -extend_slot_default validator safe_url \
      -parameter {
        {link_label}
      }
  url instproc check=safe_url {value} {
    if {$value eq ""} {return 1}
    set regexp {^(https|http|ftp)://([a-zA-Z0-9_\-\.]+(:[0-9]+)?)/[a-zA-Z0-9_.%/#?=&~-]+$}
    if {[regexp -nocase $regexp $value]} {return 1}
    return 0
  }
  url instproc initialize {} {
    next
    my type url
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

  Class create detail_link -superclass url -parameter {
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

  Class create textarea -superclass FormField -parameter {
    {rows 2}
    {cols 80}
    {spell false}
  }
  textarea instproc initialize {} {
    my set widget_type text(textarea)
    my set booleanHTMLAttributes {required readonly disabled formnovalidate}
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
    set booleanAtts [my booleanAttributes {*}[my set booleanHTMLAttributes]]
    ::html::textarea [my get_attributes id name cols rows style wrap placeholder {CSSclass class} \
                          {*}$booleanAtts] {
      ::html::t [my value]
    }
    my resetBooleanAttributes $booleanAtts
  }

  ###########################################################
  #
  # ::xowiki::formfield::code_listing
  #
  ###########################################################

  Class create code_listing -superclass textarea -parameter {
    {rows 20}
    {cols 80}
  }
  code_listing instproc pretty_value {v} {
    [my object] do_substitutions 0
    if {[info commands ::apidoc::tclcode_to_html] ne ""} {
      set html [::apidoc::tclcode_to_html [my value]]
      regsub -all "\n?\r</FONT></EM>" $html </FONT></EM> html
      return "<pre class='code'>$html</pre>"
    } else {
      return "<pre class='code'>[string map [list & {&amp;} < {&lt;} > {&gt;}]  [my value]]</pre>"
    }
  }

  ###########################################################
  #
  # ::xowiki::formfield::richtext
  #
  ###########################################################

  Class create richtext -superclass textarea \
      -extend_slot_default validator safe_html \
      -parameter {
        plugins 
        folder_id
        script_dir
        {displayMode standard}
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
    #my display_field false
    switch -- [my set displayMode] {
      inplace -
      inline -
      standard {}
      default {error "value '[my set displayMode]' invalid: valid entries for displayMode are inplace, inline or standard (default)"}
    }
    #
    # Don't set HTML5 attribute required, since this does not match
    # well with Richtext Editors (at least ckeditor4 has problems,
    # other probably as well).
    #
    my set booleanHTMLAttributes {readonly disabled formnovalidate}
    next
    if {![my exists editor]} {
      my set editor [parameter::get_global_value -package_key xowiki \
                         -parameter PreferredRichtextEditor -default xinha]
      #my msg "setting default of [my name] to [my set editor]"
    }
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
        [my object] references clear
        ::html::t -disableOutputEscaping [[my object] substitute_markup [my value]]
      } else {
        ::html::t -disableOutputEscaping [my value]
      }
    }
    ::html::div
  }

  richtext instproc check=safe_html {value} {
    # don't check if the user has sufficient permissions on the package
    if {[::xo::cc permission \
             -object_id [::xo::cc package_id] \
             -privilege swa \
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
    if {[my wiki]} {
      return [[my object] substitute_markup $v]
    } else {
      return [string map [list @ "&#64;"] $v]
    }
  }

  ###########################################################
  #
  # ::xowiki::formfield::richtext::ckeditor
  #
  #    mode: wysiwyg, source
  #    skin: kama, v2, office2003
  #    extraPlugins: tcl-list, is converted to comma list for js
  #
  ###########################################################
  Class create richtext::ckeditor -superclass richtext -parameter {
    {editor ckeditor}
    {mode wysiwyg}
    {skin kama}
    {toolbar Full}
    {CSSclass xowiki-ckeditor}
    {uiColor ""}
    {CSSclass xowiki-ckeditor}
    {customConfig "../ck_config.js"}
    {callback "/* callback code */"}
    {destroy_callback "/* callback code */"}
    {extraPlugins ""}
    {templatesFiles ""}
    {templates ""}
    {contentsCss /resources/xowiki/ck_contents.css}
    {imageSelectorDialog /xowiki/ckeditor-images/}
  }
  richtext::ckeditor set editor_mixin 1
  richtext::ckeditor instproc initialize {} {
    switch -- [my set displayMode] {
      inplace { my append help_text " #xowiki.ckeip_help#" }
      inline { error "inline is not supported for ckeditor v3"}
    }
    next
    my set widget_type richtext
    # Mangle the id to make it compatible with jquery; most probably
    # not optimal and just a temporary solution
    regsub -all {[.:]} [my id] "" id
    my id $id
  }

  richtext::ckeditor instproc js_image_helper {} {
    ::xo::Page requireJS {
      function xowiki_image_callback(editor) {
        $(editor.element.$.form).submit(function(e) {
          calc_image_tags_to_wiki_image_links(this);
        });
        editor.setData(calc_wiki_image_links_to_image_tags(editor.getData()));
      }
      
      function calc_image_tags_to_wiki_image_links (form) {
        var calc = function() {
          var wiki_link = $(this).attr('alt');
          $(this).replaceWith('[['+wiki_link+']]');
        }
        $(form).find('iframe').each(function() {
          $(this).contents().find('img[type="wikilink"]').each(calc);
        });
        
        $(form).find('textarea.ckeip').each(function() {
          var contents = $('<div>'+this.value+'</div>');
          contents.find('img[type="wikilink"]').each(calc);
          this.value = contents.html();
        });
        return true;
      }
      
      function calc_wiki_image_links_to_image_tags (data) {
        var pathname = window.location.pathname;
        pathname = pathname.substr(pathname.lastIndexOf("/")+1,pathname.length)
        pathname = pathname.replace(/:/ig,"%3a");
        var regex_wikilink = new RegExp('(\\[\\[.SELF./image:)(.*?)(\\]\\])', 'g');
        data = data.replace(regex_wikilink,'<img src="'+pathname+'/file:$2?m=download"  alt=".SELF./image:$2" type="wikilink"  />');
        return data
      }
    }
  }

  richtext::ckeditor instproc pathNames {fileNames} {
    set result [list]
    foreach fn $fileNames {
      if {[regexp {^[./]} $fn]} {
        append result $fn
      } else {
        append result "/resources/xowiki/$fn"
      }
    }
    return $result
  }

  richtext::ckeditor instproc render_input {} {
    set disabled [expr {[my exists disabled] && [my disabled] != "false"}]
    if {![my istype ::xowiki::formfield::richtext] || $disabled } {
      my render_richtext_as_div
    } else {
      ::xo::Page requireJS "/resources/xowiki/jquery/jquery.min.js"
      ::xo::Page requireJS "/resources/xowiki/ckeditor/ckeditor_source.js"
      #::xo::Page requireJS "/resources/xowiki/ckeditor/ckeditor.js"
      ::xo::Page requireJS "/resources/xowiki/ckeditor/adapters/jquery.js"
      ::xo::Page requireJS "/resources/xowiki/jquery-ui-1.8.17.custom.min.js"
      ::xo::Page requireCSS "/resources/xowiki/jquery-ui-1.8.17.custom.css"

      # In contrary to the doc, ckeditor names instances after the id,
      # not the name. 
      set id [my id]
      set name [my name] 
      set package_id [[my object] package_id]
      #my extraPlugins {timestamp xowikiimage}

      if {"xowikiimage" in [my extraPlugins]} {
        my js_image_helper
        set ready_callback {xowiki_image_callback(e.editor);}
      } else {
        set ready_callback "/*none*/;"
      }
      
      set options [subst {
        toolbar : '[my toolbar]',
        uiColor: '[my uiColor]',
        language: '[lang::conn::language]',
        skin: '[my skin]',
        startupMode: '[my mode]',
        parent_id: '[[my object] item_id]',
        package_url: '[$package_id package_url]',
        extraPlugins: '[join [my extraPlugins] ,]',
        contentsCss: '[my contentsCss]',
        imageSelectorDialog: '[my imageSelectorDialog]',
        ready_callback: '$ready_callback',
        customConfig: '[my customConfig]'
      }]
      if {[my templatesFiles] ne ""} {
        append options "  , templates_files: \['[join [my pathNames [my templatesFiles]] ',' ]' \]\n"
      }
      if {[my templates] ne ""} {
        append options "  , templates: '[my templates]'\n"
      }

      #set parent [[[my object] package_id] get_page_from_item_or_revision_id [[my object] parent_id]];# ???

      if {[my set displayMode] eq "inplace"} {
        if {[my value] eq ""} {my value "&nbsp;"}
        my render_richtext_as_div
        if {[my inline]} {
          set wrapper_class ""
        } else {
          set wrapper_class "form-item-wrapper"
          my callback {$(this.element.$).closest('.form-widget').css('clear','both').css('display', 'block');}
          my destroy_callback {$(this).closest('.form-widget').css('clear','none');}
        }
        set callback [my callback]
        set destroy_callback [my destroy_callback]

        ::xo::Page requireJS "/resources/xowiki/ckeip.js"
        ::xo::Page requireJS [subst -nocommands {
          \$(document).ready(function() {
            \$( '\#$id' ).ckeip(function() { $callback }, {
              name: '$name',
              ckeditor_config: {
                $options,
                destroy_callback: function() { $destroy_callback }
              },
              wrapper_class: '$wrapper_class'
            });
          });
        }]
      } else {
        set callback [my callback]
        ::xo::Page requireJS [subst -nocommands {
          \$(document).ready(function() {
            \$( '#$id' ).ckeditor(function() { $callback }, {
              $options
            });
            CKEDITOR.instances['$id'].on('instanceReady',function(e) {$ready_callback});
          });
        }]
        next
      }
    }
  }


  ###########################################################
  #
  # ::xowiki::formfield::richtext::ckeditor4
  #
  #    mode: wysiwyg, source
  #    skin: moono, kama
  #    extraPlugins: tcl-list, is converted to comma list for js
  #
  ###########################################################
  Class create richtext::ckeditor4 -superclass richtext -parameter {
    {editor ckeditor4}
    {mode wysiwyg}
    {skin bootstrapck}
    {toolbar Full}
    {CSSclass xowiki-ckeditor}
    {uiColor ""}
    {CSSclass xowiki-ckeditor}
    {customConfig "config.js"}
    {callback "/* callback code */"}
    {destroy_callback "/* callback code */"}
    {submit_callback ""}
    {extraPlugins "xowikiimage"}
    {templatesFiles ""}
    {templates ""}
    {contentsCss /resources/xowiki/ck_contents.css}
    {imageSelectorDialog /xowiki/ckeditor-images/}
    {additionalConfigOptions ""}
  }
  richtext::ckeditor4 set editor_mixin 1
  richtext::ckeditor4 instproc initialize {} {
    switch -- [my set displayMode] {
      inplace { my append help_text " #xowiki.ckeip_help#" }
    }
    next
    my set widget_type richtext
    # Mangle the id to make it compatible with jquery; most probably
    # not optimal and just a temporary solution
    regsub -all {[.:-]} [my id] "" id
    my id $id
  }

  richtext::ckeditor4 instproc js_image_helper {} {
    ::xo::Page requireJS {
      function xowiki_image_callback(editor) {
        if (typeof editor != "undefined") {
          $(editor.element.$.form).submit(function(e) {
            calc_image_tags_to_wiki_image_links(this);
          });
          editor.setData(calc_wiki_image_links_to_image_tags(editor.getData()));
        }
      }
      
      function calc_image_tags_to_wiki_image_links (form) {
        var calc = function() {
          var wiki_link = $(this).attr('alt');
          $(this).replaceWith('[['+wiki_link+']]');
        }
        $(form).find('iframe').each(function() {
          $(this).contents().find('img[type="wikilink"]').each(calc);
        });
        
        $(form).find('textarea.ckeip').each(function() {
          var contents = $('<div>'+this.value+'</div>');
          contents.find('img[type="wikilink"]').each(calc);
          this.value = contents.html();
        });
        return true;
      }
      
      function calc_image_tags_to_wiki_image_links_inline (e) {
        var data = $('<div>'+CKEDITOR.instances[e].getData()+'</div>');
        data.find('img[type="wikilink"]').each( function() {
          var wiki_link = $(this).attr('alt');
          $(this).replaceWith('[['+wiki_link+']]');
        });
        CKEDITOR.instances[e].setData(data.html());
        CKEDITOR.instances[e].updateElement();
      }
      
      function calc_wiki_image_links_to_image_tags (data) {
        var pathname = window.location.pathname;
        pathname = pathname.substr(pathname.lastIndexOf("/")+1,pathname.length)
        console.log('pathname' + pathname);
        pathname = pathname.replace(/:/ig,"%3a");
        var regex_wikilink = new RegExp('(\\[\\[.SELF./image:)(.*?)(\\]\\])', 'g');
        data = data.replace(regex_wikilink,'<img src="'+pathname+'/file:$2?m=download"  alt=".SELF./image:$2" type="wikilink"  />');
        return data
      }
    }
  }
  
  richtext::ckeditor4 instproc pathNames {fileNames} {
    set result [list]
    foreach fn $fileNames {
      if {[regexp {^[./]} $fn]} {
        append result $fn
      } else {
        append result "/resources/xowiki/$fn"
      }
    }
    return $result
  }
  
  richtext::ckeditor4 instproc render_input {} {
    set disabled [expr {[my exists disabled] && [my disabled] != "false"}]
    set is_repeat_template [expr {[my exists is_repeat_template] && [my set is_repeat_template] == "true"}]
    # my msg "[my id] [my name] - $is_repeat_template"
    
    # if value is empty, we need something to be clickable for display mode inplace
    if {[my value] eq "" && [my set displayMode] eq "inplace"} {
      my value "&nbsp;"
    }
    
    if {![my istype ::xowiki::formfield::richtext] || ($disabled && !$is_repeat_template)} {
      my render_richtext_as_div
    } else {
      ::xo::Page requireJS "/resources/xowiki/jquery/jquery.min.js"
      ::xo::Page requireJS "/resources/xowiki/ckeditor4/ckeditor.js"
      ::xo::Page requireJS "/resources/xowiki/ckeditor4/adapters/jquery.js"
      #::xo::Page requireJS "/resources/xowiki/jquery-ui-1.8.17.custom.min.js"
      #::xo::Page requireCSS "/resources/xowiki/jquery-ui-1.8.17.custom.css"

      # In contrary to the doc, ckeditor4 names instances after the id,
      # not the name. 
      set id [my id]
      set name [my name] 
      set package_id [[my object] package_id]
      if {[my set displayMode] eq "inline"} {my lappend extraPlugins sourcedialog}
      
      if {"xowikiimage" in [my extraPlugins]} {
        my js_image_helper
        set ready_callback {xowiki_image_callback(e.editor);}
      } else {
        set ready_callback "/*none*/;"
        set submit_callback "/*none*/;"
      }
      
      set options [subst {
        [my set additionalConfigOptions]
        toolbar : '[my toolbar]',
        uiColor: '[my uiColor]',
        language: '[lang::conn::language]',
        skin: '[my skin]',
        startupMode: '[my mode]',
        parent_id: '[[my object] item_id]',
        package_url: '[$package_id package_url]',
        extraPlugins: '[join [my extraPlugins] ,]',
        contentsCss: '[my contentsCss]',
        imageSelectorDialog: '[my imageSelectorDialog]?parent_id=[[my object] item_id]',
        ready_callback: '$ready_callback',
        customConfig: '[my customConfig]',
        allowedContent: true,
        textarea_id: '[my set id]'
      }]
      if {[my templatesFiles] ne ""} {
        append options "  , templates_files: \['[join [my pathNames [my templatesFiles]] ',' ]' \]\n"
      }
      if {[my templates] ne ""} {
        append options "  , templates: '[my templates]'\n"
      }
      
      #set parent [[[my object] package_id] get_page_from_item_or_revision_id [[my object] parent_id]];# ???
      
      if {[my set displayMode] eq "inplace"} {
        if {!$is_repeat_template} {
          set callback [my callback]
          set destroy_callback [my destroy_callback]
          
          my lappend CSSclass ckeip
          ::xo::Page requireJS "/resources/xowiki/ckeip.js"
          
          ::xo::Page requireJS [subst -nocommands {
            function load_$id () {
              \$( '\#$id' ).ckeip(function() { $callback }, {
                name: '$name',
                ckeditor_config: {
                  $options,
                  destroy_callback: function() { $destroy_callback }
                }
              });
            }
            \$(document).ready(function() {
                if (\$('#$id').parents('.repeatable').length != 0) {
                    if (\$('#$id').is(':visible')) {
                        load_$id ();
                    }
                } else {
                    //this is not inside a repeatable container, load normally
                    load_$id ();
                }
            } );
          }]
        }
        my render_richtext_as_div
      } elseif {[my set displayMode] eq "inline"} {
        if {!$is_repeat_template} {
          if {"xowikiimage" in [my extraPlugins]} {
            set ready_callback "xowiki_image_callback(CKEDITOR.instances\['$id'\]);"
            set submit_callback "calc_image_tags_to_wiki_image_links_inline('$id');"
          }

          set submit_callback "$submit_callback [my submit_callback]"
          ::xo::Page requireJS [subst {
            function load_ckinline_$id () {
              CKEDITOR.inline('$id', {
                on: {
                  instanceReady: function(e) {
                    \$(e.editor.element.\$).attr('title', '[my set label]');
                    \$(e.editor.element.\$.form).submit(function(e) {
                      $submit_callback
                    });
                  }
                },
                $options
              });
            }
            \$(document).ready(function() {
              if (\$('#$id').parents('.repeatable').length != 0) {
                if (\$('#$id').is(':visible')) {
                  load_ckinline_$id ();
                }
              } else {
                //this is not inside a repeatable container, load normally
                load_ckinline_$id ();
              }
              $ready_callback
            });
          }]
        }
        next
      } else {
        if {!$is_repeat_template} {
          set callback [my callback]
          ::xo::Page requireJS [subst -nocommands {
            function load_$id () {
              \$( '#$id' ).ckeditor(function() { $callback }, {
                $options
              });
            }
            \$(document).ready(function() {
              load_$id ();
              CKEDITOR.instances['$id'].on('instanceReady',function(e) {$ready_callback});
            });
          }]
        }
        next
      }
    }
  }
  
  ###########################################################
  #
  # ::xowiki::formfield::richtext::wym
  #
  ###########################################################
  Class create richtext::wym -superclass richtext -parameter {
    {editor wym}
    {CSSclass wymeditor}
    width
    height
    {skin silver}
    {plugins "hovertools resizable fullscreen"}
  }
  richtext::wym set editor_mixin 1
  richtext::wym instproc initialize {} {
    next
    my set widget_type richtext
  }
  richtext::wym instproc render_input {} {
    set disabled [expr {[my exists disabled] && [my disabled] != "false"}]
    if {![my istype ::xowiki::formfield::richtext] || $disabled } {
      my render_richtext_as_div
    } else {
      ::xo::Page requireCSS "/resources/xowiki/wymeditor/skins/default/screen.css"
      ::xo::Page requireJS "/resources/xowiki/jquery/jquery.min.js"
      ::xo::Page requireJS  "/resources/xowiki/wymeditor/jquery.wymeditor.pack.js"
      set postinit ""
      foreach plugin {hovertools resizable fullscreen embed} {
        if {$plugin in [my plugins]} {
          switch -- $plugin {
            embed {}
            resizable {
              ::xo::Page requireJS  "/resources/xowiki/jquery/jquery.ui.js"
              ::xo::Page requireJS  "/resources/xowiki/jquery/jquery.ui.resizable.js"
              append postinit "wym.${plugin}();\n"
            }
            default {append postinit "wym.${plugin}();\n"}
          }
          ::xo::Page requireJS  "/resources/xowiki/wymeditor/plugins/$plugin/jquery.wymeditor.$plugin.js"
        }
      }
      regsub -all {[.:]} [my id] {\\\\&} JID
      
      # possible skins are per in the distribution: "default", "sliver", "minimal" and "twopanels"
      set config [list "skin: '[my skin]'"]

      #my msg "wym, h [my exists height] || w [my exists width]"
      if {[my exists height] || [my exists width]} {
        set height_cmd ""
        set width_cmd ""
        if {[my exists height]} {set height_cmd "jQuery(wym._box).find(wym._options.iframeSelector).css('height','[my height]');"}
        if {[my exists width]}  {set width_cmd "wym_box.css('width', '[my width]');"}
        set postInit [subst -nocommand -nobackslash {
          postInit: function(wym) {
            wym_box = jQuery(".wym_box");
            $height_cmd
            $width_cmd
            $postinit
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

  Class create richtext::xinha -superclass richtext -parameter {
    javascript
    {height}
    {style}
    {wiki_p true}
    {slim false}
    {CSSclass xinha}
  }
  richtext::xinha set editor_mixin 1
  richtext::xinha instproc initialize {} {
    switch -- [my set displayMode] {
      inplace { 
        ::xo::Page requireJS  "/resources/xowiki/xinha-inplace.js"
        if {![info exists ::__xinha_inplace_init_done]} {
          template::add_body_handler -event onload -script "xinha.inplace.init();"
          set ::__xinha_inplace_init_done 1 
        }
      }    
      inline { error "inline is not supported for xinha"}
    }

    next
    my set widget_type richtext
    if {![my exists plugins]} {
      my plugins \
          [parameter::get -parameter "XowikiXinhaDefaultPlugins" \
               -default [::xo::parameter get_from_package_key \
                             -package_key "acs-templating" -parameter "XinhaDefaultPlugins"]]
    }
    my set options [my get_attributes editor plugins width height folder_id script_dir javascript wiki_p]
    # for the time being, we can't set the defaults via parameter, 
    # but only manually, since the editor is used as a mixin, the parameter
    # would have precedence over the defaults of subclasses
    if {![my exists slim]} {my set slim false} 
    if {![my exists style]} {my set style "width: 100%;"}
    if {![my exists height]} {my set height 350px}
    if {![my exists wiki_p]} {my set wiki_p 1}
    if {[my set slim]} {
      my lappend options javascript {
        xinha_config.toolbar  = [['popupeditor', 'formatblock', 'bold','italic','createlink','insertimage'], 
                                 ['separator','insertorderedlist','insertunorderedlist','outdent','indent'],
                                 ['separator','killword','removeformat','htmlmode'] 
                                ];
      }
    }
  }

  richtext::xinha instproc render_input {} {
    set disabled [expr {[my exists disabled] && [my disabled] != "false"}]
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
      foreach e {width height folder_id fs_package_id file_types attach_parent_id wiki_p package_id} {
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

      if {[my set displayMode] eq "inplace"} {
        ::html::div [my get_attributes id name {CSSclass class} disabled] {
          set href \#
          set onclick "xinha.inplace.openEditor('[my id]');return false;"
          ::html::a -style "float: right;" -class edit-item-button -href $href -onclick $onclick {
            ::html::t  -disableOutputEscaping &nbsp;
          }
          ::html::div -id "[my id]__CONTENT__" {
            ::html::t -disableOutputEscaping  [my value]
          }
        }
        my set hiddenid [my id]__HIDDEN__
        my set type hidden
        ::html::input [my get_attributes {hiddenid id} name type value] {}
      } else {
        #::html::div [my get_attributes id name cols rows style {CSSclass class} disabled] {}
        next
      }
    }
  }

  ###########################################################
  #
  # ::xowiki::formfield::enumeration
  #
  ###########################################################

  # abstract superclass for select and radio
  Class create enumeration -superclass FormField -parameter {
    {options ""}
    {category_tree}
  }
  enumeration set abstract 1
  enumeration instproc initialize {} {
    if {[my exists category_tree]} {
      my config_from_category_tree [my category_tree]
    }
    next
    # For required enumerations, the implicit default value is the
    # first entry of the options. This is as well the value, which is
    # returned from the browser in such cases.
    if {[my required] && [my set value] eq ""} {
      my set value [lindex [my set options] 0 1]
    }
  }
  enumeration abstract instproc render_input {}

  enumeration instproc get_labels {values} {
    if {[my multiple]} {
      set labels [list]
      foreach v $values {lappend labels [list [my get_entry_label $v] $v]}
      return $labels
    } else {
      return [list [list [my get_entry_label $values] $values]]
    }
  }

  enumeration instproc pretty_value {v} {
    if {[my exists category_label($v)]} {
      return [my set category_label($v)]
    }
    if {[my exists multiple] && [my set multiple]} {
      foreach o [my set options] {
        lassign $o label value
        set labels($value) [my localize $label]
      }
      set values [list]
      foreach i $v {lappend values $labels($i)}
      return [join $values {, }]
    } else {
      foreach o [my set options] {
        lassign $o label value
        if {$value eq $v} {return [my localize $label]}
      }
    }
  }
  enumeration instproc config_from_category_tree {tree_name} {
    # Get the options of a select or radio from the specified
    # category tree.
    #
    # We could config as well from the mapped category tree,
    # and get required and multiple from there....
    #
    # The usage of the label does not seem to be very useful.
    #
    #set tree_id [category_tree::get_id $tree_name [my locale]]

    set package_id [[my object] package_id]
    set tree_ids [::xowiki::Category get_mapped_trees -object_id $package_id -locale [my locale] \
                      -names $tree_name -output tree_id]
    
    # In case there are multiple trees with the same name,
    # take the first one.
    #
    set tree_id [lindex $tree_ids 0]

    if {$tree_id eq ""} {
      my msg "cannot lookup mapped category tree name '$tree_name'"
      return
    }
    set subtree_id ""
    set options [list] 

    foreach category [::xowiki::Category get_category_infos \
                          -subtree_id $subtree_id -tree_id $tree_id] {
      lassign $category category_id category_name deprecated_p level
      set category_name [ad_quotehtml [lang::util::localize $category_name]]
      my set category_label($category_id) $category_name
      if { $level>1 } {
        set category_name "[string repeat {.} [expr {2*$level-4}]]..$category_name"
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

  Class create radio -superclass enumeration -parameter {
    {horizontal false}
    {forced_name}
  }
  radio instproc initialize {} {
    my set widget_type text(radio)
    next
  }
  radio instproc render_input {} {
    set value [my value]
    foreach o [my options] {
      lassign $o label rep
      set atts [my get_attributes disabled {CSSclass class}]
      if {[my exists forced_name]} {set name [my forced_name]} {set name [my name]}
      lappend atts id [my id]:$rep name $name type radio value $rep
      if {$value eq $rep} {lappend atts checked checked}
      ::html::input $atts {}
      html::t "$label  "
      if {![my horizontal]} {html::br}
    }
  }

  ###########################################################
  #
  # ::xowiki::formfield::checkbox
  #
  ###########################################################

  Class create checkbox -superclass enumeration -parameter {
    {horizontal false}
  }
  checkbox instproc initialize {} {
    my set multiple true
    my set widget_type text(checkbox)
    next
  }


  checkbox instproc value_if_nothing_is_returned_from_form {default} {
    # Here we have to distinguish between two cases to:
    # - edit mode: somebody has removed a mark from a check button;
    #   this means: clear the field
    # - view mode: the fields were deactivted (made insensitive);
    #   this means: keep the old value

    #my msg "[my name] disabled=[my exists disabled]"
    if {[my exists disabled]} {return $default} else {return ""}
  }
  checkbox instproc render_input {} {
    # identical to radio, except "checkbox" type and lsearch;
    # maybe we can push this up to enumeration....
    set value [my value]
    foreach o [my options] {
      lassign $o label rep
      set atts [my get_attributes disabled {CSSclass class}]
      lappend atts id [my id]:$rep name [my name] type checkbox value $rep
      if {$rep in $value} {lappend atts checked checked}
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

  Class create select -superclass enumeration -parameter {
    {multiple "false"}
  }

  select instproc initialize {} {
    my set widget_type text(select)
    next
    if {![my exists options]} {my options [list]}
  }

  select instproc render_input {} {
    set atts [my get_attributes id name disabled {CSSclass class}]
    if {[my multiple]} {lappend atts multiple [my multiple]}
    set options [my options]
    if {![my required]} {
      set options [linsert $options 0 [list "--" ""]]
    }
    ::html::select $atts {
      foreach o $options {
        lassign $o label rep
        set atts [my get_attributes disabled]
        lappend atts value $rep
        #my msg "lsearch {[my value]} $rep ==> [lsearch [my value] $rep]"
        if {$rep in [my value]} {
          lappend atts selected on
        }
        ::html::option $atts {::html::t $label}
        ::html::t \n
      }}
  }


  ###########################################################
  #
  # ::xowiki::formfield::candidate_box_select
  #
  ###########################################################
  Class create candidate_box_select -superclass select -parameter {
    {as_box false}
    {dnd true}
  }
  candidate_box_select set abstract 1

  candidate_box_select instproc render_input {} {
    #my msg "mul=[my multiple]"
    # makes only sense currently for multiple selects
    if {[my multiple] && [my dnd]} {
      if {([my exists disabled] && [my disabled])} {
        html::t -disableOutputEscaping [my pretty_value [my value]]
      } else {

        # utilities.js aggregates "yahoo, dom, event, connection, animation, dragdrop"
        set ajaxhelper 0
        ::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper "utilities/utilities.js"
        ::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper "selector/selector-min.js"
        ::xo::Page requireJS  "/resources/xowiki/yui-selection-area.js"
        
        set js ""
        foreach o [my options] {
          lassign $o label rep
          set js_label [::xowiki::Includelet js_encode $label]
          set js_rep   [::xowiki::Includelet js_encode $rep]
          append js "YAHOO.xo_sel_area.DDApp.values\['$js_label'\] = '$js_rep';\n"
          append js "YAHOO.xo_sel_area.DDApp.dict\['$js_rep'\] = '$js_label';\n"
        }
        
        ::html::div -class workarea {
          ::html::h3 { ::html::t "#xowiki.Selection#"}
          set values ""
          foreach v [my value] {
            append values $v \n
            set __values($v) 1
          }
          my CSSclass selection
          my set cols 30
          set atts [my get_attributes id name disabled {CSSclass class}]
          
          # TODO what todo with DISABLED?
          ::html::textarea [my get_attributes id name cols rows style {CSSclass class} disabled] {
            ::html::t $values
          }
        }
        ::html::div -class workarea {
          ::html::h3 { ::html::t "#xowiki.Candidates#"}
          ::html::ul -id [my id]_candidates -class region {
            #my msg [my options]
            foreach o [my options] {
              lassign $o label rep
              # Don't show current values under candidates
              if {[info exists __values($rep)]} continue
              ::html::li -class candidates {::html::t $rep}
            }
          }
        }
        ::html::div -class visual-clear {
          ;# maybe some comment
        }
        ::html::script { html::t $js }
      }
    } else {
      next
    }
  }

  ###########################################################
  #
  # ::xowiki::formfield::abstract_page
  #
  ###########################################################

  Class create abstract_page -superclass candidate_box_select -parameter {
    {as_box false}
    {multiple_style comma}
  }
  abstract_page set abstract 1

  abstract_page instproc initialize {} {
    my set package_id [[my object] package_id]
    #my compute_options
    next
  }
  
  abstract_page instproc fetch_entry_label {entry_label item_id} {
    # The following is a temporary solution, only working with cr-item attributes
    # We should support as well user level instance attributes.
    set entry_label [string trimleft $entry_label _]

    ::xo::dc 1row [self proc] "select $entry_label from cr_items ci, cr_revisions cr
      where cr.revision_id = ci.live_revision and ci.item_id = :item_id"
    return [set $entry_label]
  }

  abstract_page instproc get_entry_label {value} {
    set item_id [[my set package_id] lookup -parent_id [[my object] parent_id] -name $value]
    if {$item_id} {
      return [::xo::cc cache [list my fetch_entry_label [my entry_label] $item_id]]
    }
    return ""
  }
  
  abstract_page instproc pretty_value {v} {
    my instvar package_id
    set object [my object]
    set parent_id [$object parent_id]
    my set options [my get_labels $v]
    if {[my multiple]} {
      foreach o [my set options] {
        lassign $o label value
        set href [$package_id pretty_link -parent_id $parent_id $value]
        set labels($value) "<a href='$href'>$label</a>"
      }
      set hrefs [list]
      foreach i $v {
        if {![info exists labels($i)]} {
          #my msg "can't determine label for value '$i' (values=$v, l=[array names labels])"
          set labels($i) $i
        }
        set href [$package_id pretty_link -parent_id $parent_id $i]
        lappend hrefs "<a href='$href'>$labels($i)</a>"
      }
      if {[my multiple_style] eq "list"} {
        return "<ul><li>[join $hrefs {</li><li>}]</li></ul>\n"
      } else {
        return [join $hrefs {, }]
      }
    } else {
      foreach o [my set options] {
        lassign $o label value
        #my log "comparing '$value' with '$v'"
        if {$value eq $v} {
          if {[my as_box]} {
            return [$object include [list $value -decoration rightbox]] 
          }
          set href [$package_id pretty_link -parent_id $parent_id $value]
          return "<a href='$href'>$label</a>"
        }
      }
    }
  }

  abstract_page instproc render_input {} {
    my compute_options
    next
  }

  ###########################################################
  #
  # ::xowiki::formfield::form_page
  #
  ###########################################################
  Class create form_page -superclass abstract_page -parameter {
    {form}
    {where}
    {entry_label _title}
  }

  form_page instproc initialize {} {
    my instvar form_object_item_ids package_id object
    if {![my exists form]} { return }
    next
    set form_name [my form]
    set package_id [$object package_id]
    set form_objs [::xowiki::Weblog instantiate_forms \
                       -parent_id [$object parent_id] \
                       -default_lang [$object lang] \
                       -forms $form_name -package_id $package_id]

    #set form_obj [[my object] resolve_included_page_name $form_name]
    if {$form_objs eq ""} {error "Cannot lookup Form '$form_name'"}
    
    set form_object_item_ids [list]
    foreach form_obj $form_objs {lappend form_object_item_ids [$form_obj item_id]}
  }
  form_page instproc compute_options {} {
    my instvar form_object_item_ids where package_id entry_label
    #my msg "[my name] compute_options [my exists form]"
    if {![my exists form]} {
      return
    }
    
    array set wc {tcl true h "" vars "" sql ""}
    if {[info exists where]} {
      array set wc [::xowiki::FormPage filter_expression $where &&]
      #my msg "where '$where' => wc=[array get wc]"
    }

    set from_package_ids {}
    set package_path [::$package_id package_path]
    if {[llength $package_path] > 0} {
      foreach p $package_path {
        lappend from_package_ids [$p id]
      }
    }
    lappend from_package_ids $package_id
    set items [::xowiki::FormPage get_form_entries \
                   -base_item_ids $form_object_item_ids \
                   -form_fields [list] \
                   -publish_status ready \
                   -h_where [array get wc] \
                   -package_id $package_id \
                   -from_package_ids $from_package_ids]

    set options [list]
    foreach i [$items children] {
      #
      # If the form_page has a different package_id, prepend the
      # package_url to the name. TODO: We assume here, that the form_pages
      # have no special parent_id.
      #
      set object_package_id [$i package_id]
      if {$package_id != $object_package_id} {
        set package_prefix /[$object_package_id package_url]
      } else {
        set package_prefix ""
      }

      lappend options [list [$i property $entry_label] $package_prefix[$i name]]
    }
    my options $options
  }

  form_page instproc pretty_value {v} {
    my options [my get_labels $v]
    if {![my exists form_object_item_ids]} {
      error "No forms specified for form_field '[my name]'"
    }
    my set package_id [[lindex [my set form_object_item_ids] 0] package_id]
    next
  }


  ###########################################################
  #
  # ::xowiki::formfield::page
  #
  ###########################################################
  Class create page -superclass abstract_page -parameter {
    {type ::xowiki::Page}
    {with_subtypes false}
    {glob}
    {entry_label name}
  }

  page instproc compute_options {} {
    my instvar type with_subtypes glob

    set extra_where_clause ""
    if {[my exists glob]} {
      append extra_where_clause [::xowiki::Includelet glob_clause $glob]
    }

    set package_id [[my object] package_id]
    set options [list]
    ::xo::dc foreach instance_select \
        [$type instance_select_query \
             -folder_id [$package_id folder_id] \
             -with_subtypes $with_subtypes \
             -select_attributes [list title] \
             -from_clause ", xowiki_page p" \
             -where_clause "p.page_id = bt.revision_id $extra_where_clause" \
             -orderby ci.name \
            ] {
              lappend options [list [set [my entry_label]] $name]
            }
    my options $options
  }

  page instproc pretty_value {v} {
    my set package_id [[my object] package_id]
    next
  }


  ###########################################################
  #
  # ::xowiki::formfield::security_policy
  #
  ###########################################################

  Class create security_policy -superclass select
  security_policy instproc initialize {} {
    foreach p [lsort [::xowiki::Policy info instances]] {
      lappend options [list $p $p]
    }
    my options $options
    next
  }

  ###########################################################
  #
  # ::xowiki::formfield::DD
  #
  ###########################################################

  Class create DD -superclass select
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

  Class create HH24 -superclass select
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

  Class create MI -superclass select
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

  Class create MM -superclass select
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

  Class create mon -superclass select
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

  Class create month -superclass select
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

  Class create YYYY -superclass numeric -parameter {
    {size 4}
    {maxlength 4}
  } -extend_slot_default validator YYYY

  YYYY instproc check=YYYY {value} {
    if {$value ne ""} {
      return [expr {[catch {clock scan "$value-01-01 00:00:00"}] == 0}]
    }
    return 1
  }

  ###########################################################
  #
  # ::xowiki::formfield::youtube_url
  #
  ###########################################################
  Class create youtube_url -superclass text
  youtube_url set urlre {^http://www.youtube.com/watch[?]v=([^?]+)([?]?)}
  
  youtube_url instproc initialize {} {
    next
    if {[my help_text] eq ""} {my help_text "#xowiki.formfield-youtube_url-help_text#"}
  }
  youtube_url instproc pretty_value {v} {
    if {$v eq ""} {
      return ""
    } elseif {[regexp [[self class] set urlre] $v _ name]} {
      return "<object width='425' height='344'>
<param name='movie' value='http://www.youtube.com/v/$name&fs=1'></param>
<param name='allowFullScreen' value='true'></param>
<embed src='http://www.youtube.com/v/$name&fs=1' type='application/x-shockwave-flash' allowfullscreen='true' width='425' height='344'></embed>
</object>\n"
    } else {
      return "'$v' does not look like a youtube url"
    }
  }

  ###########################################################
  #
  # ::xowiki::formfield::image_url
  #
  ###########################################################

  Class create image_url -superclass text \
      -extend_slot_default validator image_check \
      -parameter {
        href cssclass
        {float left} width height 
        padding {padding-right 10px} padding-left padding-top padding-bottom
        margin margin-left margin-right margin-top margin-bottom
        border border-width position top botton left right
      }
  image_url instproc initialize {} {
    next
    if {[my help_text] eq ""} {my help_text "#xowiki.formfield-image_url-help_text#"}
  }
  image_url instproc entry_name {value} {
    set value [string map [list %2e .] $value]
    if {![regexp -nocase {/([^/]+)[.](gif|jpg|jpeg|png)} $value _ name ext]} {
      return ""
    }
    return file:$name.$ext
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
    if {[regexp {^file://(.*)$} $value _ path]} {
      set f [open $path r]
      fconfigure $f translation binary
      set img [read $f] 
      close $f
    } elseif {[catch {
      set r [::xo::HttpRequest new -url $value -volatile]
      set img [$r set data]
    } errorMsg]} {
      # cannot transfer image
      my log "--img cannot tranfer image '$value' ($errorMsg)"
      return 0
    }
    #my msg "guess mime_type of $entry_name = [::xowiki::guesstype $entry_name]"
    set import_file [ad_tmpnam]
    ::xowiki::write_file $import_file $img
    set file_object [::xowiki::File new -destroy_on_cleanup \
                         -title $entry_name \
                         -name $entry_name \
                         -parent_id $folder_id \
                         -mime_type [::xowiki::guesstype $entry_name] \
                         -package_id [[my object] package_id] \
                         -creation_user [::xo::cc user_id] \
                        ]
    $file_object set import_file $import_file
    $file_object save_new
    return 1
  }
  image_url instproc pretty_value {v} {
    set entry_name [my entry_name $v]
    return [my pretty_image -parent_id [[my object] parent_id] $entry_name]
  }


  ###########################################################
  #
  # ::xowiki::formfield::include
  #
  ###########################################################

  # note that the includelet "include" can be used for implementing symbolic links
  # to other xowiki pages.
  Class create include -superclass text -parameter {
  }

  include instproc pretty_value {v} {
    if {$v eq ""} { return $v }

    my instvar object
    set item_id  [$object get_property_from_link_page item_id]
    if {$item_id == 0} {
      # Here, we could call "::xowiki::Link render" to offer the user means
      # to create the entry like with [[..]], if he has sufficent permissions...;
      # when $(package_id) is 0, the referenced package could not be
      # resolved
      return "Cannot resolve symbolic link '$v'"
    }
    set link_type [$object get_property_from_link_page link_type]
    $object references resolved [list $item_id $link_type]

    #
    # resetting esp. the item-id is dangerous. Therefore we reset it immediately after the rendering
    #
    $item_id set_resolve_context \
        -package_id [$object package_id] -parent_id [$object parent_id] \
        -item_id [$object item_id]
    set html [$item_id render]
    #my msg "reset resolve-context"
    $item_id reset_resolve_context

    return $html
  }

  ###########################################################
  #
  # ::xowiki::formfield::redirect
  #
  ###########################################################

  Class create redirect -superclass text
  redirect instproc pretty_value {v} {
    #ad_returnredirect -allow_complete_url $v
    #ad_script_abort
    return [[[my object] package_id] returnredirect $v]
  }

  ###########################################################
  #
  # ::xowiki::formfield::CompoundField
  #
  ###########################################################

  Class create CompoundField -superclass FormField -parameter {
    {components ""}
    {CSSclass compound-field}
  } -extend_slot_default validator compound

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

  CompoundField instproc set_is_repeat_template {is_template} {
    # my msg "[my name] set is_repeat_template $is_template"
    if {$is_template} {
      my set is_repeat_template true
    } else {
      my unset -nocomplain is_repeat_template
    }
    foreach c [my components] {
      $c set_is_repeat_template $is_template
    }
  }

  CompoundField instproc same_value {v1 v2} {
    if {$v1 eq $v2} {return 1}
    foreach {n1 value1} $v1 {n2 value2} $v2  {
      set f [my set component_index($n1)]
      if {![$f same_value $value1 $value2]} { return 0 }
    }   
    return 1
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

  CompoundField instproc validate {obj} {
    # Delegate validate to the components. If a validation of a
    # component fails, report the error message back.
    foreach c [my components] {
      set result [$c validate $obj]
      if {$result ne ""} {
        return $result
      }
    }
    return ""
  }

  CompoundField instproc set_compound_value {value} {
    if {[catch {array set {} $value} errorMsg]} {
      # this branch could be taken, when the field was retyped
      ns_log notice "CompoundField: error during setting compound value with $value: $errorMsg"
    }
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
      #my msg "$c [$c info class] lappending [list [$c name] [$c value]]"
      lappend value [$c name] [$c value]
    }
    #my msg "[my name]: get_compound_value returns value=$value"
    return $value
  }

  CompoundField instproc specs_unmodified {spec_list} {
    expr {[my set __state] eq "after_specs"
          && [my exists structure] && [my set structure] eq $spec_list
        }
  }

  CompoundField instproc create_components {spec_list} {
    #
    # Omit after specs for compund fields to avoid multiple
    # recreations.
    #
    if {[my specs_unmodified $spec_list]} return

    #
    # Build a component structure based on a list of specs
    # of the form {name spec}.
    #
    my set structure $spec_list
    my set components [list]
    foreach entry $spec_list {
      lassign $entry name spec
      #
      # create for each component a form field
      #
      set c [::xowiki::formfield::FormField create [self]::$name \
                 -name [my name].$name -id [my id].$name \
                 -locale [my locale] -object [my object] \
                 -spec $spec]
      my set component_index([my name].$name) $c
      my lappend components $c
    }
  }

  CompoundField instproc get_component {component_name} {
    set key component_index([my name].$component_name)
    if {[my exists $key]} {
      return [my set $key]
    }
    error "no component named $component_name of compound field [my name]"
  }

  CompoundField instproc exists_named_sub_component args {
    # Iterate along the argument list to check components of a deeply
    # nested structure. For example,
    #
    #    my check_named_sub_component a b
    #
    # returns 0 or one depending whether there exists a component "a"
    # with a subcomponent "b".
    set component_name [my name]
    set sub [self]
    foreach e $args {
      append component_name .$e
      if {![$sub exists component_index($component_name)]} {
        return 0
      }
      set sub [$sub set component_index($component_name)]
    }
    return 1
  }

  CompoundField instproc get_named_sub_component args {
    # Iterate along the argument list to get components of a deeply
    # nested structure. For example,
    #
    #    my get_named_sub_component a b
    #
    # returns the object of the subcomponent "b" of component "a"
    set component_name [my name]
    set sub [self]
    foreach e $args {
      append component_name .$e
      #my msg "check $sub set component_index($component_name)"
      set sub [$sub set component_index($component_name)]
    }
    return $sub
  }

  CompoundField instproc get_named_sub_component_value {{-default ""} args} {
    if {[my exists_named_sub_component {*}$args]} {
      return [[my get_named_sub_component {*}$args] value]
    } else {
      return $default
    }
  }

  CompoundField instproc generate_fieldnames {{-prefix "v-"} n} {
    set names [list]
    for {set i 1} {$i <= $n} {incr i} {lappend names $prefix$i}
    return $names
  }

  CompoundField instproc render_input {} {
    #
    # Render content within in a fieldset, but with labels etc.
    #
    html::fieldset [my get_attributes id {CSSclass class}] {
      foreach c [my components] { $c render }
    }
  }

  CompoundField instproc pretty_value {v} {
    #
    # Typically, subtypes of CompoundFields should define their own
    # "pretty_value". This is a simple renderer that provides a
    # default behavior.
    #
    set ff [dict create {*}$v]
    set html "<ul class='CompoundField'>\n"
    foreach c [my components] {
      set componentName [$c set name]
      if {[dict exists $ff $componentName]} {
        append html "<li><span class='name'>$componentName:</span> " \
            "[$c pretty_value [dict get $ff $componentName]]</li>\n"
      }
    }
    append html "</ul>\n"
    return $html
  }
  
  CompoundField instproc has_instance_variable {var value} {
    set r [next]
    if {$r} {return 1}
    foreach c [my components] { 
      set r [$c has_instance_variable $var $value]
      if {$r} {return 1}
    }
    return 0
  }

  CompoundField instproc convert_to_internal {} {
    foreach c [my components] { 
      $c convert_to_internal
    }
    # Finally, update the compound value entry with the compound
    # internal representation; actually we could drop the instance
    # atts of the components from the "instance_attributes" ...
    [my object] set_property -new 1 [my name] [my get_compound_value]
  }

  ###########################################################
  #
  # ::xowiki::formfield::label
  #
  ###########################################################

  Class create label -superclass FormField -parameter {
    {disableOutputEscaping false}
  }
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
    # Include labels as hidden fields to avoid surprises when
    # switching field types to labels.
    my set type hidden
    next
  }


  ###########################################################
  #
  # ::xowiki::formfield::child_pages
  #
  ###########################################################
  Class create child_pages -superclass label -parameter {
    {form}
    {publish_status all}
  }
  child_pages instproc initialize {} {
    next
    #
    # for now, we allow just FormPages as child_pages
    #
    if {![my exists form]} { return }
    my instvar object
    my set form_objs [::xowiki::Weblog instantiate_forms \
                          -parent_id [$object parent_id] \
                          -default_lang [$object lang] \
                          -forms [my form] \
                          -package_id [$object package_id]]
  }
  child_pages instproc pretty_value {v} {
    if {[my exists form_objs]} {
      my instvar object
      set count 0
      foreach form [my set form_objs] {
        incr count [$form count_usages \
                        -package_id [$object package_id] \
                        -parent_id [$object item_id] \
                        -publish_status [my publish_status]]
      }
      return $count
    } else {
      return 0-NULL
    }
  }

  ###########################################################
  #
  # ::xowiki::formfield::date
  #
  ###########################################################

  Class create date -superclass CompoundField -parameter {
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
    #my msg "[my name] initialize date, format=[my format] components=[my components]"
    foreach c [my components] {$c destroy}
    my components [list]

    foreach element [split [my format]] {
      if {![my exists format_map($element)]} {
        #
        # We add undefined formats as literal texts in the edit form
        #
        set name $element
        set c [::xowiki::formfield::label create [self]::$name \
                   -name [my name].$name -id [my id].$name \
                   -locale [my locale] -object [my object] \
                   -value $element]
        $c set_disabled 1; # this is a dummy field, never query for its value
        if {$c ni [my components]} {my lappend components $c}
        continue
      }
      lassign [my set format_map($element)] class code trim_zeros
      #
      # create for each component a form field
      #
      set name $class
      set c [::xowiki::formfield::$class create [self]::$name \
                 -name [my name].$name -id [my id].$name \
                 -locale [my locale] -object [my object]]
      #my msg "creating [my name].$name"
      $c set_disabled [my exists disabled]
      $c set code $code
      $c set trim_zeros $trim_zeros
      if {$c ni [my components]} {my lappend components $c}
    }
  }

  date instproc set_compound_value {value} {
    #my msg "[my name] original value '[my value]' // passed='$value' disa?[my exists disabled]"
    # if {$value eq ""} {return}
    if { $value eq {} } {
      # We need to reset component values so that
      # instances of this class can be used as flyweight
      # objects. Otherwise, we get side-effects when
      # we render the input widget.
      foreach c [my components] { 
        $c value ""
      }
      return
    }
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
    if {[catch {set ticks [clock scan "$year-$month-$day ${hour}:${min}:${sec}"]}]} {
      set ticks 0 ;# we assume that the validator flags these values
    } 
    # TODO: TZ???
    #my msg "DATE [my name] get_compound_value returns [clock format $ticks -format {%Y-%m-%d %T}]"
    return [clock format $ticks -format "%Y-%m-%d %T"]
  }
  
  date instproc same_value {v1 v2} {
    if {$v1 eq $v2} {return 1}
    return 0
  }

  date instproc pretty_value {v} {
    my instvar display_format
    #
    # Internally, we use the ansi date format. For displaying the date, 
    # use the specified display format and present the time localized.
    #
    # Drop of the value after the "." we assume to have a date in the local zone
    regexp {^([^.]+)[.]} $v _ v
    #return [clock format [clock scan $v] -format [string map [list _ " "] [my display_format]]]
    if {$display_format eq "pretty-age"} {
      return [::xowiki::utility pretty_age -timestamp [clock scan $v] -locale [my locale]]
    } else {
      return [lc_time_fmt $v [string map [list _ " "] [my display_format]] [my locale]]
    }
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

  Class create boolean -superclass radio -parameter {
    {default t}
  }
  boolean instproc value_if_nothing_is_returned_from_form {default} {
    if {[my exists disabled]} {return $default} else {return f}
  }
  boolean instproc initialize {} {
    # should be with cvs head message catalogs:
    my options "{#acs-kernel.common_Yes# t} {#acs-kernel.common_No# f}"
    next
  }

  ###########################################################
  #
  # ::xowiki::boolean_image
  #
  ###########################################################

  Class create boolean_image -superclass FormField -parameter {
    {default t} 
    {t_img_url /resources/xowiki/examples/check_richtig.png}
    {f_img_url /resources/xowiki/examples/check_falsch.png}
    {CSSclass img_boolean}
  }
  boolean_image instproc initialize {} {
    my type hidden
    my set widget_type boolean(hidden)
  }
  boolean_image instproc render_input {} {
    my instvar t_img_url f_img_url CSSclass
    set title [expr {[my exists __render_help_text_as_title_attr] ? [my set help_text] : ""}]
    ::html::img \
        -title $title \
        -class $CSSclass \
        -src [expr {[my value] ? $t_img_url : $f_img_url}] \
        -onclick "toggle_img_boolean(this,'$t_img_url','$f_img_url')"
    ::html::input -type hidden -name [my name] -value [my value]

    ::xo::Page requireJS {
      function toggle_img_boolean (element,t_img_url,f_img_url) {
        var input = $(element).next();
        var state = input.val()== "t";  
        if (state) {
          input.val('f');
          $(element).attr('src',f_img_url);
        } else {
          input.val('t');
          $(element).attr('src',t_img_url);
        }
      }
    }
  }

  ###########################################################
  #
  # ::xowiki::formfield::scale
  #
  ###########################################################

  Class create scale -superclass radio -parameter {{n 5} {horizontal true}}
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

  Class create form -superclass richtext -parameter {
    {height 200}
  } -extend_slot_default validator form

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

  Class create form_constraints -superclass textarea -parameter {
    {rows 5}
  } -extend_slot_default validator form_constraints
  # the form_constraints checker is defined already on the ::xowiki::Page level


  ###########################################################
  #
  # ::xowiki::formfield::event
  #
  # This formfield is rendered following the conventions of the
  # h-event of microformats2.
  #
  # See: http://microformats.org/wiki/h-event
  #
  ###########################################################

  Class create event -superclass CompoundField -parameter {
    {multiday false}
    {calendar}
    {time_label #xowiki.event-time#}
  }

  event instproc initialize {} {
    #my log "event initialize [my exists __initialized], multi=[my multiday] state=[my set __state]"
    if {[my set __state] ne "after_specs"} return
    my set widget_type event
    if {[my multiday]} {
      set dtend_format DD_MONTH_YYYY_#xowiki.event-hour_prefix#_HH24_MI
      set dtend_display_format %Q_%X
    } else {
      set dtend_format HH24_MI
      set dtend_display_format %X
    }
    my create_components [subst {
      {title {text,label=#xowiki.event-title_of_event#}}
      {summary {richtext,height=150px,label=#xowiki.event-summary_of_event#}}
      {dtstart {date,required,format=DD_MONTH_YYYY_#xowiki.event-hourprefix#_HH24_MI,
        default=now,label=#xowiki.event-start_of_event#,display_format=%Q_%X}}
      {dtend   date,format=$dtend_format,default=now,label=#xowiki.event-end_of_event#,display_format=$dtend_display_format}
      {location text,label=#xowiki.event-location#}
      {cal_item_id hidden}
    }]
    my set __initialized 1
  }

  event instproc get_compound_value {} {
    if {![my exists __initialized]} {
      return ""
    }
    set dtstart  [my get_component dtstart]
    set dtend    [my get_component dtend]
    if {![my multiday]} {
      # If the event is not a multi-day-event, the end_day is not
      # given by the dtend widget, but is taken from dtstart.
      set end_day  [lindex [$dtstart value] 0]
      set end_time [lindex [$dtend value] 1]
      $dtend value "$end_day $end_time"
      #my msg "[$dtend name] set to '$end_day $end_time' ==> $dtend, [$dtend value]"
    }
    next
  }

  event instproc pretty_value {v} {
    #array set {} [my value]
    set dtstart [my get_component dtstart]
    set dtstart_val [$dtstart value]
    set dtstart_iso [::xo::ical clock_to_iso [clock scan $dtstart_val]]
    set dtstart_pretty [$dtstart pretty_value $dtstart_val]

    set dtend [my get_component dtend]
    set dtend_val [$dtend value]
    set dtend_txt ""
    if {$dtend_val ne ""} {
      set dtend_iso [::xo::ical clock_to_iso [clock scan $dtend_val]]
      set dtend_txt " - <time class='dt-end' title='$dtend_iso'>[$dtend pretty_value $dtend_val]</time>"
    }

    set time_label [my time_label]
    if {[regexp {^#(.+)#$} $time_label _ msg_key]} {
      set time_label [lang::message::lookup [my locale] $msg_key]
    }
   
    set title_val   [[my get_component title] value]
    if {$title_val eq ""} {
      set title_val [[my object] property _title]
    }
    set summary_val [[my get_component summary] value]

    set location [my get_component location]
    set location_val [$location value]
    set location_txt ""
    if {$location_val ne ""} {
      set location_label [$location label]
      if {[regexp {^#(.+)#$} $location_label _ msg_key]} {
        set location_label [lang::message::lookup [my locale] $msg_key]
      }
      set location_txt "<tr><td>$location_label:</td><td><span class='p-location'>$location_val</span></td></tr>"
    }

    append result \n\
        "<div class='h-event'>" \n\
        "<h1 class=p-name>$title_val</h1>" \n\
        "<p class='p-summary'>$summary_val</p>" "<br> " \n\
        "<table>" \n\
        "<tr><td>$time_label:</td><td><time class='dt-start' datetime='$dtstart_iso'>$dtstart_pretty</time> $dtend_txt</td></tr>" \n\
        $location_txt \n\
        "</table>" \n\
        "</div>" \n
    return $result
  }

  event instproc convert_to_internal {} {
    if {[my exists calendar]} {
      #
      # Check, if the calendar package is available
      #
      if {[info commands ::calendar::item::new] eq ""} {
        error "the calendar package is not available"
      }

      #
      # Check, if the calendar_id can be determined
      #
      set calendar_id ""
      if {[string is integer -strict [my calendar]]} {
        set calendar_id [my calendar]
        if {[calendar::name $calendar_id] eq ""} {
          set calendar_id ""
        }
      }
      if {$calendar_id eq ""} {
        error "calendar '[my calendar] has no valid calendar_id"
      }

      #
      # Get the values for the calendar item
      #
      set dtstart_val [[my get_component dtstart] value]
      set dtend_val   [[my get_component dtend]   value]
      set title_val   [[my get_component title]   value]
      set title_val   [[my get_component title]   value]
      set summary_val [[my get_component summary] value]
      set cal_item_id [[my get_component cal_item_id] value]

      #
      # Check, if the cal_item_id is valid. If not, ignore it
      #
      if {$cal_item_id ne ""} {
        # if the object does not exist, it was probably deleted manually
        if {![acs_object::object_p -id $cal_item_id]} {
          set cal_item_id ""
        } else {
          acs_object::get -object_id $cal_item_id -array row
          if {$row(object_type) ne "cal_item"} {
            ns_log warning "event: the associated entry $cal_item_id is not a calendar item, ignore the old association"
            set cal_item_id ""
          }
        }
      }

      #
      # update values via transaction queue
      #
      set queue ::__xowiki__transaction_queue([[my object] item_id])
      lappend $queue [list [self] update_calendar -cal_item_id $cal_item_id -calendar_id $calendar_id \
                          -start $dtstart_val -end $dtend_val -name $title_val -description $summary_val]
    }
    
    next
  }

  event instproc update_calendar {-cal_item_id -calendar_id -start -end -name -description} {
    #
    # If we have already a valid cal_item_id (checked previously)
    # update the entry. Otherwise create a new calender item and
    # update the instance variables.
    #
    if {$cal_item_id ne ""} {
      #my log "===== [list calendar::item::edit -start_date $start -end_date $end -cal_item_id $cal_item_id ...]"
      calendar::item::edit -cal_item_id $cal_item_id -start_date $start \
          -end_date $end -name $name -description $description
    } else {
      #my log "===== [list calendar::item::new -start_date $start -end_date $end -calendar_id $calendar_id ...]"
      set cal_item_id [calendar::item::new -start_date $start -end_date $end \
                             -name $name -description $description -calendar_id $calendar_id]
      [my get_component cal_item_id] value $cal_item_id
      #
      # The following line is required when used in transaction to
      # update the instance attributes
      #
      [my object] set_property event [my get_compound_value]
    }
  }


}

namespace eval ::xowiki::formfield {

  ###########################################################
  #
  # ::xowiki::formfield::class
  #
  ###########################################################

  Class create class -superclass select -parameter {
    {subclass_of ::xotcl::Object}
  }
  class instproc initialize {} {
    my set options ""
    set baseclass [my subclass_of]
    foreach cl [lsort [concat $baseclass [$baseclass info subclass -closure]]] {
      my lappend options [list $cl $cl]
    }
    next
  }
}

::xo::library source_dependent 

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
