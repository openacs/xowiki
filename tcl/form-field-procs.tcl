::xo::library doc {
  XoWiki - form fields

  @creation-date 2007-06-22
  @author Gustaf Neumann
  @cvs-id $Id$
}

namespace eval ::xowiki::formfield {

  # FormFields are objects, which can be outputted as well in ad_forms
  # or asHTML included in wiki pages. FormFields support
  #
  #  - validation
  #  - help_text
  #  - error messages
  #  - internationalized pretty_values
  #
  # and inherit properties of the original datatypes via slots
  # (e.g. for boolean entries). FormFields can be subclassed
  # to ensure tailor-ability and high reuse.
  #
  # todo: at some later time, this could go into xotcl-core

  ###########################################################
  #
  # ::xowiki::formfield::FormField (Base Class)
  #
  ###########################################################
  Class create FormField -superclass ::xo::tdom::Object -parameter {
    {required false}
    {display_field true}
    {hide_value false}
    {inline false}
    {mode edit}
    {disabled}
    {disabled_as_div}
    {show_raw_value}

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

    {CSSclass}
    {form_item_wrapper_CSSclass}
    {form_widget_CSSclass}
    {form_button_CSSclass}
    {form_button_wrapper_CSSclass}
    {form_help_text_CSSclass}
    {td_CSSclass}

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
    grading
    in_position
    test_item_in_position
    test_item_minutes
  }
  #
  # TODO: "in_position" is just for a short transitional phase here
  # (live-updates), and should be removed ASAP.
  #
  FormField set abstract 1

