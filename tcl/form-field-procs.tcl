ad_library {
    XoWiki - form fields

    @creation-date 2007-06-22
    @author Gustaf Neumann
    @cvs-id $Id$
}

namespace eval ::xowiki {

  # seconds approximation for form fields.
  # these could support not only asWidgetSpec, but as well asHTML (just partly by now)
  #
  # todo: finally, this should go into xotcl-core

  Class FormField -parameter {
    {required false} 
    {type text} 
    {label} 
    {name} 
    {id} 
    {value ""} 
    {spec ""} 
    {help_text ""}
    {error_msg ""}
    {validator ""}
  }
  FormField instproc init {} {
    if {![my exists label]} {my label [string totitle [my name]]}
    if {![my exists id]} {my id [my name]}
    if {[my exists id]}  {my set html(id) [my id]}
    #my msg "calling config_from_spec '[my spec]'"
    my config_from_spec [my spec]
  }

  FormField instproc validate {obj} {
    my instvar name required value
    if {$required && $value eq ""} {
      my instvar label
      return [_ acs-templating.Element_is_required]
    }
    # todo value type checker (through subtypes, check only if necessary)
    if {[my validator] ne ""} {
      set r [$obj [my validator] $value]
      #my msg "validator [my validator] /[$obj procsearch [my validator]]/ returned $r"
      if {$r != 1} {
        set cl [namespace tail [lindex [$obj procsearch [my validator]] 0]]
        my msg xowiki.$cl-[my validator]
        return [_ xowiki.$cl-[my validator]]
      }
    }
    return ""
  }

  FormField instproc config_from_spec {spec} {
    my instvar type options widget_type
    if {[my info class] eq [self class]} {
      # check, wether a class was already set. we do it this way
      # to allow multiple additive config_from_spec invocations
      my class  [self class]::$type
    }

    foreach s [split $spec ,] {
      switch -glob $s {
        optional    {my set required false}
        required    {my set required true}
        hidden      {my class [self class]::hidden}
        inform      {my class [self class]::inform}
        text        {my class [self class]::text}
        textarea    {my class [self class]::textarea}
        richtext    {my class [self class]::richtext}
        boolean     {my class [self class]::boolean}
        numeric     {my class [self class]::text; #for the time being
        }
        select      {my class [self class]::select}
        #scale       {my class [self class]::scale}
        month       {my class [self class]::month}
        date        {my class [self class]::date}
        label=*     {my label     [lindex [split $s =] 1]}
        help_text=* {my help_text [lindex [split $s =] 1]}
        *=*         {
          set l [split $s =]
          if {[catch {my [lindex $l 0] [lindex $l 1]} errMsg]} {
            my msg "Error during setting attribute [lindex $l 0] to value [lindex $l 1]: $errMsg"
          }
        }
        default     {my msg "Ignoring unknown spec for entry [my name]: '$s'"}
      }
    }
    ::xotcl::Class::Parameter searchDefaults [self]; # todo will be different in xotcl 1.6.*
    #my msg "[my name]: '$spec' calling initialize class=[my info class]\n"
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
    #if {[my exists display_html]} {
     # append spec " {display_value " [list [my set display_html]] "} "
    #}
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

  FormField instproc render_form_widget {} {
    # todo: for all types
    set atts [list type text]
    foreach att {size id name value} {
      if {[my exists $att]} {lappend atts $att [my set $att]}
    }
    ::html::div -class form-widget {::html::input $atts {}}
  } 
  
  FormField instproc render_error_msg {} {
    if {[my error_msg] ne ""} {
      ::html::div -class form-error {
        my instvar label
        ::html::t -disableOutputEscaping [my error_msg]
        my set error_reported 1
      }
    }
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
      my render_error_msg
    }
  }

  FormField instproc renderValue {v} {
    if {[my exists options]} {
      foreach o [my set options] {
        foreach {label value} $o break
        if {$value eq $v} {return $label}
      }
    }
    return $v
  }


  Class FormField::hidden -superclass FormField
  FormField::hidden instproc initialize {} {
    my instvar widget_type
    set widget_type text(hidden)
  }
  
  Class FormField::inform -superclass FormField
  FormField::inform instproc initialize {} {
    my instvar widget_type
    set widget_type text(inform)
  }

  Class FormField::text -superclass FormField -parameter {
    {size 80}
  }
  FormField::text instproc initialize {} {
    my instvar widget_type html
    set widget_type text
    foreach p [list size] {if {[my exists $p]} {set html($p) [my $p]}}
  }

  Class FormField::textarea -superclass FormField -parameter {
    {rows 2}
    {cols 80}
    {spell false}
    style
  }
  FormField::textarea instproc initialize {} {
    my instvar widget_type options html
    set widget_type text(textarea)
    foreach p [list rows cols style] {if {[my exists $p]} {set html($p) [my $p]}}
  }

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
    my instvar widget_type options
    next
    set widget_type richtext
    if {![my exists plugins]} {
      my plugins \
          [parameter::get -parameter "XowikiXinhaDefaultPlugins" \
               -default [parameter::get_from_package_key \
                             -package_key "acs-templating" -parameter "XinhaDefaultPlugins"]]
    }
    set options [list]
    foreach p [list editor plugins width height folder_id javascript] {
      if {[my exists $p]} {lappend options $p [my $p]}
    }
  }


  
  Class FormField::date -superclass FormField -parameter {format}
  FormField::date instproc initialize {} {
    my instvar widget_type format
    set widget_type date
    if {[my exists format]} {
      set format [string map [list _ " "] [my format]]
    }
  }

  Class FormField::radio -superclass FormField -parameter {
    {options ""}
  }
  FormField::radio instproc initialize {} {
    my set widget_type text(radio)
  }

  Class FormField::select -superclass FormField -parameter {
    {options ""}
    {multiple "false"}
  }
  FormField::select instproc initialize {} {
    my set widget_type text(select)
  }
  FormField::select instproc render_form_widget {} {
    ::html::div -class form-widget {
      set atts [list id [my id] name [my name]]
      if {[my multiple]} {lappend atts multiple [my multiple]}
      ::html::select $atts {
        foreach {name value} [my options] {
          set atts [list value $value]
          #my msg "lsearch {[my value]} $value ==> [lsearch [my value] $value]"
          if {[lsearch [my value] $value] > -1} {
            lappend atts selected on
          }
          ::html::option $atts {::html::t $name}
    }}}
  }


  Class FormField::month -superclass FormField -superclass FormField::select
  FormField::month instproc initialize {} {
    my options {
      {January 1} {February 2} {March 3} {April 4} {May 5} {June 6}
      {July 7} {August 8} {September 9} {October 10} {November 11} {December 12}
    }
    next
  }

  Class FormField::boolean -superclass FormField -superclass FormField::radio
  FormField::boolean instproc initialize {} {
    my options {{No f} {Yes t}}
    next
  }

  #Class FormField::scale -superclass FormField -parameter {{n 5}}
  #FormField::scale instproc initialize {} {
  #  my instvar n display_html 
  #  my set widget_type text
  #  for {set i 1} {$i < $n} {incr i} {
  #    set checked ""
  #    if {[my exists value] && [my value] == $i} {set checked " checked='checked'"}
  #    append display_html "<input type='radio' name='[my name]' value='$i' $checked> "
  #  }
  #}
 
  #
  # a few test cases
  #
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
