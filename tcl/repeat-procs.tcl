::xo::library doc {

  Form-field "repeat" 

  @author Gustaf Neumann
  @creation-date 2013-02-27
}

::xo::library require -package xowiki form-field-procs

namespace eval ::xowiki::formfield {

  # TODO:
  # - improve styling (e.g. remove/deactivate controls for 
  #   addition/deletion, when min/max is reached)
  # - test for more input types
  # - maybe deactivate container display for "repeat=1..1"

  ::xowiki::formfield::FormField instproc repeat {range} {
    if {[my exists __initialized_repeat]} return

    set oldClass [my info class]
    my class ::xowiki::formfield::repeatContainer
    
    if {$oldClass ne [my info class]} {
      my reset_parameter
      my set __state reset
    }

    if {$range ne ""} {
      my instvar min max
      if {[regexp {^(\d*)[.][.](\d*)$} $range _ low high]} {
        if {$low ne ""}  {set min $low}
        if {$high ne ""} {set max $high}
        if {$min > $max} {
          error "invalid range '$range' specified (lower limit $min must not be larger than higher limit $max)"
        }
        if {$min < 0 || $max < 1} {
          error "invalid range '$range' specified (max $max must be at least 1) "
        }
      } else {
        error "invalid range '$range' specified (must be of form 'min..max')"
      }
    }
    my initialize
  }

  ###########################################################
  #
  # ::xowiki::formfield::repeatContainer
  #
  ###########################################################
  Class create repeatContainer -superclass ::xowiki::formfield::CompoundField -parameter {
    {min 1}
    {max 5}
    {repeat_add_label "#xowiki.form-repeatable-add#"}
    {repeat_remove_label "#xowiki.form-repeatable-delete#"}
  }
  repeatContainer instproc item_spec {} {
    #
    # Return the spec of a contained item, which is a subset of the
    # container spec.
    #
    set result {}
    set is_required false
    foreach s [split [my spec] ,] {
      # don't propagate "repeat" and "label" properties
      if { [string match "repeat=*" $s] || [string match "label=*" $s] } continue
      if { "required" eq $s} {set is_required true; continue}
      if { "disabled" eq $s} {my set_disabled true}
      lappend result $s
    }
    return [list $is_required [join $result ,]]
  }
  repeatContainer instproc initialize {} {
    ::xo::Page requireJS "/resources/xowiki/repeat.js"
    ::xo::Page requireJS "/resources/xowiki/jquery/jquery.min.js"
    #::xo::Page requireJS "/resources/ajaxhelper/jquery/jquery-1.11.1.min.js"
    
    if {[my exists __initialized_repeat]} {return}
    next

    my set __initialized_repeat 1
    #
    # Derive the spec of the contained items from the spec of the
    # container.
    #
    lassign [my item_spec] isRequired itemSpec

    #
    # Use item .0 as template for other items in .js (e.g. blank an
    # item with the template, when it is deleted. By using a
    # potentially compound item as template, we are able to preserve
    # default values for subfields without knowing the detailed
    # structure).
    #
    set componentItemSpecs [list [list 0 $itemSpec]]

    #
    # Add max content items (1 .. max) and build form fields
    #
    set formAction [${:object} form_parameter __form_action {}]
    # TODO: we use for the time being the code for dynamic repeat field
    if {0 && $formAction eq ""} {
      #
      # The form field is in input mode; as long there is no js
      # support do incrementally add form fields in js, we have to
      # generate it here.
      #
      set max [my max]
    } else {
      #set max [my max]
      set max [my min] ;# use dynamic repeat fields: if set to min, repeat fields will be created on demand
    }
    #ns_log notice "dynamic repeat MAX=$max FORMACTION <$formAction>"
    for {set i 1} {$i <= $max} {incr i} {
      set componentItemSpec [my component_item_spec $i $itemSpec $isRequired]
      #ns_log notice "dynamic repeat componentItemSpec $componentItemSpec"
      lappend componentItemSpecs $componentItemSpec
    }
    my create_components $componentItemSpecs

    #
    # Deactivate template item
    #
    set componentList [my components]
    if {[llength $componentList] > 0} {
      [lindex $componentList 0] set_disabled true
      [lindex $componentList 0] set_is_repeat_template true
    }
  }

  repeatContainer instproc component_item_spec {i itemSpec isRequired} {
    #
    # Return a single itemspec suited for the nth component, derived
    # from the repeatable formfield spec.
    #
    if {$i <= [my min] && $isRequired} {
      set componentItemSpec [list $i $itemSpec,required,label=$i]
    } else {
      set componentItemSpec [list $i $itemSpec,label=$i]
    }
    return $componentItemSpec
  }

  repeatContainer instproc require_component {i} {
    #
    # Require the nth component of a repeat field
    #
    lassign [my item_spec] isRequired itemSpec
    set componentItemSpec [my component_item_spec $i $itemSpec $isRequired]
    #ns_log notice "dynamic repeat field: add component on the fly: $componentItemSpec"
    my add_component $componentItemSpec
  }
  