  FormField proc fc_encode {string} {
    return [string map [list , __COMMA__] $string]
  }
  FormField proc fc_decode {string} {
    return [string map [list __COMMA__ ,] $string]
  }

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
          #ad_log warning "strange, $f [$f name] was created without object but fits name"
          return $f
        } elseif {$object eq [$f object]} {
          return $f
        }
      }
    }
    #:msg not-found-$object-$name
    return ""
  }


  #FormField instproc destroy {} {
  #  :log "=== FormField DESTROY ====="
  #  next
  #}

  FormField instproc init {} {
    if {![info exists :label]} {
      set :label [string totitle ${:name}]
    }
    if {![info exists :id]} {
      set :id ${:name}
    }
    set :html(id) ${:id}
    #if {[info exists :default]} {set :value [:default]}
    :config_from_spec ${:spec}
  }

  #
  # Basic initialize method, doing nothing; should be subclassed by the
  # application classes
  FormField instproc initialize {} {next}

  FormField instproc same_value {v1 v2} {
    if {$v1 eq $v2} {return 1}
    return 0
  }

  FormField instproc validation_check {validator_method value} {
    return [:uplevel [list :$validator_method $value]]
  }

  FormField instproc validate {obj} {
    # use the 'value' method to deal e.g. with compound fields
    set value [:value]
    #:msg "[:info class] value=$value req=${:required} // ${:value} //"

    if {${:required}
        && $value eq ""
        && ![:istype ::xowiki::formfield::hidden]
      } {
      return [_ acs-templating.Element_is_required [list label ${:label}]]
    }
    #
    #:log "++ ${:name} [:info class] validator=[:validator] ([llength [:validator]]) value=$value"
    foreach validator [:validator] {
      set errorMsg ""
      #
      # The validator might set the variable errorMsg in this scope.
      #
      set success 1
      set validator_method check=$validator
      set proc_info [:procsearch $validator_method]
      #:log "++ ${:name}: field-level validator exists '$validator_method' ? [expr {$proc_info ne {}}]"
      if {$proc_info ne ""} {
        #
        # We have a slot checker, call it.
        #
        #:msg "++ call-field level validator $validator_method '$value'"
        set success [:validation_check $validator_method $value]
      }
      if {$success == 1} {
        #
        # The previous check was ok, check now for a validator on the
        # object level.
        #
        set validator_method validate=$validator
        set proc_info [$obj procsearch $validator_method]
        #:log "++ ${:name}: page-level validator exists ? [expr {$proc_info ne {}}]"
        if {$proc_info ne ""} {
          set success [$obj $validator_method $value]
          #:msg "++ call page-level validator $validator_method '$value' returns $success"
        }
      }
      if {$success == 0} {
        #
        # We have an error message. Get the class name from procsearch and construct
        # a message key based on the class and the name of the validator.
        #
        set cl [namespace tail [lindex $proc_info 0]]
        #:msg "__langPkg?[info exists __langPkg]"
        if {![info exists __langPkg]} {
          set __langPkg "xowiki"
        }
        #:log "calling $__langPkg.$cl-validate_$validator with [list value $value errorMsg $errorMsg] on level [info level] -- [lsort [info vars]]"
        set msg [_ $__langPkg.$cl-validate_$validator [list value $value errorMsg $errorMsg]]
        #:log "++ ${:name}: ======> RETURN VALIDATION FAILED <$msg>"
        return $msg
      }
    }
    return ""
  }

  FormField instproc reset_parameter {} {
    # reset application specific parameters (defined below ::xowiki::formfield::FormField)
    # such that searchDefaults will pick up the new defaults, when a form field
    # is reclassed.

    if {[info exists :per_object_behavior]} {
      # remove per-object mixin from the "behavior"
      :mixin delete ${:per_object_behavior}
      :unset per_object_behavior
    }

    #:msg "reset along [:info precedence]"
    foreach c [:info precedence] {
      if {$c eq "::xowiki::formfield::FormField"} break
      foreach s [$c info slots] {
        if {![$s exists default]} continue
        set var [$s name]
        set key processed($var)
        if {[info exists $key]} continue
        set :$var [$s default]
        set $key 1
      }
    }
    if {[info exists :disabled]} {
      :set_disabled 0
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
      set success [$object evaluate_form_field_condition $cond]
    }
    return $success
  }

  FormField set cond_regexp {^([^=?]+)[?]([^:]*)[:](.*)$}

  FormField proc get_single_spec {-package_id -object string} {
    if {[regexp ${:cond_regexp} $string _ condition true_spec false_spec]} {
      if {[:interprete_condition -package_id $package_id -object $object $condition]} {
        return [:get_single_spec -package_id $package_id -object $object $true_spec]
      } else {
        return [:get_single_spec -package_id $package_id -object $object $false_spec]
      }
    }
    return $string
  }

  FormField instproc remove_omit {} {
    set m ::xowiki::formfield::omit
    if {[:ismixin $m]} {:mixin delete $m}
  }
  FormField instproc set_disabled {disable} {
    #:msg "${:name} set disabled $disable"
    if {$disable} {
      set :disabled true
    } else {
      :unset -nocomplain disabled
    }
  }

  FormField instproc behavior {mixin} {

    #
    # Specify the behavior of a form field via
    # per object mixins
    #
    set pkgctx [[${:object} package_id] context]
    if {[$pkgctx exists embedded_context]} {
      set ctx [$pkgctx set embedded_context]
      set classname ${ctx}::$mixin
      #:msg ctx=$ctx-viewer=$mixin,found=[:isclass $classname]
      # TODO: search different places for the mixin. Special namespace?
      if {[:isclass $classname]} {
        if {[info exists :per_object_behavior]} {
          :mixin delete ${:per_object_behavior}
        }
        :mixin add $classname
        set :per_object_behavior $classname
      } else {
        :msg "Could not find mixin '$mixin'"
      }
    }
  }

  FormField instproc interprete_single_spec {s} {
    if {$s eq ""} return

    set package_id [${:object} package_id]
    set s [::xowiki::formfield::FormField get_single_spec -object ${:object} -package_id $package_id $s]

    switch -glob -- $s {
      optional    {set :required false}
      required    {set :required true; :remove_omit}
      omit        {:mixin add ::xowiki::formfield::omit}
      noomit      {:remove_omit}
      disabled    {:set_disabled true}
      readonly    {:readonly true}
      enabled     {:set_disabled false}
      label=*     {:label     [lindex [split $s =] 1]}
      help_text=* {:help_text [lindex [split $s =] 1]}
      *=*         {
        set p [string first = $s]
        set attribute [string range $s 0 $p-1]
        set value [string range $s $p+1 end]
        set definition_class [lindex [:procsearch $attribute] 0]
        set method [:info methods $attribute]
        if {[string match "::xotcl::*" $definition_class] || $method eq ""} {
          error [_ xowiki.error-form_constraint-unknown_attribute [list class [:info class] name ${:name} entry $attribute]]
        }
        ad_try {
          #
          # We want to allow a programmer to use e.g. options=[xowiki::locales]
          #
          # Note: do not allow users to use [] via forms, since they might
          # execute arbitrary commands. The validator for the form fields
          # makes sure that the input specs are free from square brackets.
          #
          if {[string match {\[*\]} $value]} {
            set value [subst $value]
          }
          :$attribute $value
        } on error {errMsg} {
          error "Error during setting attribute '$attribute' to value '$value': $errMsg"
        }
      }
      default {
        # Check, if the spec value $s is a class.
        set old_class [:info class]
        # Don't allow one to use namespaced values, since we would run
        # into a recursive loop for richtext::wym (could be altered there as well).
        if {[:isclass ::xowiki::formfield::$s] && ![string match "*:*" $s]} {
          :class ::xowiki::formfield::$s
          :remove_omit
          if {$old_class ne [:info class]} {
            #:msg "${:name}: reset class from $old_class to [:info class]"
            :reset_parameter
            set :__state reset
            #:log "INITIALIZE ${:name} due to reclassing old $old_class to new [:info class]"
            :initialize
          }
        } else {
          if {$s ne ""} {
            error [_ xowiki.error-form_constraint-unknown_spec_entry \
                       [list name ${:name} entry $s x "Unknown spec entry for entry '$s'"]]
          }
        }
      }
    }
  }

  FormField instproc config_from_spec {spec} {
    #:log "config_from_spec ${:name} spec <$spec> [:info class] [[:info class] exists abstract]"
    if {[[:info class] exists abstract]} {
      # had earlier here: [:info class] eq [self class]
      # Check, whether the actual class is a concrete class (mapped to
      # concrete field type) or an abstract class.  Since
      # config_from_spec can be called multiple times, we want to do
      # the reclassing only once.
      if {[:isclass ::xowiki::formfield::${:type}]} {
        :class ::xowiki::formfield::${:type}
      } else {
        :class ::xowiki::formfield::text
      }
      # set missing instance vars with defaults
      :set_instance_vars_defaults
    }
    regsub -all {,\s+} $spec , spec
    foreach s [split $spec ,] {
      :interprete_single_spec [FormField fc_decode $s]
    }

    #:msg "${:name}: after specs"
    set :__state after_specs
    #:log "INITIALIZE ${:name} due to config_from_spec"
    :initialize

    #
    # It is possible, that a default value of a form field is changed through a spec.
    # Since only the configuration might set values, checking value for "" seems safe here.
    #
    if {[:value] eq "" && [info exists :default] && ${:default} ne ""} {
      #:msg "+++ reset value to [:default]"
      :value ${:default}
    }

    if {[lang::util::translator_mode_p]} {
      :mixin add "::xo::TRN-Mode"
    }

  }

  FormField instproc asWidgetSpec {} {
    set spec ${:widget_type}
    if {[info exists :spell]} {append spec ",[expr {${:spell} ? {} : {no}}]spell"}

    if {!${:required}} {append spec ",optional"}
    if {[info exists :editor]} {append spec " {options {editor ${:editor}}} "}
    append spec " {label " [list ${:label}] "} "

    if {[string match "*bootstrap*" [subsite::get_theme]]} {
      array set :html {class "form-control"}
    }

    if {[info exists :html]} {
      append spec " {html {"
      foreach {key value} [array get :html] {
        append spec $key " " [list $value] " "
      }
      append spec "}} "
    }

    if {[info exists :options]} {
      append spec " {options " [list ${:options}] "} "
    }
    if {[info exists :format]} {
      append spec " {format " [list ${:format}] "} "
    }

    if {${:help_text} ne ""} {
      if {[string match "#*#" ${:help_text}]} {
        set internationalized [:localize ${:help_text}]
        append spec " {help_text {$internationalized}}"
      } else {
        append spec " {help_text {${:help_text}}}"
      }
    }
    return $spec
  }

  FormField instproc render {} {
    # In case, we use an asHTML of a FormField, we use this
    # render definition
    if {${:inline}} {
      # with label, error message, help text
      :render_form_widget
    } else {
      # without label, error message, help text
      :render_item
    }
    set :__rendered 1
  }

  FormField instproc render_form_widget {} {
    # This method provides the form-widget wrapper
    set CSSclass [expr {[info exists :form_widget_CSSclass] ? ${:form_widget_CSSclass} : ""}]
    if {${:error_msg} ne ""} {
      append CSSclass " form-widget-error"
    }
    set atts [list class $CSSclass]
    if {${:inline}} {
      lappend atts style "display: inline;"
    }
    ::html::div $atts { :render_input }
  }

  FormField instproc booleanAttributes {args} {
    #
    # Special handling of HTML boolean attributes, since they require a
    # different coding; it would be nice, if tDOM would care for this.
    #
    set pairs ""
    foreach att $args {
      if {[info exists :$att] && [set :$att]} {
        set :__#$att $att
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
      if {[info exists :$var]} {:unset $var}
    }
  }

  FormField instproc is_disabled {} {
    return [expr {[info exists :disabled] && [string is true -strict ${:disabled}]}]
  }

  FormField instproc handle_transmit_always {value} {
    #
    # Disabled fields are not returned by the browsers. For some
    # fields, we require to be sent. Therefore, we include in these
    # cases the value in an additional hidden field. Maybe we should
    # change in the future the "name" of the disabled entry to keep
    # some hypothetical html-checker quiet.
    #
    if {[info exists :disabled] && [info exists :transmit_field_always]} {
      ::html::div {
        ::html::input [list type hidden name ${:name} value $value] {}
      }
    }
  }

  FormField instproc render_input {} {
    #
    # This is the most general widget content renderer.
    # If no special renderer is defined, we fall back to this one,
    # which is in most cases  a simple input field of type string.
    #
    set value [:value]
    if {${:mode} ne "edit"} {
      html::t -disableOutputEscaping [:pretty_value $value]
      return
    }
    if {[info exists :validate_via_ajax] && [:validator] ne ""} {
      set ajaxhelper 1
      ::xowiki::Includelet require_YUI_JS -ajaxhelper 0 "yahoo/yahoo-min.js"
      ::xowiki::Includelet require_YUI_JS -ajaxhelper 0 "dom/dom-min.js"
      ::xowiki::Includelet require_YUI_JS -ajaxhelper 0 "event/event-min.js"
      ::xowiki::Includelet require_YUI_JS -ajaxhelper 0 "connection/connection-min.js"
      ::xo::Page requireJS  "/resources/xowiki/yui-form-field-validate.js"
      set package_url [[${:object} package_id] package_url]
      ::xo::Page requireJS  "YAHOO.xo_form_field_validate.add('${:id}','$package_url');"
    }

    set booleanAtts [:booleanAttributes required readonly disabled multiple \
                         formnovalidate autofocus]
    #
    # We do not want i18n substitutions in the input fields. So, save
    # away the original value and pass the escaped value to the tDOM
    # renderer.
    #
    set old_value ${:value}
    set :value [xo::escape_message_keys $old_value]
    ::html::input [:get_attributes type size maxlength id name value \
                       autocomplete pattern placeholder {CSSclass class} {*}$booleanAtts] {}
    #
    # Reset values to original content
    #
    :resetBooleanAttributes $booleanAtts
    set :value $old_value

    :handle_transmit_always $value

    set :__rendered 1
  }

  FormField instproc render_item {} {
    ::html::div [:get_attributes {form_item_wrapper_CSSclass class}] {
      if {[:error_msg] ne ""} {
        set CSSclass form-label-error
      } else {
        set CSSclass form-label
      }
      ::html::div -class $CSSclass {
        ::html::label -for ${:id} {
          ::html::t ${:label}
        }
        if {${:required} && ${:mode} eq "edit"} {
          ::html::div -class form-required-mark {
            ::html::t " (#acs-templating.required#)"
          }
        }
      }
      :render_form_widget
      :render_help_text
      :render_error_msg
      html::t \n
    }
  }

  FormField instproc render_error_msg {} {
    if {[:error_msg] ne "" && ![info exists :error_reported]} {
      ::html::div -class form-error {
        set label ${:label} ;# needed for error_msg; TODO: we should provide a substitution_list similar to "_"
        ::html::t [::xo::localize [:error_msg]]
        :render_localizer
        set :error_reported 1
      }
    }
  }

  FormField instproc render_help_text {} {
    set text ${:help_text}
    if {$text ne ""} {
      html::div -class [:form_help_text_CSSclass] {
        html::span -class "info-sign" { }
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
      return [lang::message::lookup ${:locale} $key]
    }
    return $v
  }

  FormField ad_instproc dict_to_fc {
    -name
    -type:required
    dict
  } {

    Convert the provided dict into form_constraint syntax
    (comma separated).

    @param name optional form-field name
    @param type required type of the form-field
    @param dict dict to be converted.
  } {
    set result [expr {[info exists name] ? "$name:" : ""}]
    set list $type
    foreach {key value} $dict {
      lappend list $key=[::xowiki::formfield::FormField fc_encode $value]
    }
    return $result[join $list ,]
  }

  FormField instproc value_if_nothing_is_returned_from_form {default} {
    return $default
  }

  FormField instproc pretty_value {v} {
    #:log "mapping $v"
    return [string map [list & "&amp;" < "&lt;" > "&gt;" \" "&quot;" ' "&#39;" @ "&#64;"] $v]
  }

  FormField instproc has_instance_variable {var value} {
    if {[info exists :$var] && [set :$var] eq $value} {return 1}
    return 0
  }
  FormField instproc convert_to_internal {} {
    # to be overloaded
  }
  FormField instproc convert_to_external {value} {
    # to be overloaded
    return $value
  }

  FormField instproc process_correct_when_modifier {} {
    set value [string trim [regsub -all {[ ]+} ${:value} " "]]
    if {[string match "*lower*" [lindex ${:correct_when} 1]]} {
      set value [string tolower $value]
      set words [lrange ${:correct_when} 2 end]
      set modifier lower
    } else {
      set words [lrange ${:correct_when} 1 end]
      set modifier ""
    }
    return [list words $words value $value modifier $modifier]
  }

  FormField instproc answer_check=eq {} {
    set arg1 [lindex ${:correct_when} 1]
    return [expr {${:value} eq $arg1}]
  }
  FormField instproc answer_check=gt {} {
    set arg1 [lindex ${:correct_when} 1]
    return [expr {${:value} > $arg1}]
  }
  FormField instproc answer_check=ge {} {
    set arg1 [lindex ${:correct_when} 1]
    return [expr {${:value} >= $arg1}]
  }
  FormField instproc answer_check=lt {} {
    set arg1 [lindex ${:correct_when} 1]
    return [expr {${:value} < $arg1}]
  }
  FormField instproc answer_check=le {} {
    set arg1 [lindex ${:correct_when} 1]
    return [expr {${:value} <= $arg1}]
  }
  FormField instproc answer_check=btwn {} {
    set arg1 [lindex ${:correct_when} 1]
    set arg2 [lindex ${:correct_when} 2]
    return [expr {${:value} >= $arg1 && ${:value} <= $arg2}]
  }
  FormField instproc answer_check=in {} {
    #
    # Correct, when answer is in the given set.
    #
    set d [:process_correct_when_modifier]
    return [expr {[dict get $d value] in [dict get $d words]}]
  }
  FormField instproc answer_check=match {} {
    return [string match [lindex ${:correct_when} 1] ${:value}]
  }
  FormField instproc answer_check=contains {} {
    #
    # Correct, when answer contains any of the provided words.
    #
    set d [:process_correct_when_modifier]
    foreach word [dict get $d words] {
      if {[string match *$word* [dict get $d value]]} {
        return 1
      }
    }
    return 0
  }
  FormField instproc answer_check=answer_words {} {
    #
    # Correct, when the answer is equal to the provided (sequence of)
    # words, but white-space is ignored. When the first word is
    # "*lower*" then the provided answer of the student is converted
    # to lower case before the comparison is performed; as a
    # consequence the comparison is not case sensitive. Note that the
    # answer_words have to be provided in lower case as well.
    #
    set d [:process_correct_when_modifier]
    return [expr {[dict get $d value] eq [dict get $d words]}]
  }

  FormField instproc answer_is_correct {} {
    #
    # Return correctness of the answer based on the instance variables
    # ":correct_when" and ":answer". Possible results are
    #
    #  -  1: correct
    #  - -1: incorrect
    #  -  0: can't say (or report back, that no evaluation should be
    #        provided for this field)
    #
    #  This method is free from side-effects (no instance variables are updated).
    #
    #:log "CORRECT? ${:name} ([:info class]): value=${:value}, answer=[expr {[info exists :answer]?${:answer}:{NONE}}]"
    if {[info exists :correct_when]} {
      set op [lindex ${:correct_when} 0]
      if {[:procsearch answer_check=$op] ne ""} {
        set r [:answer_check=$op]
        if {$r == 0} {
          return -1
        } {
          return 1
        }
      } elseif { $op eq ""} {
        return 0
      } else {
        error "invalid operator '$op'"
      }
    } elseif {![info exists :answer]} {
      return 0
    } elseif {${:value} ne ${:answer}} {
      #:msg "v='${:value}' NE a='[:answer]'"
      #:log "... answer_is_correct value comparison '${:value}' NE a='${:answer}'"
      return -1
    } else {
      #:log "... answer_is_correct value comparison OK"
      return 1
    }
  }

  FormField instproc set_feedback {feedback_mode} {
    #
    # Set instance variables based on correctness of an answer.
    #
    #   - :form_widget_CSSclass
    #   - :evaluated_answer_result
    #   - :value (highlights potentially partial results, e.g. "contains")
    #   - :help_text
    #
    set correct [:answer_is_correct]
    #:log "${:name} [:info class]: correct? $correct"
    switch -- $correct {
      0  { set result "unknown" }
      -1 { set result "incorrect"}
      1  { set result "correct"  }
    }
    :form_widget_CSSclass $result
    set :evaluated_answer_result $result

    if {$correct == 0} {
      return ${:evaluated_answer_result}
    }

    set feedback ""
    if {[info exists :feedback_answer_$result]} {
      set feedback [set :feedback_answer_$result]
    } else {
      set feedback [_ xowf.answer_$result]
    }
    if {$feedback_mode > 1} {
      #:log "=== ${:name} == $feedback_mode=[info exists :correct_when] [info exists :correction] ============"
      if {[info exists :correct_when]} {
        append feedback " ${:correct_when}"
      } elseif {[info exists :correction]} {
        append feedback " ${:correction}"
        if {[info exists :correction_data]} {
          #append feedback " ${:correction_data}"
          if {[info exists :grading]} {
            if {${:grading} in  {"" "exact"}} {
              set score [expr {${:evaluated_answer_result} eq "correct" ? 100.0 : 0.0}]
              dict set :correction_data scores ${:grading} $score
            }
            if {[dict exists ${:correction_data} scores ${:grading}] } {
              set grading_score [dict get ${:correction_data} scores ${:grading}]
              if {$grading_score < 0} {
                set grading_score 0.0
              }
              #:log "=== ${:name} grading ${:grading} => $grading_score"
              if {[info exists :test_item_minutes]} {
                set points [format %.2f [expr {${:test_item_minutes} * $grading_score / 100.0}]]
                dict set :correction_data points $points
                #append feedback " correct: $grading_score "
                append feedback " points: $points of [format %.2f ${:test_item_minutes}]"
              } else {
                append feedback " grading_score $grading_score"
              }
              #${:object} set_property -new 1 grading_score $grading_score
              set :grading_score $grading_score
              #ns_log notice "SET GRADING score $grading_score for [self]"
            } else {
              ns_log notice "=== ${:name} == no scores for grading '${:grading}': ${:correction_data}"
            }
          } else {
            set :grading_score ""
            ns_log notice "=== ${:name} == no grading available"
          }
        } else {
          ns_log notice "=== ${:name} NO correction_data"
        }
      } else {
        ns_log notice "=== ${:name} NO correct_when and no :correction"
      }
      #
      # When the widget class supports "disabled_as_div", we
      # can try to highlight matches from :correct_when.
      #
      if {[info exists :disabled_as_div] && [info exists :correct_when]} {
        #
        # When render_as_div might or might not require output
        # escaping. When we have a markup produced form match
        # highlighting, the code sets :value_with_markup for
        # rendering. Otherwise, the plain :value is used.
        #
        set :value [ns_quotehtml ${:value}]
        if {[lindex ${:correct_when} 0] eq "contains"} {
          #
          # Mark matches in the div element.
          #
          set d [:process_correct_when_modifier]
          set nocase [expr {[dict get $d modifier] eq "lower" ? "-nocase" : ""}]
          set annotated_value ${:value}
          foreach word [dict get $d words] {
            #
            # We need here probably more escapes, or we should be more
            # restrictive on allowed content in the "contains" clause.
            #
            set word [string map {* \\*} $word]
            regsub -all {*}$nocase [ns_quotehtml $word] \
                $annotated_value \
                {<span class='match'>&</span>} \
                annotated_value
          }
          if {$annotated_value ne ${:value}} {
            set :value_with_markup $annotated_value
          }
        }
      }
    }
    #:log "==== ${:name} setting feedback $feedback"
    set :help_text $feedback
    return ${:evaluated_answer_result}
  }

  FormField instproc make_correct {} {
    #
    # Set the form_field to a correct value, currently based on
    # :correct_when.  We could use here :answer when available.
    # Modified instance variables
    #
    # - :help_text is cleared to avoid stray per-user-feedback,
    #    We could as well provide teacher-level feedback here.
    # - :form_widget_CSSclass is altered to "correct" or "unknown".
    #
    #ns_log notice "FormField make_correct ${:name}: [info exists :answer] [info exists :correct_when]"

    set :form_widget_CSSclass unknown
    if {[info exists :correct_when]} {
      #
      # Try to get a correct value from the correct_when spec
      #
      set predicate [lindex ${:correct_when} 0]
      set args [lrange ${:correct_when} 1 end]
      switch $predicate {
        "match"    {set correct $args}
        "eq"       {set correct $args}
        "gt"       {set correct "> $args"}
        "ge"       {set correct ">= $args"}
        "lt"       {set correct "< $args"}
        "le"       {set correct "<= $args"}
        "contains" {set correct "... [join $args { ... }] ..."}
        "answer_words" {set correct "... [join $args { ... }] ..."}
        "in"       {set correct "... [join args { OR }] ..."}
        "btwn"     {set correct "[lindex $args 0] <= X <= [lindex $args 1]"}

      }
      if {[info exists correct]} {
        :value $correct
        set :form_widget_CSSclass correct
        #ns_log notice "FormField make_correct ${:name}: value '${:value}'"
      } else {
        ns_log notice "FormField make_correct ${:name}: not handled: correct_when '${:correct_when}' "
      }
    } else {
      ns_log notice "FormField make_correct ${:name}: not handled: answer? [info exists :answer]"
    }
    set :help_text "" ;# we could provide a teacher-level feedback here.
  }

  FormField instproc add_statistics {{-options ""}} {
    dict incr :result_statistics count
    if {[info exists :evaluated_answer_result] && ${:evaluated_answer_result} eq "correct"} {
      dict incr :result_statistics correct
      #ns_log notice "??? add_statistics ${:name}: ${:result_statistics}"
    }
    dict incr :answer_statistics ${:value}
  }

  FormField instproc word_statistics {flavor} {
    #
    # Word statistics based on :value. It is assumed here, that the
    # value is basically a string with whitespace.
    #
    regsub -all {\s} ${:value} " " value
    foreach w [split $value " "] {
      dict incr :word_statistics [string tolower $w]
    }
    set :word_statistics_option $flavor
  }

  FormField instproc render_answer_statistics {} {
    #ns_log notice ":answer_statistics: ${:answer_statistics}"
    ::html::ul {
      foreach {answer freq} [lsort -decreasing -integer -stride 2 -index 1 ${:answer_statistics}] {
        html::li { html::t "$freq: $answer" }
      }
    }
  }

  FormField instproc render_word_statistics {} {
    #ns_log notice ":render_word_statistics: ${:word_statistics_option}"
    if {${:word_statistics_option} eq "word_cloud"} {
      # stopword list based on lucene, added a few more terms
      set stopWords {
        a about an and are as at be but by do does for from how if in into is it no not of on or
        such that the their then there these they this to vs was what when where who will with
      }
      set jsWords {}
      foreach {word freq} [lsort -decreasing -integer -stride 2 -index 1 ${:word_statistics}] {
        if {$word in $stopWords} continue
        lappend jsWords [subst {{text: "$word", weight: $freq}}]
      }
      set tsp [clock clicks -microseconds]
      set height [expr {(12*[llength $jsWords]/10)  + 250}]
      # set js [subst {
      #   var jqcloud_$tsp = \[
      #   [join $jsWords ",\n"]
      #   \];
      #   \$('#jqcloud_$tsp').jQCloud(jqcloud_$tsp, {autoResize: true, width: 500, steps: 5, height: $height});
      # }]
      set js [subst {
        var jqcloud_$tsp = \[
        [join $jsWords ",\n"]
        \];
        \$('#jqcloud_$tsp').jQCloud(jqcloud_$tsp, {autoResize: true, width: 500, height: $height});
      }]
      template::add_script -order 20 -src https://cdn.jsdelivr.net/npm/jqcloud2@2.0.3/dist/jqcloud.min.js
      template::head::add_css -href https://cdn.jsdelivr.net/npm/jqcloud2@2.0.3/dist/jqcloud.min.css
      security::csp::require script-src https://cdn.jsdelivr.net
      security::csp::require style-src  https://cdn.jsdelivr.net

      template::add_body_script -script $js
      ::html::div -class "jq-cloud" -id jqcloud_$tsp  {}
    } else {
      ::html::ul {
        foreach {word freq} [lsort -decreasing -integer -stride 2 -index 1 ${:word_statistics}] {
          html::li { html::t "$freq: $word" }
          lappend jsWords [subst {{text: "$word", weight: $freq}}]
        }
      }
    }
  }

  FormField instproc render_collapsed {-id:required {-label ""} -inner_method} {
    template::add_script -src urn:ad:js:bootstrap3
    set num [clock clicks -microseconds]
    ::html::button -type button -class "btn btn-xs" -data-toggle "collapse" -data-target "#$id" {
      ::html::span -class "glyphicon glyphicon-chevron-down" {::html::t $label}
    }
    ::html::div -id "$id" -class "collapse" {
      :$inner_method
    }
  }

  FormField instproc render_modal {-id:required {-label ""} -inner_method} {
    ::html::button -type button -class "btn btn-xs" -data-toggle "modal" -data-target "#$id" {
      ::html::span -class "glyphicon glyphicon-chevron-down" {::html::t $label}
    }
    ::html::div -id "$id" -class "modal fade" -tabindex -1 -role dialog aria-hidden "true" {
      ::html::div -class "modal-dialog" -role document {
        ::html::div -class "modal-content" {
          ::html::div -class "modal-header" {
            ::html::h5 -class "modal-title" { ::html::t $label }
            ::html::button -type "button" -class "close" -data-dismiss "modal" -aria-label "Close" {
              ::html::span -aria-hidden "true" { ::html::t -disableOutputEscaping "&times;" }
            }
            ::html::div -class "modal-body" {
              #::html::t ...
              :$inner_method
            }
            ::html::div -class "modal-footer" {
              ::html::button -type "button" -class "btn btn-secondary" -data-dismiss "modal" {
                ::html::t Close
              }
            }
          }
        }
      }
    }
  }

  FormField instproc render_result_statistics {} {
    #
    # In case, there are result_statistics, use a "progress bar" to
    # visualize correct answers.
    #
    # Currently, this is bootstrap3 only.
    #
    if {[info exists :result_statistics] && [dict exists ${:result_statistics} count]} {
      set result_count [dict get ${:result_statistics} count]
      #ns_log notice "??? render_result_statistics: ${:name}: ${:result_statistics}"
      if {$result_count > 0} {
        ::html::div -class "progress" {
          set correctCount [expr {[dict exists ${:result_statistics} correct] ? [dict get ${:result_statistics} correct] : 0}]
          set percentage [format %2.0f [expr {$correctCount * 100.0 / $result_count}]]
          ::html::div -class "progress-bar progress-bar-success" -role "progressbar" \
              -aria-valuenow $percentage -aria-valuemin "0" -aria-valuemax "100" -style "width:$percentage%" {
                ::html::t "$percentage %"
              }
        }
      }
    }
    if {[info exists :answer_statistics]} {
      :render_collapsed \
          -id answers-[clock clicks -microseconds] \
          -label "#xowiki.answers#" \
          -inner_method render_answer_statistics
    }
    if {[info exists :word_statistics]} {
      ns_log notice ":word_statistics: ${:word_statistics}"
      if {${:word_statistics_option} eq "word_cloud"} {
        :render_modal \
            -id words-[clock clicks -microseconds] \
            -label "#xowiki.words#" \
            -inner_method render_word_statistics
      } else {
        #
        # The following is not used for the word cloud, since the
        # placement of the words in the word cloud does not work in
        # collapsed mode.
        #
        :render_collapsed \
            -id words-[clock clicks -microseconds] \
            -label "#xowiki.words#" \
            -inner_method render_word_statistics
      }
    }
  }

  FormField instproc render_disabled_as_div {CSSclass} {
    set attributes [:get_attributes id]
    lappend attributes class $CSSclass
    ::html::div $attributes {
      if {[info exists :value_with_markup]} {
        ::html::t -disableOutputEscaping ${:value_with_markup}
      } else {
        ::html::t [:value]
      }
    }
  }

  FormField instproc set_is_repeat_template {is_template} {
    # :msg "${:name} set is_repeat_template $is_template"
    if {$is_template} {
      set :is_repeat_template true
    } else {
      unset :is_repeat_template
    }
  }

  FormField instproc field_value {v} {
    if {[info exists :show_raw_value]} {
      return $v
    } else {
      return [:pretty_value $v]
    }
  }

  FormField instproc pretty_image {-parent_id:required {-revision_id ""} entry_name} {
    if {$entry_name eq "" || ${:value} eq ""} return

    array set "" [${:object} item_ref -default_lang [${:object} lang] -parent_id $parent_id $entry_name]

    set label ${:label} ;# the label is used for alt and title
    if {$label eq $(stripped_name)} {
      #
      # The label is apparently the default. For Photo.form instances,
      # this is always "image". In such cases, use the title of the
      # parent object as label.
      #
      set label [${:object} title]
    }
    set l [::xowiki::Link create new -destroy_on_cleanup \
               -page ${:object} -type "image" -lang $(prefix) \
               -stripped_name $(stripped_name) -label $label \
               -parent_id $(parent_id) -item_id $(item_id)]

    if {[:istype file]} {
      if {$revision_id ne ""} {
        $l revision_id $revision_id
      }
    }

    foreach option {
      href cssclass
      float width height
      padding padding-right padding-left padding-top padding-bottom
      margin margin-left margin-right margin-top margin-bottom
      border border-width position top bottom left right
      geometry
    } {
      if {[info exists :$option]} {$l set $option [set :$option]}
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
    # Search for the slot. If the slot exists, extend its default
    # value with the new value
    foreach c [:info heritage] {
      if {[nsf::is object ${c}::slot::$name]} {
        set value [list $value {*}[${c}::slot::$name default]]
        break
      }
    }
    # create a mirroring slot with the maybe extended default
    :slots [list Attribute create $name -default $value]
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
    #:msg "check compound in ${:components}"
    foreach c ${:components} {
      set error [$c validate [self]]
      if {$error ne ""} {
        set msg "[$c label]: $error"
        :uplevel [list set errorMsg $msg]
        #util_user_message -message "Error in compound field [$c name]: $error"
        return 0
      }
    }
    return 1
  }

  CompoundField instproc set_disabled {disable} {
    #:msg "${:name} set disabled $disable"
    if {$disable} {
      set :disabled true
    } else {
      :unset -nocomplain disabled
    }
    foreach c ${:components} {
      $c set_disabled $disable
    }
  }

  CompoundField instproc set_is_repeat_template {is_template} {
    # :msg "${:name} set is_repeat_template $is_template"
    if {$is_template} {
      set :is_repeat_template true
    } else {
      :unset -nocomplain is_repeat_template
    }
    foreach c ${:components} {
      $c set_is_repeat_template $is_template
    }
  }

  CompoundField instproc same_value {v1 v2} {
    if {$v1 eq $v2} {return 1}
    foreach {n1 value1} $v1 {n2 value2} $v2  {
      set f [set :component_index($n1)]
      if {![$f same_value $value1 $value2]} { return 0 }
    }
    return 1
  }

  CompoundField instproc value {value:optional} {
    if {[info exists value]} {
      #:msg "${:name}: setting compound value => '$value'"
      :set_compound_value $value
    }
    return [:get_compound_value]
  }

  CompoundField instproc object args {
    set l [llength $args]
    switch $l {
      0 {
        #
        # Called without args, return the current value
        #
        return ${:object}
      }
      1 {
        #
        # Called with a single value, set object for all components
        #
        foreach c ${:components} {
          $c object [lindex $args 0]
        }

        set :object [lindex $args 0]
      }
      default {
        error "wrong number of arguments"
      }
    }
  }

  CompoundField instproc validate {obj} {
    # Delegate validate to the components. If a validation of a
    # component fails, report the error message back.
    foreach c ${:components} {
      set result [$c validate $obj]
      #ns_log notice "CompoundField validate on [$c name] returns '$result' [info exists errorMsg]"
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
    foreach c ${:components} {
      # Set only those parts, for which attribute values pairs are
      # given.  Components might have their own default values, which
      # we do not want to overwrite ...
      if {[info exists ([$c name])]} {
        $c value $([$c name])
      }
    }
  }

  CompoundField instproc get_compound_value {} {
    #
    # Set the internal representation based on the components values.
    #
    set cc [[${:object} package_id] context]

    set value [list]
    foreach c ${:components} {
      lappend value [$c name] [$c value]
    }
    #:log "${:name}: get_compound_value returns value=$value"
    return $value
  }

  CompoundField instproc specs_unmodified {spec_list} {
    expr {${:__state} eq "after_specs"
          && [info exists :structure] && ${:structure} eq $spec_list
        }
  }

  CompoundField instproc create_components {spec_list} {
    #:log "create_components $spec_list"

    #
    # Omit after specs for compound fields to avoid multiple
    # recreations.
    #
    if {[:specs_unmodified $spec_list]} {
      return
    }

    #
    # Build a component structure based on a list of specs
    # of the form {name spec}.
    #
    set :structure $spec_list
    set :components [list]
    foreach entry $spec_list {
      #:log "create_components creates $entry"
      lassign $entry name spec
      #
      # create for each component a form field
      #
      set c [::xowiki::formfield::FormField create [self]::$name \
                 -name ${:name}.$name -id ${:id}.$name \
                 -locale [:locale] -object ${:object} \
                 -spec $spec]
      set :component_index(${:name}.$name) $c
      $c set parent_field [self]
      lappend :components $c
    }
  }

  CompoundField instproc add_component {entry} {
    #
    # Add a single component dynamically to the list of already
    # existing components and return the component as result.
    #
    lappend :structure $entry
    lassign $entry name spec
    set c [::xowiki::formfield::FormField create [self]::$name \
               -name ${:name}.$name -id ${:id}.$name \
               -locale [:locale] -object ${:object} \
               -spec $spec]
    set :component_index(${:name}.$name) $c
    lappend :components $c
    return $c
  }

  CompoundField instproc get_component {component_name} {
    set key component_index(${:name}.$component_name)
    if {[info exists :$key]} {
      return [set :$key]
    }
    error "no component named $component_name of compound field ${:name}"
  }

  CompoundField instproc named_sub_components {} {
    # Iterate along the argument list to check components of a deeply
    # nested structure.
    set component_names [array names :component_index]
    foreach c ${:components} {
      lappend component_names {*}[$c array names component_index]
    }
    return $component_names
  }

  CompoundField instproc exists_named_sub_component args {
    # Iterate along the argument list to check components of a deeply
    # nested structure. For example,
    #
    #    :check_named_sub_component a b
    #
    # returns 0 or one depending whether there exists a component "a"
    # with a subcomponent "b".
    set component_name ${:name}
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
    #    :get_named_sub_component a b
    #
    # returns the object of the subcomponent "b" of component "a"
    set component_name ${:name}
    set sub [self]
    foreach e $args {
      append component_name .$e
      #:msg "check $sub set component_index($component_name)"
      set sub [$sub set component_index($component_name)]
    }
    return $sub
  }

  CompoundField ad_instproc get_named_sub_component_value {
    {-from_repeat:switch}
    {-default ""}
    args
  } {

    Return the value of a named sub-component. When the named
    sub-component is a repeated item, and the value of the 0th element
    of the repeat (the template element) is omitted from the returned
    value.

    @param from_repeat skip template element from repeated values
    @param default default value, when component is not found
    @param args space separated path of elements names in a potentially
           nested component structure (similar to dict)
    @result value of the component
  } {
    if {[:exists_named_sub_component {*}$args]} {
      set result [[:get_named_sub_component {*}$args] value]
      if {$from_repeat} {
        if {[lindex [split [lindex $result 0] .] end] eq "0"} {
          set result [lrange $result 2 end]
        }
      }
    } else {
      set result $default
    }
    return $result
  }

  CompoundField instproc generate_fieldnames {{-prefix "v-"} n} {
    set names [list]
    for {set i 1} {$i <= $n} {incr i} {lappend names $prefix$i}
    return $names
  }

  CompoundField instproc leaf_components {} {
    set leaf_components {}
    foreach c ${:components} {
      if {[self class] in [[$c info class] info heritage]} {
        lappend leaf_components {*}[$c leaf_components]
      } else {
        lappend leaf_components $c
      }
    }
    return $leaf_components
  }

  CompoundField instproc render_input {} {
    #
    # Render content within in a fieldset, but with labels etc.
    #
    html::fieldset [:get_attributes id {CSSclass class}] {
      foreach c ${:components} { $c render }
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
    foreach c [lsort ${:components}] {
      set componentName [$c set name]
      if {[dict exists $ff $componentName]} {
        set componentLabel [string range $componentName [string length ${:name}]+1 end]
        append html "<li><span class='name'>$componentLabel:</span> " \
            "[$c pretty_value [dict get $ff $componentName]]</li>\n"
      }
    }
    append html "</ul>\n"
    return $html
  }

  CompoundField instproc has_instance_variable {var value} {
    set r [next]
    if {$r} {return 1}
    foreach c ${:components} {
      set r [$c has_instance_variable $var $value]
      if {$r} {return 1}
    }
    return 0
  }

  CompoundField instproc convert_to_internal {} {
    foreach c ${:components} {
      $c convert_to_internal
    }
    # Finally, update the compound value entry with the compound
    # internal representation; actually we could drop the instance
    # atts of the components from the "instance_attributes" ...
    ${:object} set_property -new 1 ${:name} [:get_compound_value]
  }

  CompoundField instproc make_correct {} {
    foreach c ${:components} {
      $c make_correct
    }
  }
  CompoundField instproc add_statistics {{-options ""}} {
    foreach c ${:components} {
      $c add_statistics -options $options
    }
  }

  ###########################################################
  #
  # ::xowiki::formfield::submit_button
  #
  ###########################################################

  Class create submit_button -superclass FormField
  submit_button  instproc initialize {} {
    set :type submit
    set :value [::xo::localize [_ xowiki.Form-submit_button]]
  }
  submit_button instproc render_input {} {
    # don't disable submit buttons
    if {[:type] eq "submit"} {:unset -nocomplain disabled}
    ::html::button [:get_attributes name type {form_button_CSSclass class} title disabled] {
      ::html::t ${:value}
    }
    #::html::input [:get_attributes name type {form_button_CSSclass class} value title disabled] {}
    :render_localizer
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
        {viruscheck:boolean true}
        {sticky:boolean false}
        {searchable:boolean false}
        {multiple:boolean false}
        link_label
      }
  file instproc check=virus {value} {
    # In case of an upgrade script, the (uploaded) tmp file might not exist
    if {[:viruscheck]
        && [info exists :tmpfile]
        && $value ne ""
        && [::file exists ${:tmpfile}]
        && [::xowiki::virus check ${:tmpfile}]
      } {
      #util_user_message -message "uploaded file contains a virus; upload rejected"
      return 0
    }
    return 1
  }
  file instproc tmpfile {value}      {:set [self proc] $value}
  file instproc content-type {value} {:set [self proc] $value}
  file instproc initialize {} {
    :type file
    set :booleanHTMLAttributes {multiple}
    set :widget_type file(file)
    next
  }
  file instproc entry_info {} {
    if {${:multiple}} {
      if {[info exists :tmpfile]} {
        set list ${:tmpfile}
      } else {
        set list [:get_from_value ${:value} name]
      }
      set objName {}
      for {set i 0} {$i < [llength $list]} {incr i} {
        lappend objName file:${:name}___$i
      }
    } else {
      set objName file:${:name}
    }
    #:log ENTRY_INFO=[list name $objName parent_id [${:object} item_id]]
    return [list name $objName parent_id [${:object} item_id]]
  }

  file instproc get_from_value {value attribute {raw ""}} {
    #
    # The value of a form entry might be:
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
    expr {${:value} eq ""}
  }

  file instproc get_old_value {} {
    return [${:object} form_parameter __old_value_${:name} ""]
  }

  file instproc value {args} {
    if {[llength $args] == 0} {
      if {[:no_value_provided]} {
        return [:get_old_value]
      }
      return ${:value}
    }
    return [next]
  }

  file instproc store_file {
    -file_name
    -content_type
    -package_id
    -parent_id
    -object_name
    -tmpfile
    -publish_date_cmd
    -save_flag
  } {

    set content_type_registered [::xo::dc get_value check_content_type {
      select exists(select 1 from cr_mime_types where mime_type = :content_type)
    }]
    #
    # If the provided mime type is not registered, or unknown, try
    # to look it up via the file extension.
    #
    if {!$content_type_registered
        || $content_type in { application/octetstream application/force-download }
      } {
      set content_type [::xowiki::guesstype $file_name]
      #
      # Here, the mime type could sill be an unknown/unregistered
      # one. We could check, whether this mime type is registered. If
      # not, we could add it on the fly or we could map it to the
      # registered unknown type (maybe via package parameter of
      # acs-content-repository + a new API call).
      #
    }

    set file_object [::$package_id get_page_from_name -name $object_name -parent_id $parent_id]
    if {$file_object ne ""} {
      #
      # File entry exists already, create a new revision
      #
      #:msg "new revision (value $file_name)"
      $file_object set import_file $tmpfile
      $file_object set mime_type $content_type
      $file_object set title $file_name
      eval $publish_date_cmd
      $file_object save {*}$save_flag
    } else {
      #
      # Create a new file
      #
      #:msg "new file"
      set package_id [${:object} package_id]
      set file_object [::xowiki::File new -destroy_on_cleanup \
                           -title $file_name \
                           -name $object_name \
                           -parent_id $parent_id \
                           -mime_type $content_type \
                           -package_id $package_id \
                           -creation_user [::xo::cc user_id] ]
      $file_object set import_file $tmpfile
      eval $publish_date_cmd
      #
      # When produduction_mode is set, make sure, the new file object
      # is not in a published state.
      #
      if {[::$package_id get_parameter production_mode 0]} {
        $file_object publish_status "production"
      }
      $file_object save_new {*}$save_flag
    }
    return $file_object
  }


  file instproc convert_to_internal {} {

    if {[:no_value_provided] || ![info exists :content-type]} {
      ${:object} set_property -new 1 ${:name} [:get_old_value]
      return
    }
    #:log "${:name}: got value '${:value}'"
    #${:object} set_property -new 1 ${:name} ${:value}

    set package_id [${:object} package_id]
    set entry_info [:entry_info]

    if {[:searchable]} {
      set publish_date_cmd {;}
      set save_flag ""
    } else {
      set publish_date_cmd {$file_object set publish_date "9999-12-31 23:59:59.0+01"}
      set save_flag "-use_given_publish_date true"
    }

    #
    # Make sure that we do not mis-interprete spaces in paths or file
    # names.
    #
    if {[llength ${:content-type}] == 1} {
      set :tmpfile [list ${:tmpfile}]
      set :value [list ${:value}]
    }

    set revision_ids {}
    set newValue ""
    foreach content_type ${:content-type} \
        object_name [dict get $entry_info name] \
        tmpfile ${:tmpfile} \
        fn ${:value} {

          regsub -all {\\+} $fn {/} fn  ;# fix IE upload path
          set fn [::file tail ./$fn]    ;# prefix $fn to avoid potential tilde expansion

          set file_object [:store_file \
                               -file_name $fn \
                               -content_type $content_type \
                               -package_id $package_id \
                               -parent_id [dict get $entry_info parent_id] \
                               -object_name $object_name \
                               -tmpfile $tmpfile \
                               -publish_date_cmd $publish_date_cmd \
                               -save_flag $save_flag]

          lappend revision_ids [$file_object revision_id]
          lappend newValue $fn
        }

    #
    # Update the value with the attribute value pair list containing
    # the revision_id. TODO: clear revision_id on export.
    #
    set newValue [list name $newValue revision_id $revision_ids]
    ${:object} set_property -new 1 ${:name} $newValue
    set :value $newValue
  }

  file instproc label_or_value {v} {
    if {[info exists :link_label]} {
      return [:localize [:link_label]]
    }
    return $v
  }

  file instproc pretty_value {v} {
    if {$v ne ""} {
      set entry_info [:entry_info]

      set result ""
      foreach object_name [dict get $entry_info name] fn [:get_from_value $v name] {

        set item_info [${:object} item_ref \
                           -default_lang [${:object} lang] \
                           -parent_id [dict get $entry_info parent_id] \
                           $object_name]

        #:log "name <$object_name> pretty value name '[dict get $item_info stripped_name]'"

        set l [::xowiki::Link new -destroy_on_cleanup \
                   -page ${:object} -type "file" \
                   -lang [dict get $item_info prefix] \
                   -stripped_name [dict get $item_info stripped_name] \
                   -label $fn \
                   -extra_query_parameter [list [list filename $fn]] \
                   -parent_id [dict get $item_info parent_id] \
                   -item_id [dict get $item_info item_id]]
        append result [$l render]
      }
      return $result
    }
  }

  file instproc render_input {} {

    set package_id [${:object} package_id]
    set entry_info [:entry_info]
    set fns [:get_from_value ${:value} name ${:value}]

    #
    # The HTML5 handling of "required" would force us to upload in
    # every form the file again. To implement the sticky option, we
    # set temporarily the "required" attribute to false
    #
    if {${:required}} {
      set reset_required 1
      set :required false
    }
    next

    ::html::t " "
    set id __old_value_${:name}
    ::html::div {
      ::html::input -type hidden -name $id -id $id -value ${:value}
    }
    ::html::div -class file-control -id __a$id {
      foreach \
          object_name [dict get $entry_info name] \
          revision_id [:get_from_value ${:value} revision_id ""] \
          fn $fns {
            #:msg "${:name}: [list :get_from_value <${:value}> name] => '$fn'"
            set href [::$package_id pretty_link -download 1 \
                          -parent_id [dict get $entry_info parent_id] \
                          $object_name]

            if {![:istype image]} {
              append href ?filename=[ns_urlencode $fn]
              if {$revision_id ne ""  && [string is integer $revision_id]} {
                append href &revision_id=$revision_id
              }
            }

            if {[info exists reset_required]} {
              set :required true
            }
            ::html::div {
              ::html::a -href $href {::html::t [:label_or_value $fn] }
            }
          }
      #
      # Show the clear button just when
      # - there is something to clear, and
      # - the formfield is not disabled, and
      # - the form-field is not sticky (default)
      #
      set disabled [:is_disabled]
      if {${:value} ne "" && !$disabled && ![:sticky] } {
        ::html::input -type button -value [_ xowiki.clear] -id $id-control
        template::add_event_listener \
            -id $id-control \
            -script [subst {document.getElementById('$id').value = ''; document.getElementById('__a$id').style.display = 'none';}]

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
    if {${:help_text} eq ""} {
      set :help_text "#xowiki.formfield-import_archive-help_text#"
    }
  }
  import_archive instproc pretty_value {v} {
    set package_id [${:object} package_id]
    set parent_id  [${:object} parent_id]
    if {$v eq ""} {return ""}
    set entry_info [:entry_info]
    set fn [:get_from_value $v name $v]
    #
    # Get the file object of the imported file to obtain is full name and path
    #
    set file_id [::$package_id lookup \
                     -parent_id [${:object} item_id] \
                     -name      [dict get $entry_info name]]
    ::xo::db::CrClass get_instance_from_db -item_id $file_id
    set full_file_name [::$file_id full_file_name]
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
      if {[:cleanup]} {
        set return_url [::$package_id query_parameter \
                            "return_url:localurl" \
                            [::$parent_id pretty_link]]
        ::$package_id returnredirect [${:object} pretty_link \
                                          -query [export_vars {m delete} return_url]]
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
    border border-width position top bottom left right
  }
  image instproc pretty_value {v} {
    set html ""
    set entry_info [:entry_info]
    foreach object_name [dict get $entry_info name] revision_id [:get_from_value $v revision_id] {
      append html [:pretty_image \
                       -parent_id [dict get $entry_info parent_id] \
                       -revision_id $revision_id \
                       $object_name]
    }
    return $html
  }

  ###########################################################
  #
  # ::xowiki::formfield::hidden
  #
  ###########################################################

  Class create hidden -superclass FormField -parameter {
    {sign:boolean false}
    {max_age:integer}
  } -extend_slot_default validator signature
  hidden instproc initialize {} {
    :type hidden
    set :widget_type text(hidden)
    # remove mixins in case of retyping
    :mixin ""
    if {[info exists :size]} {:unset size}
  }
  hidden instproc render_item {} {
    # don't render the labels
    if {[info exists :sign] && ${:sign}} {
      set token_id [sec_get_random_cached_token_id]
      set secret [ns_config "ns/server/[ns_info server]/acs" parametersecret ""]
      if {[info exists :max_age]} {
        set max_age [:max_age]
      } else {
        set max_age ""
      }
      set value [:value]
      set sig [ad_sign -max_age $max_age -secret $secret -token_id $token_id $value]
      ::html::div {
        ::html::input -name ${:name} -value $value -type hidden
        ::html::input -name __${:name}:sig -value $sig -type hidden
      }
    } else {
      :render_form_widget
    }
  }
  hidden instproc check=signature {value} {
    set v 1
    if {[info exists :sign] && ${:sign}} {
      set sig [::xo::cc form_parameter __${:name}:sig]
      set secret  [ns_config "ns/server/[ns_info server]/acs" parametersecret ""]
      set v [ad_verify_signature -secret $secret $value $sig]
      ns_log notice "==== we have sig <$sig> val $v"
    }
    return $v
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
    #:render_form_widget
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
    :type hidden
    set :widget_type text(inform)
  }
  inform instproc render_input {} {
    ::html::t [:value]
    ::html::input [:get_attributes type id name value disabled autocomplete {CSSclass class}] {}
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
    :type text
    set :widget_type text
    foreach p [list size maxlength] {if {[info exists :$p]} {set :html($p) [:$p]}}
  }
  text instproc render_input {} {
    if {[:is_disabled] && [info exists :disabled_as_div]} {
      :render_disabled_as_div text
    } else {
      next
    }
  }
  text instproc add_statistics {{-options ""}} {
    next
    if {[dict exists $options word_statistics]} {
      :word_statistics [dict get $options word_statistics]
    }
  }

  ###########################################################
  #
  # ::xowiki::formfield::correct_when
  #
  ###########################################################

  Class create correct_when -superclass text \
      -extend_slot_default validator valid_predicate

  correct_when instproc check=valid_predicate {value} {
    set predicate [lindex $value 0]
    if {$predicate ne ""} {
      set valid [expr {[:info methods answer_check=$predicate] ne ""}]
      if {!$valid} {
        :uplevel [list set errorMsg "invalid predicate $predicate"]
      }
    } else {
      set valid 1
    }
    return $valid
  }

  correct_when instproc initialize {} {
    next
    if {${:help_text} eq ""} {
      set :help_text "#xowiki.formfield-correct_when-help_text#"
    }
  }

  ###########################################################
  #
  # ::xowiki::formfield::color
  #
  ###########################################################

  Class create color -superclass text
  color instproc initialize {} {
    next
    :type color
  }

  ###########################################################
  #
  # ::xowiki::formfield::datetime
  #
  ###########################################################

  Class create datetime -superclass text
  datetime instproc initialize {} {
    next
    :type datetime
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
    :type date
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
    :type time
  }


  ###########################################################
  #
  # ::xowiki::formfield::datetime-local
  #
  ###########################################################

  Class create datetime-local -superclass text
  datetime-local instproc initialize {} {
    next
    :type datetime-local
  }

  ###########################################################
  #
  # ::xowiki::formfield::time
  #
  ###########################################################

  Class create time -superclass text
  time instproc initialize {} {
    next
    :type time
  }

  ###########################################################
  #
  # ::xowiki::formfield::week
  #
  ###########################################################

  Class create week -superclass text
  week instproc initialize {} {
    next
    :type datetime
  }

  ###########################################################
  #
  # ::xowiki::formfield::email
  #
  ###########################################################

  Class create email -superclass text
  email instproc initialize {} {
    next
    :type email
  }

  ###########################################################
  #
  # ::xowiki::formfield::search
  #
  ###########################################################

  Class create search -superclass text
  search instproc initialize {} {
    next
    :type search
  }
  ###########################################################
  #
  # ::xowiki::formfield::tel
  #
  ###########################################################

  Class create tel -superclass text
  tel instproc initialize {} {
    next
    :type tel
  }

  ###########################################################
  #
  # ::xowiki::formfield::number
  #
  ###########################################################

  Class create number -superclass FormField -parameter {
    min max step value
    {td_CSSclass right}
  }
  number instproc initialize {} {
    :type number
    set :widget_type text
  }
  number instproc render_input {} {
    set boolean_atts [:booleanAttributes required readonly disabled \
                          formnovalidate autofocus]
    ::html::input [:get_attributes type id name value {CSSclass class} \
                       min max step autocomplete placeholder {*}$boolean_atts] {}
    :resetBooleanAttributes $boolean_atts
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
    :type range
    set :widget_type text
  }
  range instproc render_input {} {
    ::html::input [:get_attributes type id name value disabled {CSSclass class} min max step value \
                       autofocus autocomplete formnovalidate multiple pattern placeholder readonly required] {}
  }

  ###########################################################
  #
  # ::xowiki::formfield::password
  #
  ###########################################################

  Class create password -superclass text
  password instproc initialize {} {
    next
    set :widget_type password
    :type password
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
    set :widget_type numeric
    # check, if we have an integer format
    set :is_integer [regexp {%[0-9.]*d} ${:format}]
  }
  numeric instproc convert_to_external value {
    if {$value eq ""} {
      set result ""
    } else {
      ad_try {
        return [lc_numeric $value ${:format} [:locale]]
      } on error errorMsg {
        util_user_message -message "${:label}: $errorMsg (locale=[:locale])"
      }
      #
      # try again
      #
      set converted_value $value
      ad_try {
        scan $value ${:format} result
      } on error {errMsg} {
        set result $value
      }
    }
    return $result
  }
  numeric instproc convert_to_internal {} {
    if {[:value] ne ""} {
      set value [lc_parse_number [:value] [:locale] ${:is_integer}]
      ${:object} set_property -new 1 ${:name} [expr {$value}]
      return
    }
  }
  numeric instproc check=numeric {value} {
    return [expr {[catch {lc_parse_number $value [:locale] ${:is_integer}}] == 0}]
  }
  numeric instproc pretty_value value {
    return [:convert_to_external $value]
  }
  numeric instproc answer_check=eq {} {
    # use numeric equality
    return [expr {[:value] == [lindex ${:correct_when} 1]}]
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
    set :is_party_id 1
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
    {with_gravatar true}
    {with_user_link false}
    {label #xowiki.formfield-author#}
  }
  author instproc pretty_value {v} {
    if {$v ne ""} {
      acs_user::get -user_id $v -array user
      if {${:with_photo}} {
        set portrait_id [acs_user::get_portrait_id -user_id $v]
        if {$portrait_id == 0 && ${:with_gravatar}} {
          set src [::xowiki::includelet::gravatar url \
                       -email $user(email) -size ${:photo_size}]
        } else {
          set src "/shared/portrait-bits.tcl?user_id=$v"
        }
        set photo "<img width='[:photo_size]' class='photo' src='[ns_quotehtml $src]'>"
        set photo_class "photo"
      } else {
        set photo ""
        set photo_class ""
      }
      set date_field [::xowiki::FormPage get_table_form_fields \
                          -base_item ${:object} \
                          -field_names _last_modified \
                          -form_constraints ""]
      set date [$date_field pretty_value [${:object} property _last_modified]]

      if {[:with_user_link]} {
        set user_link_begin "<a href='[ns_quotehtml /shared/community-member?user_id=$v]'>"
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
    :type url
  }
  url instproc pretty_value {v} {
    if {$v ne ""} {
      if {[info exists :link_label]} {
        set link_label [:localize [:link_label]]
      } else {
        set link_label $v
      }
      regsub -all & $v "&amp;" v
      return "<a href='[ns_quotehtml $v]'>$link_label</a>"
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
      set link_label [:localize [:link_label]]
      regsub -all & $v "&amp;" v
      return " <span class='more'>\[ <a href='[ns_quotehtml $v]'>$link_label</a> \]</span>"
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
    {autosave:boolean false}
  }
  textarea instproc initialize {} {
    set :widget_type text(textarea)
    set :booleanHTMLAttributes {required readonly disabled formnovalidate}
    foreach p [list rows cols style] {
      if {[info exists :$p]} {set :html($p) [:$p]}
    }
    if {![:istype ::xowiki::formfield::richtext] && [info exists :editor]} {
      # downgrading
      #:msg "downgrading [:info class]"
      foreach m [:info mixin] {if {[$m exists editor_mixin]} {:mixin delete $m}}
      foreach v {editor options} {if {[info exists :$v]} {:unset $v}}
    }
    if {${:autosave}} {
      ::xo::Page requireJS  "/resources/xowiki/autosave-text.js"
    }
    next
  }

  textarea instproc render_input {} {
    if {[:is_disabled] && [info exists :disabled_as_div]} {
      :render_disabled_as_div textarea
    } else {
      set booleanAtts [:booleanAttributes {*}${:booleanHTMLAttributes}]
      if {${:autosave}} {
        ::html::div -class "autosave" {
          ::html::div -id ${:id}-status \
              -class "nochange" \
              -data-saved #xowiki.autosave_saved# \
              -data-pending #xowiki.autosave_pending# {
                ::html::t "" ;#"no change"
              }
          ::html::textarea [:get_attributes id name cols rows style wrap placeholder \
                                data-repeat-template-id {CSSclass class} \
                                {*}$booleanAtts] {
                                  ::html::t [:value]
                                }
        }
        template::add_event_listener \
            -id ${:id} \
            -event keyup \
            -preventdefault=false \
            -script "autosave_handler('${:id}');"

      } else {
        ::html::textarea [:get_attributes id name cols rows style wrap placeholder \
                              data-repeat-template-id {CSSclass class} \
                              {*}$booleanAtts] {
                                ::html::t [:value]
                              }
      }
      :resetBooleanAttributes $booleanAtts
    }
    :render_result_statistics
  }

  textarea instproc set_feedback {feedback_mode} {
    set :correction [next]
    return ${:correction}
  }

  textarea instproc add_statistics {{-options ""}} {
    #:log "add_statistics $options"
    next
    if {[dict exists $options word_statistics]} {
      #:log "add_statistics call :word_statistics"
      :word_statistics [dict get $options word_statistics]
    }
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
    ${:object} do_substitutions 0
    if {[info commands ::apidoc::tclcode_to_html] ne ""} {
      set html [::apidoc::tclcode_to_html [:value]]
      regsub -all "\n?\r</FONT></EM>" $html </FONT></EM> html
      return "<pre class='code'>$html</pre>"
    } else {
      return "<pre class='code'>[string map [list & {&amp;} < {&lt;} > {&gt;}]  [:value]]</pre>"
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
    #:msg "setting editor for ${:name}, args=$args,[llength $args]"
    if {[llength $args] == 0} {return ${:editor}}
    set editor [lindex $args 0]
    if {[info exists :editor] && $editor eq ${:editor} && [info exists :__initialized]} return

    set editor_class [self class]::$editor
    if {$editor ne "" && ![:hasclass $editor_class]} {
      if {![:isclass $editor_class]} {
        set editors [list]
        foreach c [::xowiki::formfield::richtext info subclass] {
          if {![$c exists editor_mixin]} continue
          lappend editors [namespace tail $c]
        }
        error [_ xowiki.error-form_constraint-unknown_editor \
                   [list name ${:name} editor [:editor] editors $editors]]
      }
      foreach m [:info mixin] {if {[$m exists editor_mixin]} {:mixin delete $m}}
      :mixin add $editor_class
      #:msg "MIXIN $editor: [:info precedence]"
      :reset_parameter
      set :__initialized 1
    }
    set :editor $editor
  }

  richtext instproc initialize {} {
    #set :display_field false
    switch -- ${:displayMode} {
      inplace -
      inline -
      standard {}
      default {error "value '${:displayMode}' invalid: valid entries for displayMode are inplace, inline or standard (default)"}
    }
    #
    # Don't set HTML5 attribute "required", since this does not match
    # well with Richtext Editors (at least ckeditor4 has problems,
    # other probably as well).
    #
    set :booleanHTMLAttributes {readonly disabled formnovalidate}
    next
    #ns_log notice "==== ${:name} EDITOR specified? [info exists :editor]"
    if {![info exists :editor]} {
      set :editor [parameter::get_global_value -package_key xowiki \
                       -parameter PreferredRichtextEditor -default ckeditor4]
      #:msg "setting default of ${:name} to ${:editor}"
    }
    if {![info exists :__initialized]} {
      #
      # Mixin the editor based on the attribute 'editor' if necessary
      # and call initialize again in this case...
      #
      #ns_log notice "==== initializing EDITOR: ${:editor}"
      :editor ${:editor}
      :initialize
    }
  }

  richtext instproc render_richtext_as_div {} {
    #:msg "[:get_attributes id style {CSSclass class}]"
    ::html::div [:get_attributes id style {CSSclass class}] {
      if {[:wiki]} {
        ${:object} references clear
        ::html::t -disableOutputEscaping [${:object} substitute_markup [:value]]
      } else {
        ::html::t -disableOutputEscaping [:value]
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
      :uplevel [list set errorMsg $msg]
      return 0
    }
    return 1
  }
  richtext instproc pretty_value {v} {
    # for richtext, perform minimal output escaping
    if {[:wiki]} {
      return [${:object} substitute_markup $v]
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
  #    This formfield class is deprecated, use richtext::ckeditor4
  #    instead.
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
    {extraPlugins "xowikiimage"}
    {templatesFiles ""}
    {templates ""}
    {contentsCss /resources/xowiki/ck_contents.css}
    {imageSelectorDialog /xowiki/ckeditor-images/}
  }
  richtext::ckeditor set editor_mixin 1
  richtext::ckeditor ad_instproc -deprecated initialize {} {
  } {
    switch -- ${:displayMode} {
      inplace { append :help_text " #xowiki.ckeip_help#" }
      inline { error "inline is not supported for ckeditor v3"}
    }
    next
    set :widget_type richtext
    # Mangle the id to make it compatible with jquery; most probably
    # not optimal and just a temporary solution
    regsub -all {[.:]} ${:id} "" id
    :id $id
  }

  richtext::ckeditor instproc js_image_helper {} {
    set path [${:object} pretty_link]
    append js \
        [subst -novariables {
          function xowiki_image_callback(editor) {
            if (typeof editor != "undefined") {
              $(editor.element.$.form).submit(function(e) {
                calc_image_tags_to_wiki_image_links(this);
              });
              editor.setData(calc_wiki_image_links_to_image_tags('[set path]',editor.getData()));
            }
          }
        }] {
          function calc_image_tags_to_wiki_image_links(form) {
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

          function calc_wiki_image_links_to_image_tags(path, data) {
            var regex_wikilink = new RegExp('(\\[\\[.SELF./image:)(.*?)(\\]\\])', 'g');
            data = data.replace(regex_wikilink,'<img src="'+path+'/file:$2?m=download"  alt=".SELF./image:$2" type="wikilink"  />');
            return data
          }
        }
    ::xo::Page requireJS $js
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
    set disabled [:is_disabled]
    if {![:istype ::xowiki::formfield::richtext] || $disabled } {
      :render_richtext_as_div
    } else {
      ::xo::Page requireJS urn:ad:js:jquery
      ::xo::Page requireJS "/resources/xowiki/ckeditor/ckeditor_source.js"
      #::xo::Page requireJS "/resources/xowiki/ckeditor/ckeditor.js"
      ::xo::Page requireJS "/resources/xowiki/ckeditor/adapters/jquery.js"
      ::xo::Page requireJS urn:ad:js:jquery-ui
      ::xo::Page requireCSS urn:ad:css:jquery-ui

      # In contrary to the doc, ckeditor names instances after the id,
      # not the name.
      set id ${:id}
      set name ${:name}
      set package_id [${:object} package_id]
      #set :extraPlugins {timestamp xowikiimage}

      if {"xowikiimage" in [:extraPlugins]} {
        :js_image_helper
        set ready_callback {xowiki_image_callback(e.editor);}
      } else {
        set ready_callback "/*none*/;"
      }

      set options [subst {
        toolbar : '[:toolbar]',
        uiColor: '[:uiColor]',
        language: '[::xo::cc lang]',
        skin: '[:skin]',
        startupMode: '${:mode}',
        parent_id: '[${:object} item_id]',
        package_url: '[::$package_id package_url]',
        extraPlugins: '[join [:extraPlugins] ,]',
        contentsCss: '[:contentsCss]',
        imageSelectorDialog: '[:imageSelectorDialog]',
        ready_callback: '$ready_callback',
        customConfig: '[:customConfig]'
      }]
      if {[:templatesFiles] ne ""} {
        append options "  , templates_files: \['[join [:pathNames [:templatesFiles]] ',' ]' \]\n"
      }
      if {[:templates] ne ""} {
        append options "  , templates: '[:templates]'\n"
      }

      #set parent [[${:object} package_id] get_page_from_item_or_revision_id [${:object} parent_id]];# ???

      if {${:displayMode} eq "inplace"} {
        if {[:value] eq ""} {
          :value "&nbsp;"
        }
        :render_richtext_as_div
        if {${:inline}} {
          set wrapper_class ""
        } else {
          set wrapper_class "form-item-wrapper"
          :callback {$(this.element.$).closest('.form-widget').css('clear','both').css('display', 'block');}
          :destroy_callback {$(this).closest('.form-widget').css('clear','none');}
        }
        set callback [:callback]
        set destroy_callback [:destroy_callback]

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
        set callback [:callback]
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
    {skin "bootstrapck,/resources/xowiki/ckeditor4/skins/bootstrapck/"}
    {toolbar Full}
    {CSSclass xowiki-ckeditor}
    {uiColor ""}
    {allowedContent ""}
    {CSSclass xowiki-ckeditor}
    {customConfig "config.js"}
    {callback "/* callback code */"}
    {destroy_callback "/* callback code */"}
    {submit_callback ""}
    {extraPlugins "xowikiimage"}
    {extraAllowedContent {*(*)}}
    {ck_package standard-all}
    {templatesFiles ""}
    {templates ""}
    {contentsCss /resources/xowiki/ck_contents.css}
    {imageSelectorDialog /xowiki/ckeditor-images/}
    {additionalConfigOptions ""}
  }
  richtext::ckeditor4 set editor_mixin 1
  richtext::ckeditor4 instproc initialize {} {

    switch -- ${:displayMode} {
      inplace { append :help_text " #xowiki.ckeip_help#" }
    }
    next
    set :widget_type richtext
    # Mangle the id to make it compatible with jquery; most probably
    # not optimal and just a temporary solution
    regsub -all {[.:-]} ${:id} "" id
    :id $id
  }

  richtext::ckeditor4 instproc js_image_helper {} {
    set path [${:object} pretty_link]
    append js \
        [subst -novariables {
          function xowiki_image_callback(editor) {
            if (typeof editor != "undefined") {
              $(editor.element.$.form).submit(function(e) {
                calc_image_tags_to_wiki_image_links(this);
              });
              editor.setData(calc_wiki_image_links_to_image_tags('[set path]',editor.getData()));
            }
          }
        }] {
          function calc_image_tags_to_wiki_image_links(form) {
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

          function calc_image_tags_to_wiki_image_links_inline(e) {
            var data = $('<div>'+CKEDITOR.instances[e].getData()+'</div>');
            data.find('img[type="wikilink"]').each( function() {
              var wiki_link = $(this).attr('alt');
              $(this).replaceWith('[['+wiki_link+']]');
            });
            CKEDITOR.instances[e].setData(data.html());
            CKEDITOR.instances[e].updateElement();
          }

          function calc_wiki_image_links_to_image_tags(path, text) {
            // console.log('path = <' + path + '>');
            var regex_wikilink = new RegExp('(\\[\\[.SELF./image:)(.*?)(\\]\\])', 'g');
            text = text.replace(regex_wikilink,'<img src="'+path+'/file:$2?m=download"  alt=".SELF./image:$2" type="wikilink"  />');
            return text;
          }
        }
    ::xo::Page requireJS $js
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
    set disabled [:is_disabled]
    set is_repeat_template [expr {[info exists :is_repeat_template] && ${:is_repeat_template} == "true"}]
    # :msg "${:id} ${:name} - $is_repeat_template"

    if {$is_repeat_template} {
      set :data-repeat-template-id ${:id}
    }

    # if value is empty, we need something to be clickable for display mode inplace
    if {[:value] eq "" && ${:displayMode} eq "inplace"} {
      :value "&nbsp;"
    }

    if {![:istype ::xowiki::formfield::richtext] || ($disabled && !$is_repeat_template)} {
      :render_richtext_as_div
    } else {

      template::head::add_javascript -src urn:ad:js:jquery
      try {
        #
        # Try to use the ckeditor from the richtext-ckeditor4
        # installation.
        #
        # There seems to be something broken on 4.9.2 version on the
        # CDN. If we do not use standard-all, then we see an error
        # about a missing
        # ".../4.9.2/full/plugins/iframedialog/plugin.js". There
        # exists a "iframe" and a "iframedialog" plugin for ckeditor4,
        # the latter is not included in the standard builds (only in
        # "-all").
        #
        ::richtext::ckeditor4::add_editor \
            -order 90 \
            -ck_package ${:ck_package} \
            -adapters "jquery.js"

      } trap {TCL LOOKUP COMMAND} {errorMsg} {
        #
        # If for whatever reason, richtext-ckeditor4 is not available,
        # bail out and tell the user to install.
        #

        error "Please install the package: richtext-ckeditor4"
      }

      #
      # In contrary to the documentation, ckeditor4 names instances
      # after the id, not the name.
      #
      set id ${:id}
      set name ${:name}
      set package_id [${:object} package_id]
      if {${:displayMode} eq "inline"} {
        lappend :extraPlugins sourcedialog
      }

      if {"xowikiimage" in ${:extraPlugins}} {
        :js_image_helper
        set ready_callback "xowiki_image_callback(CKEDITOR.instances\['$id'\]);"
        set ready_callback2 {xowiki_image_callback(e.editor);}
      } else {
        set ready_callback "/*none*/;"
        set ready_callback2 $ready_callback
        set submit_callback "/*none*/;"
      }

      #
      # Append dimensions (when available) in JSON notation.
      #
      set dimensions {}
      if {[info exists :height]} {
        lappend dimensions [subst {"height": "${:height}"}]
      }
      if {[info exists :width]} {
        lappend dimensions [subst {"width": "${:width}"}]
      }
      if {[llength $dimensions] > 0} {
        set dimensions [join $dimensions ,],
      }

      set options [subst {
        $dimensions
        ${:additionalConfigOptions}
        toolbar : '${:toolbar}',
        uiColor: '${:uiColor}',
        language: '[::xo::cc lang]',
        skin: '${:skin}',
        startupMode: '${:mode}',
        disableNativeSpellChecker: false,
        parent_id: '[${:object} item_id]',
        package_url: '[::$package_id package_url]',
        extraPlugins: '[join ${:extraPlugins} ,]',
        extraAllowedContent: '${:extraAllowedContent}',
        contentsCss: '${:contentsCss}',
        imageSelectorDialog: '[:imageSelectorDialog]?parent_id=[${:object} item_id]',
        ready_callback: '$ready_callback2',
        customConfig: '${:customConfig}',
        textarea_id: id
      }]
      if {${:allowedContent} ne ""} {
        #
        # Syntax rules:
        # https://ckeditor.com/docs/ckeditor4/latest/guide/dev_allowed_content_rules.html#string-format
        #
        if {${:allowedContent} in {true false}} {
          append options "  , allowedContent: ${:allowedContent}\n"
        } else {
          append options "  , allowedContent: '${:allowedContent}'\n"
        }
      }
      if {${:templatesFiles} ne ""} {
        append options "  , templates_files: \['[join [:pathNames ${:templatesFiles}] ',' ]' \]\n"
      }
      if {${:templates} ne ""} {
        append options "  , templates: '${:templates}'\n"
      }

      #set parent [[${:object} package_id] get_page_from_item_or_revision_id [${:object} parent_id]];# ???

      if {${:displayMode} eq "inplace"} {

        lappend :CSSclass ckeip
        ::xo::Page requireJS "/resources/xowiki/ckeip.js"

        ::xo::Page requireJS [subst -nocommands {
          function load_$id (id) {
            // must use id provided as argument
            \$('#' + id).ckeip(function() { ${:callback}}, {
              name: '$name',
              ckeditor_config: {
                $options,
                destroy_callback: function() { ${:destroy_callback} }
              }
            });
          }
        }]
        if {!$is_repeat_template} {
          ::xo::Page requireJS [subst -nocommands {
            \$(document).ready(function() {
              CKEDITOR.plugins.addExternal( 'xowikiimage', '/resources/xowiki/ckeditor4/plugins/xowikiimage/', 'plugin.js' );
              if (\$('#$id').parents('.repeatable').length != 0) {
                if (\$('#$id').is(':visible')) {
                  load_$id ('$id');
                }
              } else {
                //this is not inside a repeatable container, load normally
                load_$id ('$id');
              }
            } );
          }]
        }
        :render_richtext_as_div
      } elseif {${:displayMode} eq "inline"} {
        if {"xowikiimage" in ${:extraPlugins}} {
          set ready_callback "xowiki_image_callback(CKEDITOR.instances\['$id'\]);"
          set submit_callback "calc_image_tags_to_wiki_image_links_inline('$id');"
        }

        set submit_callback "$submit_callback ${:submit_callback}"
        ::xo::Page requireJS [subst {
          function load_$id (id) {
            CKEDITOR.inline(id, {
              on: {
                instanceReady: function(e) {
                  \$(e.editor.element.\$).attr('title', '${:label}');
                  \$(e.editor.element.\$.form).submit(function(e) {
                    $submit_callback
                  });
                }
              },
              $options
            });
          }
        }]
        if {!$is_repeat_template} {
          ::xo::Page requireJS [subst {
            \$(document).ready(function() {
              CKEDITOR.plugins.addExternal( 'xowikiimage', '/resources/xowiki/ckeditor4/plugins/xowikiimage/', 'plugin.js' );
              if (\$('#$id').parents('.repeatable').length != 0) {
                if (\$('#$id').is(':visible')) {
                  load_$id ('$id');
                }
              } else {
                //this is not inside a repeatable container, load normally
                load_$id ('$id');
              }
              $ready_callback
            });
          }]
        }
        next
      } else {
        ::xo::Page requireJS [subst -nocommands {
          function load_$id (id) {
            // must use id provided as argument
            \$('#' + id).ckeditor(function() { ${:callback} }, {$options});
          }
        }]
        if {!$is_repeat_template} {
          ::xo::Page requireJS [subst -nocommands {
            \$(document).ready(function() {
              CKEDITOR.plugins.addExternal( 'xowikiimage', '/resources/xowiki/ckeditor4/plugins/xowikiimage/', 'plugin.js' );
              load_$id ('$id');
              $ready_callback
              //CKEDITOR.instances['$id'].on('instanceReady',function(e) {$ready_callback});
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
    set :widget_type richtext
  }
  richtext::wym instproc render_input {} {
    set disabled [:is_disabled]
    if {![:istype ::xowiki::formfield::richtext] || $disabled } {
      :render_richtext_as_div
    } else {
      ::xo::Page requireCSS "/resources/xowiki/wymeditor/skins/default/screen.css"
      ::xo::Page requireJS urn:ad:js:jquery
      ::xo::Page requireJS  "/resources/xowiki/wymeditor/jquery.wymeditor.pack.js"
      set postinit ""
      foreach plugin {hovertools resizable fullscreen embed} {
        if {$plugin in [:plugins]} {
          switch -- $plugin {
            embed {}
            resizable {
              ::xo::Page requireJS  urn:ad:js:jquery-ui
              append postinit "wym.${plugin}();\n"
            }
            default {append postinit "wym.${plugin}();\n"}
          }
          ::xo::Page requireJS  "/resources/xowiki/wymeditor/plugins/$plugin/jquery.wymeditor.$plugin.js"
        }
      }
      regsub -all {[.:]} ${:id} {\\\\&} JID

      # possible skins are per in the distribution: "default", "sliver", "minimal" and "twopanels"
      set config [list "skin: '[:skin]'"]

      #:msg "wym, h [info exists :height] || w [info exists :width]"
      if {[info exists :height] || [info exists :width]} {
        set height_cmd ""
        set width_cmd ""
        if {[info exists :height]} {set height_cmd "jQuery(wym._box).find(wym._options.iframeSelector).css('height','[:height]');"}
        if {[info exists :width]}  {set width_cmd "wym_box.css('width', '[:width]');"}
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
    switch -- ${:displayMode} {
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
    set :widget_type richtext
    if {![info exists :plugins]} {
      :plugins \
          [parameter::get -parameter "XowikiXinhaDefaultPlugins" \
               -default [::xo::parameter get_from_package_key \
                             -package_key "acs-templating" -parameter "XinhaDefaultPlugins"]]
    }
    set :options [:get_attributes editor plugins width height folder_id script_dir javascript wiki_p]
    # for the time being, we can't set the defaults via parameter,
    # but only manually, since the editor is used as a mixin, the parameter
    # would have precedence over the defaults of subclasses
    if {![info exists :slim]} {set :slim false}
    if {![info exists :style]} {set :style "width: 100%;"}
    if {![info exists :height]} {set :height 350px}
    if {![info exists :wiki_p]} {set :wiki_p 1}
    if {${:slim}} {
      lappend :options javascript {
        xinha_config.toolbar  = [['popupeditor', 'formatblock', 'bold','italic','createlink','insertimage'],
                                 ['separator','insertorderedlist','insertunorderedlist','outdent','indent'],
                                 ['separator','killword','removeformat','htmlmode']
                                ];
      }
    }
  }

  richtext::xinha instproc render_input {} {
    set disabled [:is_disabled]
    if {![:istype ::xowiki::formfield::richtext] || $disabled} {
      :render_richtext_as_div
    } else {
      #
      # required CSP directives for Xinha
      #
      security::csp::require script-src 'unsafe-eval'
      security::csp::require script-src 'unsafe-inline'

      # we use for the time being the initialization of xinha based on
      # the blank master
      set ::acs_blank_master(xinha) 1
      set quoted [list]
      foreach e [:plugins] {lappend quoted '$e'}
      set ::acs_blank_master(xinha.plugins) [join $quoted ", "]

      array set o ${:options}
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
      lappend ::acs_blank_master__htmlareas ${:id}

      if {${:displayMode} eq "inplace"} {
        ::html::div [:get_attributes id name {CSSclass class} disabled] {
          set href \#
          ::html::a -style "float: right;" -class edit-item-button -href $href -id ${:id}-edit {
            ::html::t -disableOutputEscaping &nbsp;
          }
          template::add_event_listener \
              -id ${:id}-edit \
              -script [subst {xinha.inplace.openEditor('${:id}');}]

          ::html::div -id "${:id}__CONTENT__" {
            ::html::t -disableOutputEscaping  [:value]
          }
        }
        set :hiddenid ${:id}__HIDDEN__
        set :type hidden
        ::html::input [:get_attributes {hiddenid id} name type value] {}
      } else {
        #::html::div [:get_attributes id name cols rows style {CSSclass class} disabled] {}
        next
      }
    }
  }

  ###########################################################
  #
  # ::xowiki::formfield::ShuffleField
  #
  ###########################################################

  # abstract superclass for select and radio
  Class create ShuffleField -superclass FormField -parameter {
    {options ""}
    {render_hints ""}
    {show_max ""}
    {shuffle_kind:wordchar none}
  } -ad_doc {

    An abstract class for shuffling options and answers.  The options
    can be used a content of checkboxes, radioboxes and the like. This
    is particular useful when creating quizzes.

    @param shuffle_kind none|peruser|always
  }
  ShuffleField set abstract 1

  ShuffleField instproc randomized_indices {length} {
    #
    # Produce a list of random indices.
    #
    # In case, the shuffle_kind is not "always", we assume a shuffling
    # produced by every call. When a seed is provided (e.g. a user_id)
    # then the shuffling is stable for this seed.
    #
    if {${:shuffle_kind} ne "always"} {
      #
      # It is possible to keep different seeds in the instance
      # attributes of the object to support a different randomization
      # not only by user but also per position. This requires either
      # an instance variable "test_item_in_position" in the form field or an
      # instance_attribute "position" in the object, where the former
      # has a higher precedence (important for combined forms).
      #
      if {![:exists test_item_in_position]} {
        set :test_item_in_position [${:object} property position]
      }
      set seeds [${:object} property seeds]
      set seed [expr {$seeds ne "" && ${:test_item_in_position} ne ""
                      ? [lindex $seeds ${:test_item_in_position}]
                      : [xo::cc user_id]}]
      set shuffled [::xowiki::randomized_indices -seed $seed $length]
      #ns_log notice "randomized_indices for [xo::cc user_id] (${:test_item_in_position} - $seeds): $shuffled (inp [:exists test_item_in_position])"
    } else {
      set shuffled [::xowiki::randomized_indices $length]
    }
    return $shuffled
  }

  ShuffleField instproc valid_subselection {shuffled} {
    if {${:show_max} < [llength $shuffled]} {
      #
      # Take first n shuffled elements as subselection
      #
      set range [expr {${:show_max} - 1}]
      set subselection [lrange $shuffled 0 $range]

      if {${:multiple}} {
        #
        # Multiple choice: Accept every subselection as valid for the
        # time being.
        #
      } elseif {[info exists :answer_value]} {
        #
        # Single choice: make sure that the correct element is
        # included in subselection.
        #
        set must_contain [expr {${:answer_value} - 1}]
        if {$must_contain ni $subselection} {
          #ns_log notice "--- have to fix subselection does not contain $must_contain"
          set dropIndex [expr {int($range * rand())}]
          set subselection [lreplace $subselection $dropIndex $dropIndex $must_contain]
          #ns_log notice "--- fixed subselection dropIndex $dropIndex -> $subselection"
        }
      }
      set shuffled $subselection
    }
    return $shuffled
  }

  ShuffleField instproc shuffle_options {} {
    #
    # Reorder :options and :answers when :shuffle is activated.
    #
    set length [llength ${:options}]
    if {$length > 0} {
      #
      # There is something to shuffle.
      #
      #
      # Produce a list of random indices.
      #
      set shuffled [:randomized_indices $length]

      #
      # Use the random indices for reordering the :options and
      # :answers.
      #
      if {[info exists :show_max] && ${:show_max} ne ""} {
        set shuffled [:valid_subselection $shuffled]
        #ns_log notice "SHUFFLE ${:name} <$shuffled> answer_value ${:answer_value} MAX <${:show_max}>"
      }
      set option2 {}; set answer2 {}; set answer_value2 {}
      if {[llength ${:render_hints}] > 0} {
        set render_hints2 {}
      }
      if {[info exists :descriptions] && [llength ${:descriptions}] > 0} {
        set descriptions2 {}
      }
      foreach i $shuffled {
        lappend option2 [lindex ${:options} $i]
        lappend answer2 [lindex ${:answer} $i]
        if {${:multiple} && [info exists :answer_value]} {
          lappend answer_value2 [lindex ${:answer_value} $i]
        }
        if {[info exists render_hints2]} {
          lappend render_hints2 [lindex ${:render_hints} $i]
        }
        if {[info exists descriptions2]} {
          lappend descriptions2 [lindex ${:descriptions} $i]
        }
      }
      #ns_log notice "SHUFFLE ${:name} o2=$option2 answer2=$answer2"
      set :options $option2
      set :answer $answer2
      if {${:multiple}} {
        set :answer_value $answer_value2
      }
      if {[info exists render_hints2]} {
        set :render_hints $render_hints2
      }
      if {[info exists descriptions2]} {
        set :descriptions $descriptions2
      }
    }
  }

  ShuffleField instproc initialize {} {
    next
    #
    # Shuffle options when needed
    #
    if {${:shuffle_kind} ne "none"} {
      :shuffle_options
    }
  }


  ###########################################################
  #
  # ::xowiki::formfield::enumeration
  #
  ###########################################################

  # abstract superclass for select and radio
  Class create enumeration -superclass ShuffleField -parameter {
    {category_tree}
    {descriptions ""}
  }
  enumeration set abstract 1

  enumeration instproc initialize {} {
    if {[info exists :category_tree]} {
      :config_from_category_tree ${:category_tree}
    }
    if {[info exists :answer]} {
      set count 1
      set :answer_value {}
      foreach a ${:answer} {
        if {$a} {
          lappend :answer_value $count
        }
        incr count
      }
      #ns_log notice "???? answer ${:answer} -> ${:answer_value}"
    }
    next

    #
    # For required enumerations, the implicit default value is the
    # first entry of the options. This is as well the value, which is
    # returned from the browser in such cases.
    #
    if {${:required} && ${:value} eq ""} {
      set :value [lindex ${:options} 0 1]
    }
  }
  enumeration abstract instproc render_input {}

  enumeration instproc value_if_nothing_is_returned_from_form {default} {

    # Here we have to distinguish between two cases:
    # - edit mode: somebody has removed a mark from a check button;
    #   this means: clear the field
    # - view mode: the fields were deactivated (made insensitive);
    #   this means: keep the old value -> return default

    if {[info exists :disabled]} {
      return $default
    } else {
      return ""
    }
  }

  enumeration instproc get_labels {values} {
    if {${:multiple}} {
      set labels [list]
      foreach v $values {
        lappend labels [list [:get_entry_label $v] $v]
      }
      return $labels
    } else {
      return [list [list [:get_entry_label $values] $values]]
    }
  }

  enumeration instproc answer_is_correct {} {
    #:log "enumeration CORRECT? ${:name} (value=[:value], answer=[expr {[info exists :answer]?${:answer}:{NONE}}]"
    if {![info exists :answer]} {
      return 0
    } else {
      set value [:value]
      #:log "enumeration CORRECT? answers [llength ${:answer}] options [llength ${:options}]"
      set :correction {}
      set r 0; set f 0; set rk 0; set fk 0; set W 0; set O 0; set R 0
      foreach o ${:options} a ${:answer} {
        lassign $o label v
        #:log "enumeration CORRECT? <$a> <$v in $value> -> [expr {$v in $value}]"
        #
        # A correct answer might be:
        # - a mark on a correct entry
        # - no mark on a wrong entry
        #
        if {$a} {
          incr r
          set correctly_answered [expr {$v in $value}]
        } else {
          set correctly_answered [expr {$v ni $value}]
          incr f
          #:log "enumeration - CORRECT? <$a> <$v ni $value> -> [expr {$v ni $value}]"
        }
        lappend :correction $correctly_answered
        if {$correctly_answered} {
          incr R
        } else {
          incr W
        }

        if {$v in $value} {
          #
          # Marked entries: mark can be correct or wrong.
          #
          if {$a} {
            incr rk
          } else {
            incr fk
          }
        }
        #
        # Now calculate the scores of different scoring schemes. For
        # now, we do not allow questions having no correct answer.
        #
        if {$r > 0} {
          if {$f == 0} {
            #
            # No penalty for marking a wrong solution, when there is
            # no wrong solution.
            #
            set wi1 [expr {max((100.0/$r) * $rk,0)}]
            set wi2 [expr {max((100.0/$r) * $rk, 0)}]
          } else {
            set wi1 [expr {max((100.0/$r) * $rk - (100.0/$f) * $fk, 0)}]
            if {$f == 1} {
              #
              # Special rule when there is just one wrong solution.
              #
              set wi2 [expr {max((100.0/$r) * $rk - min(50.0, (100.0/$f)) * $fk, 0)}]
            } else {
              set wi2 $wi1
            }
          }
          set s1   [expr {100.0 * $R / ($R + $W) }]
          set s2   [expr {100.0 * ($R - $W/2.0) / ($R + $W) }]
          set etk  [expr {100.0 * (($r*1.0+$f) /$r) * ($rk - $fk) / ($R + $W) }]
          set ggw0 [expr {100.0 * ($R - $W) / ($R + $W) }]
          set ggw  [expr {100.0 * ($R - $W*0.5) / ($R + $W) }]

          set scores [list wi1 $wi1 wi2 $wi2 s1 $s1 s2 $s2 etk $etk ggw0 $ggw0 ggw $ggw]
        } else {
          set scores {}
        }
        set :correction_data [list \
                                  item [list r $r f $f] \
                                  marks [list rk $rk fk $fk] \
                                  answers [list R $R W $W] \
                                  scores $scores]
      }
      #:log "enumeration CHECKED CORRECT? ${:correction_data}"
      return [expr {0 ni ${:correction} ? 1 : -1}]
    }
  }

  enumeration instproc make_correct {} {
    set :value ${:answer_value}
    #ns_log notice "???? make_correct sets value ${:answer_value}"
  }

  enumeration instproc add_statistics {{-options ""}} {
    #ns_log notice "???? add_statistics"
    #
    # Add generic statistics
    #
    next
    #
    # Enumeration specific statistics
    #
    foreach v ${:value} {
      dict incr :result_statistics $v
    }
    #ns_log notice "${:name} ### answer ${:answer} value ${:value} correction ${:correction} "
    #ns_log notice [:serialize]
  }


  enumeration instproc pretty_value {v} {
    if {[info exists :category_label($v)]} {
      return [set :category_label($v)]
    }
    if {[info exists :multiple] && ${:multiple}} {
      foreach o ${:options} {
        lassign $o label value
        set labels($value) [:localize $label]
      }
      set values [list]
      foreach i $v {lappend values $labels($i)}
      return [join $values {, }]
    } else {
      foreach o ${:options} {
        lassign $o label value
        if {$value eq $v} {return [:localize $label]}
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
    #set tree_id [category_tree::get_id $tree_name [:locale]]

    set package_id [${:object} package_id]
    set tree_ids [::xowiki::Category get_mapped_trees \
                      -object_id $package_id -locale ${:locale} \
                      -names $tree_name -output tree_id]

    # In case there are multiple trees with the same name,
    # take the first one.
    #
    set tree_id [lindex $tree_ids 0]

    if {$tree_id eq ""} {
      :msg "cannot lookup mapped category tree name '$tree_name'"
      return
    }
    set subtree_id ""
    set options [list]

    foreach category [::xowiki::Category get_category_infos \
                          -subtree_id $subtree_id -tree_id $tree_id] {
      lassign $category category_id category_name deprecated_p level
      set category_name [ns_quotehtml [lang::util::localize $category_name]]
      set :category_label($category_id) $category_name
      if { $level>1 } {
        set category_name "[string repeat {.} [expr {2*$level-4}]]..$category_name"
      }
      lappend options [list $category_name $category_id]
    }
    set :options $options
    if {[info exists :default] && ${:default} ne ""} {
      #
      # When a default is provided, and the default is a valid
      # name. Note that the "symbolic" default has to be provided
      # exactly like the label, and it might not be unique.
      #
      set optdict [concat {*}$options]
      if {[dict exists $optdict ${:default}]} {
        set :default [dict get $optdict ${:default}]
      }
    }
    set :is_category_field 1
    # :msg label_could_be=$tree_name,existing=${:label}
    # if {![info exists :label]} {
    #    :label $tree_name
    # }
  }

  enumeration instproc render_result_statistics {rep} {
    #
    # In case, there are result_statistics, use a "progress bar" to
    # visualize correct answers.
    #
    if {[info exists :result_statistics] && [dict exists ${:result_statistics} count]} {
      set result_count [dict get ${:result_statistics} count]

      if {$result_count > 0} {
        ::html::div -class "progress" {
          set correctCount [expr {[dict exists ${:result_statistics} $rep] ? [dict get ${:result_statistics} $rep] : 0}]
          set percentage [format %2.0f [expr {$correctCount * 100.0 / $result_count}]]
          ::html::div -class "progress-bar progress-bar-success" -role "progressbar" \
              -aria-valuenow $percentage -aria-valuemin "0" -aria-valuemax "100" -style "width:$percentage%" {
                ::html::t "$percentage %"
              }
        }
      }
    }
  }

  enumeration instproc render_label_classes {} {
    #
    # Determine the values of the CSS classes for correct/incorrect
    # rendering. In statistics mode (when :result_statistics exists),
    # use the correct value of the alternative. Otherwise, use
    # the :correction of the actual value in the form field.
    #
    if {[info exists :result_statistics]} {
      set values ${:answer}
      #ns_log notice "==== radio answer $answer aw ${:answer_value} results ${:result_statistics}"
    } else {
      set values [expr {[info exists :correction] ? ${:correction} : ""}]
    }
    return [lmap v $values {dict get {"" "" 1 correct 0 incorrect t correct f incorrect} $v}]
  }

  enumeration instproc render_label_text {label CSSclass description} {
    #
    # Render a label text (typically of a checkbox or radio input)
    # either as richtext or as plain label.
    #
    if {${:richtext}} {
      ::html::div -class richtext-label {
        ::html::t -disableOutputEscaping $label
        if {[info exists :evaluated_answer_result] && "incorrect" in $CSSclass} {
          html::div -class "help-block description" {
            html::t $description
          }
        }
      }
    } else {
      ::html::t " $label "
    }
  }


  ###########################################################
  #
  # ::xowiki::formfield::radio
  #
  ###########################################################

  Class create radio -superclass enumeration -parameter {
    {horizontal false}
    {richtext:boolean false}
    {forced_name}
  }
  radio instproc initialize {} {
    set :widget_type text(radio)
    set :multiple false
    next
  }
  radio instproc render_input {} {
    set value [:value]

    set base_atts [:get_attributes disabled]
    lappend base_atts \
        type radio \
        name [expr {[info exists :forced_name] ? ${:forced_name} : ${:name}}]

    foreach o ${:options} label_class [:render_label_classes] description ${:descriptions} {
      lassign $o label rep
      set id ${:id}:$rep
      set atts [list {*}$base_atts id $id value $rep]
      if {$value eq $rep} {
        lappend atts checked checked
      }
      if {1 || ${:horizontal}} {lappend label_class col-sm2 radio-inline}
      ::html::label -for $id -class $label_class {
        ::html::input $atts {}
        :render_label_text $label $label_class $description
      }
      :render_result_statistics $rep
      if {!${:horizontal}} {
        html::br
      }
    }
    :handle_transmit_always $value
  }

  ###########################################################
  #
  # ::xowiki::formfield::checkbox
  #
  ###########################################################

  Class create checkbox -superclass enumeration -parameter {
    {horizontal:boolean false}
    {richtext:boolean false}
  }
  checkbox instproc initialize {} {
    set :multiple true
    set :widget_type text(checkbox)
    next
  }
  checkbox instproc td_pretty_value {v} {
    return $v
  }

  checkbox instproc render_input {} {
    set value [:value]

    set base_atts [:get_attributes disabled]
    lappend base_atts \
        type checkbox \
        name ${:name}

    foreach o ${:options} label_class [:render_label_classes] description ${:descriptions} {
      lassign $o label rep
      set id ${:id}:$rep
      set atts [list {*}$base_atts id $id value $rep]
      if {$rep in $value} {
        lappend atts checked checked
      }
      if {1 || ${:horizontal}} {lappend label_class col-sm2 checkbox-inline}
      ::html::label -for $id -class $label_class {
        ::html::input $atts {}
        :render_label_text $label $label_class $description
      }
      :render_result_statistics $rep

      if {!${:horizontal}} {
        html::br
      }
    }
    :handle_transmit_always $value
  }

  ###########################################################
  #
  # ::xowiki::formfield::text_fields
  #
  ###########################################################

  Class create text_fields -superclass {CompoundField ShuffleField} -parameter {
    {descriptions ""}
  } -ad_doc {

    Provide multiple text and short text entries. This field is a
    compound field which create for every text field a sub
    component. When the components are rendered, the items can be
    shuffled.

  }

  text_fields instproc initialize {} {
    # The value of ":multiple" has to be true for shuffling.
    set :multiple true
    next

    #
    # Properties for all fields
    #
    dict set fc_dict disabled [:is_disabled]
    dict set fc_dict disabled_as_div [info exists :disabled_as_div]
    dict set fc_dict label ""

    set fields {}
    set answers [expr {[info exists :answer] ? ${:answer} : ""}]

    foreach option ${:options} a $answers render_hints_dict ${:render_hints} {
      #
      # Properties for a single fields
      #
      set field_fc_dict $fc_dict

      if {[dict exists $render_hints_dict words]} {
        dict set field_fc_dict placeholder #xowiki.[dict get $render_hints_dict words]#
      }
      dict set field_fc_dict correct_when $a

      lassign $option text rep
      set render_hints [dict get $render_hints_dict words]
      switch $render_hints {
        "multiple_lines" {
          set type textarea
          dict set field_fc_dict rows [dict get $render_hints_dict lines]
          dict set field_fc_dict autosave true
        }
        "file_upload" {
          set type file
        }
        default {
          set type text
        }
      }
      lappend fields [list $rep [:dict_to_fc -type $type $field_fc_dict]]
    }

    #:log "TEXT text_fields fields\n[join $fields \n]>"
    :create_components $fields
  }

  text_fields instproc set_feedback {feedback_mode} {
    next
    #
    # Make result (fully) correct, only when all sub-questsions are as
    # well correct.
    #
    set :evaluated_answer_result [expr {"0" in ${:correction} ? "incorrect" : "correct"}]
    return ${:evaluated_answer_result}
  }

  text_fields instproc answer_is_correct {} {
    #:log "text_fields  CORRECT? ${:name}"

    set feedback_mode [expr {[${:object} exists __feedback_mode] ? [${:object} set __feedback_mode] : 0}]
    set results {}
    set :correction {}
    foreach c [lsort ${:components}] {
      set correct [$c set_feedback $feedback_mode]
      lappend results $correct
      lappend :correction [expr {$correct eq "correct"}]
    }

    set nr_correct [llength [lmap c ${:correction} { if {!$c} continue; set _ 1}]]
    set :grading_score [format %.2f [expr {$nr_correct*100.0/[llength ${:correction}]}]]*
    #:log "text_fields CORRECT? ${:name} results $results :correction ${:correction} -> ${:grading_score}"
    #
    # Return "0" to avoid double feedback via the info text per
    # subquestion and on the top-level.
    #
    return 0
  }

  text_fields instproc get_text_entry {componentName} {
    set wantedRep [lindex [split $componentName .] end]
    foreach option ${:options} {
      lassign $option text rep
      if {$rep eq $wantedRep} {
        return $text
      }
    }
    return ""
  }

  text_fields instproc render_input {} {
    #
    # Render content within in a fieldset, but with labels etc.
    #
    html::ul [:get_attributes id {CSSclass class}] {
      #
      # Descriptions are currently handled outside of the
      # component. It might be possible to handle these on the
      # subcomponent level, but for now we want to keep the changes as
      # local as possible.
      #
      foreach c ${:components} description ${:descriptions} {
        if {$c eq ""} {
          ns_log bug "text_fields ${:name}: no component for description $description"
          continue
        }
        html::li {
          html::t -disableOutputEscaping [:get_text_entry [$c name]]
          $c render
          #
          # Display descriptions only for the "incorrect" cases.
          #
          if {[info exists :evaluated_answer_result] && ${:evaluated_answer_result} eq "incorrect"} {
            html::div -class "help-block description" {
              html::t $description
            }
          }
          $c render_result_statistics
        }
      }
    }
  }

  text_fields instproc td_pretty_value {v} {
    set result ""
    foreach {key value} $v {
      set componentLabel [string range $key [string length ${:name}]+1 end]
      append result $componentLabel: " " $value \n
    }
    return $result
  }

  text_fields instproc pretty_value {v} {
    set result ""
    set ff [dict create {*}$v]
    foreach c [lsort ${:components}] {
      set componentName [$c set name]
      if {[dict exists $ff $componentName]} {
        set componentLabel [string range $componentName [string length ${:name}]+1 end]
        append result $componentLabel: " " [$c pretty_value [dict get $ff $componentName]] \n
      }
    }
    return $result
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
    set :widget_type text(select)
    next
    if {![info exists :options]} {set :options [list]}
  }

  select instproc render_input {} {
    set value [:value]
    set atts [:get_attributes id name disabled {CSSclass class}]
    if {${:multiple}} {lappend atts multiple ${:multiple}}
    if {!${:required}} {
      set :options [linsert ${:options} 0 [list "--" ""]]
    }
    ::html::select $atts {
      foreach o ${:options} {
        lassign $o label rep
        set atts [:get_attributes disabled]
        lappend atts value $rep
        #:msg "lsearch {$value} $rep ==> [lsearch $value $rep]"
        if {$rep in $value} {
          lappend atts selected selected
        }
        ::html::option $atts {::html::t $label}
        ::html::t \n
      }
    }
    :handle_transmit_always $value
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

  candidate_box_select instproc add_drag_handler {
    -id:required
    -event:required
  } {
    template::add_event_listener \
        -id $id \
        -event $event \
        -preventdefault=false \
        -script "selection_area_${event}_handler(event);"
  }

  candidate_box_select instproc render_input {} {
    #:msg "mul ${:multiple} dnd ${:dnd}"
    # makes only sense currently for multiple selects

    if {${:multiple} && ${:dnd}} {

      if {[:is_disabled]} {
        html::t -disableOutputEscaping [:pretty_value [:value]]
      } else {

        ::xo::Page requireJS  "/resources/xowiki/selection-area.js"
        set count 0
        set selected {}
        set candidates {}

        foreach o ${:options} {
          lassign $o label rep
          if {$rep in ${:value}} {
            lappend selected $rep
          } else {
            lappend candidates $rep
          }
          dict set labels $rep label $label
          #dict set labels $rep label $rep
          dict set labels $rep serial [incr count]
        }

        html::div -class candidate-selection -id ${:id} {
          #
          # Internal representation
          #
          ::html::textarea -id ${:id}.text -name ${:name} {
            ::html::t [join ${:value} \n]
          }

          #
          # Selections
          #
          ::html::div -class workarea {
            ::html::h3 { ::html::t "#xowiki.Selection#"}
            # TODO what todo with DISABLED?
            ::html::ul -class "region selected" \
                -id ${:id}.selected {
                  foreach v $selected {
                    set id ${:id}.selected.[dict get $labels $v serial]
                    ::html::li -class selection \
                        -draggable true -id $id -data-value $v {
                          ::html::t [dict get $labels $v label]
                        }
                    :add_drag_handler -id $id -event dragstart
                  }
                }
            :add_drag_handler -id ${:id}.selected -event drop
            :add_drag_handler -id ${:id}.selected -event dragover
          }
          #
          # Candidates
          #
          ::html::div -class workarea {
            ::html::h3 { ::html::t "#xowiki.Candidates#"}
            ::html::ul -id ${:id}.candidates -class region {
              foreach v $candidates {
                set id ${:id}.[dict get $labels $v serial]
                ::html::li \
                    -class candidates \
                    -draggable true -id $id -data-value $v {
                      ::html::t [dict get $labels $v label]
                    }
                :add_drag_handler -id $id -event dragstart
              }
            }
            :add_drag_handler -id ${:id}.candidates -event drop
            :add_drag_handler -id ${:id}.candidates -event dragover
          }
        }
        ::html::div -class visual-clear {
          ;# this space is left intentionally blank
        }
      }
    } else {
      next
    }
  }

  ###########################################################
  #
  # ::xowiki::formfield::reorder_box
  #
  # The reorder_box form field can be used for ordering tasks (e.g. in
  # e-assessments) where elements are provided in a given or random
  # order and the user has to bring these to some correct order).
  #
  ###########################################################
  Class create reorder_box -superclass select -parameter {
    {shuffle:boolean true}
  }

  reorder_box instproc answer_is_correct {} {
    #
    # This method returns 0 (undecided), -1 (incorrect) or 1 (correct)
    # and sets as well the instance variable :correction with the
    # per-item correctness settings for correct/incorrect.
    #
    #:log "reorder_box CORRECT? ${:name} (value=[:value])"

    if {![info exists :answer]} {
      set result 0
    } else {
      set value [:value]
      if {[llength $value] != [llength ${:answer}]} {
        error "list length of value <$value> and answer <${:answer}> must be equal"
      }
      set result 1
      set :correction {}

      foreach v $value a ${:answer} {
        set ok [expr {$v eq $a}]
        lappend :correction $ok
        if {!$ok} {
          set result -1
        }
      }

      #:log "reorder_box CORRECT? answers [llength ${:answer}] options [llength ${:options}] -> $result"
    }
    return $result
  }


  reorder_box instproc render_input {} {

    if {${:value} eq ""} {
      #
      # When we have no value, provide a start value.
      #
      if {${:shuffle}} {
        #
        # When :shuffle is set, provide a randomized start value.
        #
        set :value [::xowiki::randomized_indices -seed [xo::cc user_id] [llength ${:options}]]
        #ns_log notice "=== reorder_box value '${:value}' shuffle ${:shuffle} value ${:value}"
      } else {
        #
        # Otherwise, take the internal representations as :value
        #
        set :value [lmap o ${:options} {lindex $o 1}]
      }
    }
    #
    # Make sure that value is feasible and bail out, if not.
    #
    set c -1; set indices [lmap o ${:options} {incr c}]
    if {[lsort -integer ${:value}] ne $indices} {
      error "intenal representation of options ${:options} must be subsequent integers starting with 0"
    }

    #
    # Provide a HTML ID for ".sortable" compatible with jquery
    #
    regsub -all {[.]} "${:id}.sortable" - jqID
    set textAreaID ${:id}.text

    if {![:is_disabled]} {
      #
      # If not disabled, let people move around the elements.
      #
      ::xo::Page requireCSS urn:ad:css:jquery-ui
      ::xo::Page requireJS urn:ad:js:jquery-ui

      template::add_body_script -script  [subst {
        \$("#$jqID").sortable();
        \$("#$jqID").on( "sortupdate", function( event, ui ) {
          var ul       = event.target;
          var textarea = document.getElementById('$textAreaID');
          var items    = ul.getElementsByTagName('LI');
          var internalRep = "";
          for (var j = 0; j < items.length; j++) {
            internalRep += items\[j\].dataset.value + "\\n";
          }
          textarea.value = internalRep;
        } );
      }]
    }

    #
    # Make sure, we have :correction initialized, since the rendering
    # code below needs it.
    #
    if {![info exists :correction]} {
      set :correction {}
    }

    html::div -class reorder_box -id ${:id} {
      #
      # The input field of the internal representation.
      #
      ::html::textarea -id $textAreaID -name ${:name} {
        ::html::t [join ${:value} \n]
      }

      #
      # The box for reordering items.
      #
      ::html::div -class workarea {
        ::html::ul -class "list-group" \
            -id $jqID {
              foreach v ${:value} c ${:correction} {
                set cl "list-group-item"
                lappend cl [expr {$c eq "1" ? "correct" : $c eq "0" ? "incorrect" : ""} ]
                ::html::li -class $cl -data-value $v {
                  ::html::t [lindex ${:options} $v 0]
                }
              }
            }
      }
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
    set :package_id [${:object} package_id]
    #:compute_options
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
    foreach o ${:options} {
      lassign $o label rep
      if {$value eq $rep} {
        return $label
      }
    }
    return ""
  }


  abstract_page instproc pretty_value {v} {
    set parent_id [${:object} parent_id]
    set package ::${:package_id}
    set :options [:get_labels $v]
    if {${:multiple}} {
      set default_lang [$package default_language]
      set root_folder [$package folder_id]
      set package_root [$package package_url]
      foreach o ${:options} {
        lassign $o label value
        #
        # "value" is an item_ref. Resolve it (assuming this works) and
        # prepend the package root URL)
        #
        set item_info [$package item_ref -default_lang $default_lang -parent_id $root_folder $value]
        set href $package_root[dict get $item_info link]
        set labels($value) "<a href='[ns_quotehtml $href]'>[ns_quotehtml $label]</a>"
      }
      set hrefs [list]
      foreach i $v {
        if {![info exists labels($i)]} {
          #:msg "can't determine label for value '$i' (values=$v, l=[array names labels])"
          set labels($i) $i
        }
        set href [$package pretty_link -parent_id $parent_id $i]
        lappend hrefs "<a href='[ns_quotehtml $href]'>$labels($i)</a>"
      }
      if {[:multiple_style] eq "list"} {
        return "<ul><li>[join $hrefs {</li><li>}]</li></ul>\n"
      } else {
        return [join $hrefs {, }]
      }
    } else {
      foreach o ${:options} {
        lassign $o label value
        #:log "comparing '$value' with '$v'"
        if {$value eq $v} {
          if {${:as_box}} {
            return [${:object} include [list $value -decoration rightbox]]
          }
          set href [$package pretty_link -parent_id $parent_id $value]
          return "<a href='[ns_quotehtml $href]'>$label</a>"
        }
      }
    }
  }

  abstract_page instproc render_input {} {
    :compute_options
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
    if {![info exists :form]} { return }
    next
    set form_name [:form]
    set :package_id [${:object} package_id]
    set form_objs [::xowiki::Weblog instantiate_forms \
                       -parent_id [${:object} parent_id] \
                       -default_lang [${:object} lang] \
                       -forms $form_name -package_id ${:package_id}]
    :log "form_page $form_name resolved into '$form_objs'"

    if {$form_objs eq ""} {
      error "Cannot lookup Form '$form_name'"
    }
    set :form_object_item_ids [list]
    foreach form_obj $form_objs {
      lappend :form_object_item_ids [$form_obj item_id]
    }
  }

  form_page instproc compute_options {} {
    #:msg "${:name} compute_options [info exists :form]"
    if {![info exists :form]} {
      return
    }

    set wc {tcl true h "" vars "" sql ""}
    if {[info exists :where]} {
      set wc [dict merge $wc [::xowiki::FormPage filter_expression ${:where} &&]]
      #:msg "where '${:where}' => wc=$wc"
    }

    set from_package_ids {}
    set package_path [::${:package_id} package_path]
    if {[llength $package_path] > 0} {
      foreach p $package_path {
        lappend from_package_ids [$p id]
      }
    }
    lappend from_package_ids ${:package_id}
    set items [::xowiki::FormPage get_form_entries \
                   -base_item_ids ${:form_object_item_ids} \
                   -form_fields [list] \
                   -publish_status ready \
                   -h_where $wc \
                   -package_id ${:package_id} \
                   -from_package_ids $from_package_ids]

    set :options [list]
    foreach i [$items children] {
      #
      # Compute the item_ref of the page. The item_ref has the
      # advantage over an href that it is easier relocatable via clipboard.
      #
      set package_id [$i package_id]
      set folder_path [$package_id folder_path -parent_id [$i parent_id]]
      set item_ref $folder_path[$i name]
      #ns_log notice "instance_select name [$i name] pl [$i pretty_link] PATH <$folder_path>"
      lappend :options [list [$i property ${:entry_label}] $item_ref]
    }
  }

  form_page instproc pretty_value {values} {
    if {![info exists :form_object_item_ids]} {
      error "No forms specified for form_field '${:name}'"
    }
    set :package_id [[lindex ${:form_object_item_ids} 0] package_id]
    next
  }

  form_page instproc convert_to_internal {} {
    #
    # The "value" consists of multiple lines, where every line is a
    # separate item_ref as returned by "compute_options". Add these as
    # extra references to the associated object each time the page is
    # updated.
    #
    if {${:value} ne ""} {
      set references {}
      #:log "---- form_page.convert_to_internal <${:value}>"
      set package_id [${:object} package_id]
      set parent_id [${:object} parent_id]
      ::xo::db::CrClass get_instance_from_db -item_id $parent_id
      set parent_id [$parent_id parent_id]

      foreach name [split ${:value} \n] {
        set item_info [::$package_id item_ref -normalize_name false \
                           -use_package_path 1 \
                           -default_lang [${:object} lang] \
                           -parent_id $parent_id \
                           $name]
        set item_id [dict get $item_info item_id]
        #:log "---- $name -> item_id $item_id"
        if {$item_id ne 0} {
          lappend references [list $item_id wf_form]
        }
      }
      if {[llength $references] > 0} {
        #:msg "updating references refs=$references"
        #
        # In case, there are already __extra_references, append it.
        #
        ${:object} lappend __extra_references {*}$references
      }
    }
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
    set extra_where_clause ""
    if {[info exists :glob]} {
      append extra_where_clause [::xowiki::Includelet glob_clause ${:glob}]
    }

    set package_id [${:object} package_id]
    set :options [list]
    ::xo::dc foreach instance_select \
        [${:type} instance_select_query \
             -folder_id [::$package_id folder_id] \
             -with_subtypes ${:with_subtypes} \
             -select_attributes [list title] \
             -from_clause ", xowiki_page p" \
             -where_clause "p.page_id = bt.revision_id $extra_where_clause" \
             -orderby ci.name \
            ] {
              lappend :options [list [set ${:entry_label}] $name]
            }
  }

  page instproc pretty_value {v} {
    set :package_id [${:object} package_id]
    next
  }


  ###########################################################
  #
  # ::xowiki::formfield::security_policy
  #
  ###########################################################

  Class create security_policy -superclass select
  security_policy instproc initialize {} {
    set :options {}
    foreach p [lsort [::xowiki::Policy info instances]] {
      lappend :options [list $p $p]
    }
    next
  }

  ###########################################################
  #
  # ::xowiki::formfield::DD
  #
  ###########################################################

  Class create DD -superclass select
  DD instproc initialize {} {
    set :options {
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
    set :options {
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
    if {[llength $args] == 0} {return ${:value}} else {
      set v [lindex $args 0]
      if {$v eq ""} {
        set :value ""
      } else {
        # round to 5 minutes
        set :value [lindex ${:options} [expr {($v + 2) / 5}] 1]
      }
    }
  }
  MI instproc initialize {} {
    set :options {
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
    set :options {
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
    set values [lang::message::lookup [:locale] acs-lang.localization-abmon]
    if {[lang::util::translator_mode_p]} {set values [::xo::localize $values]}
    set last 0
    set :options {}
    foreach m {1 2 3 4 5 6 7 8 9 10 11 12} {
      lappend :options [list [lindex $values $last] $m]
      set last $m
    }
    next
  }
  ###########################################################
  #
  # ::xowiki::formfield::month
  #
  ###########################################################

  Class create month -superclass select
  month instproc initialize {} {
    set values [lang::message::lookup [:locale] acs-lang.localization-mon]
    if {[lang::util::translator_mode_p]} {set values [::xo::localize $values]}
    set last 0
    set :options {}
    foreach m {1 2 3 4 5 6 7 8 9 10 11 12} {
      lappend :options [list [lindex $values $last] $m]
      set last $m
    }
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
    if {${:help_text} eq ""} {
      set :help_text "#xowiki.formfield-youtube_url-help_text#"
    }
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
        border border-width position top bottom left right
      }
  image_url instproc initialize {} {
    next
    if {${:help_text} eq ""} {
      set :help_text "#xowiki.formfield-image_url-help_text#"
    }
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
    set entry_name [:entry_name $value]
    if {$entry_name eq ""} {
      :log "--img '$value' does not appear to be an image"
      # no image?
      return 0
    }
    set folder_id [${:object} set parent_id]
    if {[::xo::db::CrClass lookup -name $entry_name -parent_id $folder_id]} {
      :log "--img entry named $entry_name exists already"
      # file exists already
      return 1
    }
    if {[regexp {^file://(.*)$} $value _ path]} {
      set f [open $path r]
      fconfigure $f translation binary
      set img [read $f]
      close $f
    } else {
      ad_try {
        set request [util::http::get -url $value]
        set img [expr {[dict exists $request page] ? [dict get $request page] : ""}]
      } on error {errorMsg} {
        # cannot transfer image
        :log "--img cannot obtain image '$value' ($errorMsg)"
        return 0
      }
    }
    #:msg "guess mime_type of $entry_name = [::xowiki::guesstype $entry_name]"
    set import_file [ad_tmpnam]
    ::xo::write_file $import_file $img
    set file_object [::xowiki::File new -destroy_on_cleanup \
                         -title $entry_name \
                         -name $entry_name \
                         -parent_id $folder_id \
                         -mime_type [::xowiki::guesstype $entry_name] \
                         -package_id [${:object} package_id] \
                         -creation_user [::xo::cc user_id] \
                        ]
    $file_object set import_file $import_file
    $file_object save_new
    return 1
  }
  image_url instproc pretty_value {v} {
    set entry_name [:entry_name $v]
    return [:pretty_image -parent_id [${:object} parent_id] $entry_name]
  }


  ###########################################################
  #
  # ::xowiki::formfield::include
  #
  ###########################################################

  # note that the includelet "include" can be used for implementing symbolic links
  # to other xowiki pages.
  Class create include -superclass text -parameter {
    {resolve_local false}
  }

  include instproc pretty_value {v} {
    if {$v eq ""} { return $v }

    set item_id [${:object} get_property_from_link_page item_id 0]
    :log "##### include in ${:object} '[${:object} name]': get_property_from_link_page ${:object} item_id => <$item_id> (resolve_local ${:resolve_local})"
    if {$item_id == 0} {
      # Here, we could call "::xowiki::Link render" to offer the user means
      # to create the entry like with [[..]], if he has sufficient permissions...;
      # when $(package_id) is 0, the referenced package could not be
      # resolved
      return "Cannot resolve symbolic link '$v'"
    }
    set link_type [${:object} get_property_from_link_page link_type]
    ${:object} references resolved [list $item_id $link_type]
    set item ::$item_id

    if {${:resolve_local}} {
      #
      # Resetting esp. the item_id is dangerous.
      # Therefore, we reset it immediately after the rendering.
      #
      #:log "#### RESOLVE LOCAL: setting for $item [$item name] set_resolve_context -parent_id [${:object} parent_id] -item_id [${:object} item_id]"
      $item set __RESOLVE_LOCAL 1
      $item set_resolve_context \
          -package_id [${:object} package_id] -parent_id [${:object} parent_id] \
          -item_id [${:object} item_id]

      set html [$item render -update_references never]

      $item unset __RESOLVE_LOCAL
      $item reset_resolve_context
    } else {
      set html [$item render]
    }
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
    return [[${:object} package_id] returnredirect $v]
  }

  ###########################################################
  #
  # ::xowiki::formfield::label
  #
  ###########################################################

  Class create label -superclass FormField -parameter {
    {disableOutputEscaping:boolean false}
  }
  label instproc render_item {} {
    # sanity check; required and label do not fit well together
    if {${:required}} {set :required false}
    next
  }
  label instproc render_input {} {
    if {${:disableOutputEscaping}} {
      ::html::t -disableOutputEscaping [:value]
    } else {
      ::html::t [:value]
    }
    # Include labels as hidden fields to avoid surprises when
    # switching field types to labels.
    set :type hidden
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
    if {![info exists :form]} { return }
    set :form_objs [::xowiki::Weblog instantiate_forms \
                        -parent_id [${:object} parent_id] \
                        -default_lang [${:object} lang] \
                        -forms [:form] \
                        -package_id [${:object} package_id]]
  }
  child_pages instproc pretty_value {v} {
    if {[info exists :form_objs]} {
      set count 0
      foreach form ${:form_objs} {
        incr count [$form count_usages \
                        -package_id [${:object} package_id] \
                        -parent_id [${:object} item_id] \
                        -publish_status ${:publish_status}]
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
    #:msg "DATE has value [:value]//d=[:default] format=${:format} disabled?[info exists :disabled]"
    set :widget_type date
    set :format [string map [list _ " "] ${:format}]
    array set :defaults {year 2000 month 01 day 01 hour 00 min 00 sec 00}
    array set :format_map {
      SS    {SS    %S 1}
      MI    {MI    %M 1}
      HH24  {HH24  %H 1}
      DD    {DD    %e 0}
      MM    {MM    %m 1}
      MON   {mon   %m 1}
      MONTH {month %m 1}
      YYYY  {YYYY  %Y 0}
    }
    #:msg "${:name} initialize date, format=${:format} components=${:components}"
    foreach c ${:components} {$c destroy}
    :components [list]

    foreach element [split ${:format}] {
      if {![info exists :format_map($element)]} {
        #
        # We add undefined formats as literal texts in the edit form
        #
        set name $element
        set c [::xowiki::formfield::label create [self]::$name \
                   -name ${:name}.$name -id ${:id}.$name \
                   -locale [:locale] -object ${:object} \
                   -value $element]
        $c set_disabled 1; # this is a dummy field, never query for its value
        if {$c ni ${:components}} {lappend :components $c}
        continue
      }
      lassign [set :format_map($element)] class code trim_zeros
      #
      # create for each component a form field
      #
      set name $class
      set c [::xowiki::formfield::$class create [self]::$name \
                 -name ${:name}.$name -id ${:id}.$name \
                 -locale [:locale] -object ${:object}]
      #:msg "creating ${:name}.$name"
      $c set_disabled [info exists :disabled]
      $c set code $code
      $c set trim_zeros $trim_zeros
      if {$c ni ${:components}} {lappend :components $c}
    }
  }

  date instproc set_compound_value {value} {
    #:msg "${:name} original value '[:value]' // passed='$value' disa?[info exists :disabled]"
    # if {$value eq ""} {return}
    if { $value eq {} } {
      # We need to reset component values so that
      # instances of this class can be used as flyweight
      # objects. Otherwise, we get side-effects when
      # we render the input widget.
      foreach c ${:components} {
        $c value ""
      }
      return
    }
    set value [::xo::db::tcl_date $value tz]
    #:msg "transformed value '$value'"
    if {$value ne ""} {
      set ticks [clock scan [string map [list _ " "] $value]]
    } else {
      set ticks ""
    }
    set :defaults(year)  [clock format $ticks -format %Y]
    set :defaults(month) [clock format $ticks -format %m]
    set :defaults(day)   [clock format $ticks -format %e]
    set :defaults(hour)  [clock format $ticks -format %H]
    set :defaults(min)   [clock format $ticks -format %M]
    #set :defaults(sec)   [clock format $ticks -format %S]

    # set the value parts for each components
    foreach c ${:components} {
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
      #:msg "ticks=$ticks $c value $value_part"
      $c value $value_part
    }
  }

  date instproc get_compound_value {} {
    # Set the internal representation of the date based on the components values.
    # Internally, the ansi date format is used.
    set year ""; set month ""; set day ""; set hour ""; set min ""; set sec ""
    if {[nsf::is object [self]::YYYY]}  {set year  [[self]::YYYY  value]}
    if {[nsf::is object [self]::month]} {set month [[self]::month value]}
    if {[nsf::is object [self]::mon]}   {set month [[self]::mon   value]}
    if {[nsf::is object [self]::MM]}    {set month [[self]::MM    value]}
    if {[nsf::is object [self]::DD]}    {set day   [[self]::DD    value]}
    if {[nsf::is object [self]::HH24]}  {set hour  [[self]::HH24  value]}
    if {[nsf::is object [self]::MI]}    {set min   [[self]::MI    value]}
    if {[nsf::is object [self]::SS]}    {set sec   [[self]::SS    value]}
    if {"$year$month$day$hour$min$sec" eq ""} {
      return ""
    }
    # Validation happens after the value is retrieved.
    # To avoid errors in "clock scan", fix the year if necessary
    if {![string is integer $year]} {set year 0}

    foreach v [list year month day hour min sec] {
      if {[set $v] eq ""} {set $v [set :defaults($v)]}
    }
    #:msg "$year-$month-$day ${hour}:${min}:${sec}"
    if {[catch {set ticks [clock scan "$year-$month-$day ${hour}:${min}:${sec}"]}]} {
      set ticks 0 ;# we assume that the validator flags these values
    }
    # TODO: TZ???
    #:msg "DATE ${:name} get_compound_value returns [clock format $ticks -format {%Y-%m-%d %T}]"
    return [clock format $ticks -format "%Y-%m-%d %T"]
  }

  date instproc same_value {v1 v2} {
    if {$v1 eq $v2} {return 1}
    return 0
  }

  date instproc pretty_value {v} {
    #
    # Internally, we use the ansi date format. For displaying the date,
    # use the specified display format and present the time localized.
    #
    # Drop of the value after the "." we assume to have a date in the local zone
    regexp {^([^.]+)[.]} $v _ v
    #return [clock format [clock scan $v] -format [string map [list _ " "] ${:display_format}]]
    if {${:display_format} eq "pretty-age"} {
      return [::xowiki::utility pretty_age -timestamp [clock scan $v] -locale [:locale]]
    } else {
      return [lc_time_fmt $v [string map [list _ " "] ${:display_format}] [:locale]]
    }
  }

  date instproc render_input {} {
    #
    # render the content inline within a fieldset, without labels etc.
    #
    set :style "margin: 0px; padding: 0px;"
    html::fieldset [:get_attributes id style] {
      foreach c ${:components} { $c render_input }
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
    if {[info exists :disabled]} {
      return $default
    } else {
      return f
    }
  }
  boolean instproc initialize {} {
    # should be with cvs head message catalogs:
    set :options "{#acs-kernel.common_Yes# t} {#acs-kernel.common_No# f}"
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
    :type hidden
    set :widget_type boolean(hidden)
  }
  boolean_image instproc render_input {} {
    set title [expr {[info exists :__render_help_text_as_title_attr] ? ${:help_text} : ""}]
    ::html::img \
        -title $title \
        -class ${:CSSclass} \
        -src [expr {[:value] ? ${:t_img_url} : ${:f_img_url}}] \
        -id ${:id}-image
    template::add_event_listener \
        -id ${:id}-image \
        -script [subst {toggle_img_boolean(this,'${:t_img_url}','${:f_img_url}');}]

    ::html::input -type hidden -name ${:name} -value [:value]

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
    set :options [list]
    for {set i 1} {$i <= ${:n}} {incr i} {
      lappend :options [list $i $i]
    }
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
    #:msg form=$form
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
  #
  # The form_constraints checker is defined on the
  # ::xowiki::Page level as validate=form_constraints
  #


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
    {multiday:boolean false}
    {calendar}
    {time_label #xowiki.event-time#}
  }

  event instproc initialize {} {
    #:log "event initialize [info exists :__initialized], multi=${:multiday} state=${:__state}"
    if {${:__state} ne "after_specs"} return
    set :widget_type event
    if {${:multiday}} {
      set dtend_format DD_MONTH_YYYY_#xowiki.event-hour_prefix#_HH24_MI
      set dtend_display_format %Q_%X
    } else {
      set dtend_format HH24_MI
      set dtend_display_format %X
    }
    :create_components [subst {
      {title {text,label=#xowiki.event-title_of_event#}}
      {summary {richtext,height=150px,label=#xowiki.event-summary_of_event#}}
      {dtstart {date,required,format=DD_MONTH_YYYY_#xowiki.event-hourprefix#_HH24_MI,
        default=now,label=#xowiki.event-start_of_event#,display_format=%Q_%X}}
      {dtend   date,format=$dtend_format,default=now,label=#xowiki.event-end_of_event#,display_format=$dtend_display_format}
      {location text,label=#xowiki.event-location#}
      {cal_item_id hidden}
    }]
    set :__initialized 1
  }

  event instproc get_compound_value {} {
    if {![info exists :__initialized]} {
      return ""
    }
    set dtstart  [:get_component dtstart]
    set dtend    [:get_component dtend]
    if {!${:multiday}} {
      # If the event is not a multi-day-event, the end_day is not
      # given by the dtend widget, but is taken from dtstart.
      set end_day  [lindex [$dtstart value] 0]
      set end_time [lindex [$dtend value] 1]
      $dtend value "$end_day $end_time"
      #:msg "[$dtend name] set to '$end_day $end_time' ==> $dtend, [$dtend value]"
    }
    next
  }

  event instproc pretty_value {v} {
    #array set {} [:value]
    set dtstart [:get_component dtstart]
    set dtstart_val [$dtstart value]
    set dtstart_iso [::xo::ical clock_to_iso [clock scan $dtstart_val]]
    set dtstart_pretty [$dtstart pretty_value $dtstart_val]

    set dtend [:get_component dtend]
    set dtend_val [$dtend value]
    set dtend_txt ""
    if {$dtend_val ne ""} {
      set dtend_iso [::xo::ical clock_to_iso [clock scan $dtend_val]]
      set dtend_txt " - <time class='dt-end' title='$dtend_iso'>[$dtend pretty_value $dtend_val]</time>"
    }

    set time_label [:time_label]
    if {[regexp {^#([a-zA-Z0-9_:-]+\.[a-zA-Z0-9_:-]+)#$} $time_label _ msg_key]} {
      set time_label [lang::message::lookup [:locale] $msg_key]
    }

    set title_val   [[:get_component title] value]
    if {$title_val eq ""} {
      set title_val [${:object} property _title]
    }
    set summary_val [[:get_component summary] value]

    set location [:get_component location]
    set location_val [$location value]
    set location_txt ""
    if {$location_val ne ""} {
      set location_label [$location label]
      if {[regexp {^#(.+)#$} $location_label _ msg_key]} {
        set location_label [lang::message::lookup [:locale] $msg_key]
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
    if {[info exists :calendar]} {
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
      if {[string is integer -strict ${:calendar}]} {
        set calendar_id ${:calendar}
        if {[calendar::name $calendar_id] eq ""} {
          set calendar_id ""
        }
      }
      if {$calendar_id eq ""} {
        error "calendar '${:calendar} has no valid calendar_id"
      }

      #
      # Get the values for the calendar item
      #
      set dtstart_val [[:get_component dtstart] value]
      set dtend_val   [[:get_component dtend]   value]
      set title_val   [[:get_component title]   value]
      set title_val   [[:get_component title]   value]
      set summary_val [[:get_component summary] value]
      set cal_item_id [[:get_component cal_item_id] value]

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
      set queue ::__xowiki__transaction_queue([${:object} item_id])
      lappend $queue [list [self] update_calendar -cal_item_id $cal_item_id -calendar_id $calendar_id \
                          -start $dtstart_val -end $dtend_val -name $title_val -description $summary_val]
    }

    next
  }

  event instproc update_calendar {-cal_item_id -calendar_id -start -end -name -description} {
    #
    # If we have already a valid cal_item_id (checked previously)
    # update the entry. Otherwise create a new calendar item and
    # update the instance variables.
    #
    if {$cal_item_id ne ""} {
      #:log "===== [list calendar::item::edit -start_date $start -end_date $end -cal_item_id $cal_item_id ...]"
      calendar::item::edit -cal_item_id $cal_item_id -start_date $start \
          -end_date $end -name $name -description $description
    } else {
      #:log "===== [list calendar::item::new -start_date $start -end_date $end -calendar_id $calendar_id ...]"
      set cal_item_id [calendar::item::new -start_date $start -end_date $end \
                           -name $name -description $description -calendar_id $calendar_id]
      [:get_component cal_item_id] value $cal_item_id
      #
      # The following line is required when used in transaction to
      # update the instance attributes
      #
      ${:object} set_property event [:get_compound_value]
    }
  }


}

namespace eval ::xowiki::formfield {

  # Class create mycompound -superclass CompoundField
  #
  # mycompound instproc initialize {} {
  #   if {${:__state} ne "after_specs"} return
  #   :create_components  [subst {
  #     {start_on_publish {checkbox,default=t,options={YES t}}}
  #     {whatever   {text}}
  #   }]
  #   set :__initialized 1
  # }

  ###########################################################
  #
  # ::xowiki::formfield::class
  #
  ###########################################################

  Class create class -superclass select -parameter {
    {subclass_of ::xotcl::Object}
  }
  class instproc initialize {} {
    set :options ""
    foreach cl [lsort [list ${:subclass_of} {*}[${:subclass_of} info subclass -closure]]] {
      lappend :options [list $cl $cl]
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
