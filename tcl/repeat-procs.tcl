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
  # - allow max to be open-ended (see also "addItem" in .js)
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
  Class repeatContainer -superclass ::xowiki::formfield::CompoundField -parameter {
    {min 1}
    {max 5}
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
      lappend result $s
    }
    return [list $is_required [join $result ,]]
  }
  repeatContainer instproc initialize {} {
    ::xo::Page requireJS  "/resources/xowiki/repeat.js"
    ::xo::Page requireJS "/resources/xowiki/jquery/jquery.min.js"
    
    if {[my exists __initialized_repeat]} {return}
    next
    my set __initialized_repeat 1
    #
    # Derive the spec of the contained items from the spec of the
    # container.
    #
    set itemSpec [lindex [my item_spec] 1]
    set is_required [lindex [my item_spec] 0]

    #
    # Use item .0 as template for other items in .js (e.g. blank an
    # item with the template, when it is deleted. By using a
    # potentially compound item as template, we are able to preserve
    # default values for subfields without knowing the detailed
    # structure).
    #
    set components [list [list 0 $itemSpec]]

    #
    # Add max content items (1 .. max) and build form fields
    #
    for {set i 1} {$i <= [my max]} {incr i} {
      if {$i <= [my min] && $is_required} {
        lappend components [list $i $itemSpec,required,label=$i]
      } else {
        lappend components [list $i $itemSpec,label=$i]
      }
    }
    my create_components $components

    #
    # Deactivate template item
    #
    set componentList [my components]
    if {[llength $componentList] > 0} {
      [lindex $componentList 0] set_disabled true
      [lindex $componentList 0] set_is_repeat_template true
    }
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
      set i 1
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
      set containerDisabled [expr {[my exists disabled] && [my disabled] ne "false"}]
      foreach c [my components] {
	set atts [list class $CSSclass]
	if {$i > $nrItems || [string match "*.0" [$c name]]} {
	  lappend atts style "display: none;"
	}
	::html::div $atts {
	  $c render_input 
	  # compound fields - link not shown if we are not rendering for the template and copy the template afterwards
	  # if {!$containerDisabled} {
	    ::html::a -href "#" -onclick "return xowiki.repeat.delItem(this,\"$clientData\")" { html::t "\[x\]" }
	  # }
	}
	incr i
      }
      # if {!$containerDisabled} {
	html::a -href "#" -onclick "return xowiki.repeat.addItem(this,\"$clientData\");" { html::t "add another" }
      # }
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

}