  repeatContainer instproc set_compound_value value {
    #
    # Before setting compound values, check if we have the repeat
    # strucure already set.
    #
    set neededComponents [expr {[llength $value] / 2}]
    set availableComponents [llength ${:components}]
    #ns_log notice "[self] repeatContainer set_compound_value <$value> have $availableComponents needed $neededComponents"
    if {$neededComponents > $availableComponents} {
      lassign [my item_spec] isRequired itemSpec
      for {set i $availableComponents} {$i < $neededComponents} {incr i} {
        :require_component $i
      }
    }

    next
  }
  
  repeatContainer instproc convert_to_internal {} {
    set values [my value]
    my trim_values
    set r [next]
    #my msg name=[my name],value=[my get_compound_value]

    #
    # remove "unneeded" entries from instance attributes
    #
    [my object] instvar instance_attributes
    foreach {name value} $values {
      if {[dict exists $instance_attributes $name]} {
        dict unset instance_attributes $name
      }
    }
    return $r
  }

  repeatContainer instproc trim_values {} {
    # Trim trailing values idential to default.
    # Trimming the components list seems sufficient.
    set count [my count_values [my value]]
    my set components [lrange [my components] 0 $count]
  }

  repeatContainer instproc count_values {values} {
    set count 1
    set highestCount 1
    if {![my required]} {set highestCount [my min]}
    # The first pair is the default from the template field (.0)
    set default [lindex $values 1]
    foreach f [lrange [my components] 1 end] {name value} [lrange $values 2 end] {
      if {[$f required] || ($value ne "" && ![$f same_value $value $default])} {set highestCount $count}
      incr count
    }
    return $highestCount
  }


  repeatContainer instproc render_input {} {
    #
    # Render content of the container within in a fieldset,
    # without labels for the contained items.
    #
    html::fieldset [my get_attributes id {CSSclass class}] {
      set i 0
      my instvar min max name
      set clientData "{'min':$min,'max':$max, 'name':'$name'}"
      set CSSclass   "[my form_widget_CSSclass] repeatable"
      set providedValues [my count_values [my value]]
      if {$min > $providedValues} {
        set nrItems $min
      } else {
        set nrItems $providedValues
      }
      incr nrItems
      set containerIsDisabled [expr {[my exists disabled] && [my disabled] != "false"}]
      set containerIsPrototype [string match "*.0*" $name]
      set isPrototypeElement 0
      foreach c [my components] {
        set atts [list class $CSSclass]
        lappend atts data-repeat $clientData
        if {$i == 0 || $i >= $nrItems} {
          lappend atts style "display: none;"
        }
        ::html::div $atts {
          $c render_input 
          # compound fields - link not shown if we are not rendering for the template and copy the template afterwards
          if {!$containerIsDisabled || $containerIsPrototype} {
            set del_id "repeat-del-link-[$c set id]"
            ::html::a -href "#" \
                -id $del_id \
                -class "repeat-del-link" {
                  html::t [my repeat_remove_label]
                }
            template::add_event_listener \
                -id $del_id \
                -script [subst {xowiki.repeat.delItem(this,\"$clientData\");}]
          }
        }
        incr i
      }
      #ns_log notice "repeat container $c [$c name] isDisabled $containerIsDisabled containerIsPrototype $containerIsPrototype"
      if {!$containerIsDisabled || $containerIsPrototype } {
        set hidden [expr {[my count_values [my value]] == $max ? "display: none;" : ""}]
        set add_id "repeat-add-link-[my id]"
        ns_log notice "... add another for $name"
        html::a -href "#" \
            -id $add_id \
            -style $hidden \
            -class "repeat-add-link" {
              html::t [my repeat_add_label]
            }
        template::add_event_listener \
            -id $add_id \
            -script [subst {xowiki.repeat.newItem(this,\"$clientData\");}]
      }
    }
  }
  
  repeatContainer instproc validate {obj} {
    foreach c [lrange [my components] 1 [my count_values [my value]]] {
      set result [$c validate $obj]
      if {$result ne ""} {
        return $result
      }
    }
    return ""
  }

  repeatContainer instproc pretty_value {v} {
    #
    # Simple renderer for repeated values
    #
    set ff [dict create {*}$v]
    set html "<ol class='repeatContainer'>\n"
    foreach c [lrange [my components] 1 [my count_values [my value]]] {
      if {[dict exists $ff [$c set name]]} {
        append html "<li>[$c pretty_value [dict get $ff [$c set name]]]</li>\n"
      }
    }
    append html "</ol>\n"
    return $html
  }

  repeatContainer instproc value_if_nothing_is_returned_from_form {default} {
    # Here we have to distinguish between two cases to:
    # - edit mode: somebody has removed a mark from a check button;
    #   this means: clear the field
    # - view mode: the fields were deactivted (made insensitive);
    #   this means: keep the old value

    if {[my exists disabled]} {return $default} else {return ""}
  }

  Class create repeattest -superclass CompoundField
  repeattest instproc initialize {} {
    my create_components  [subst {
        {sub {text,repeat=1..4}}
    }]
    next
  }
}

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
