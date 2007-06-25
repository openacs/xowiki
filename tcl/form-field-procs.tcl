ad_library {
    XoWiki - form fields

    @creation-date 2007-06-22
    @author Gustaf Neumann
    @cvs-id $Id$
}

namespace eval ::xowiki {

  # first approximation for form fields.
  # these could support not only asWidgetSpec, but as well asHTML
  #
  # todo: every formfield type should have its own class
  # finally, this should go into xotcl-core

  Class FormField -parameter {
    {required false} {type text} {label} {name} {spell false} {size 80} 
    {value ""} {spec ""} {help_text ""}
  }
  FormField instproc init {} {
    my instvar spec
    if {![my exists label]} {my label [string totitle [my name]]}
    my config_from_spec $spec
  }
  FormField instproc config_from_spec {spec} {
    my instvar type options widget_type
    foreach s [split $spec ,] {
      switch -glob $s {
        optional    {my set required false}
        required    {my set required true}
        hidden      {set type hidden}
        inform      {set type inform}
        text        {set type text}
        boolean     {set type boolean}
        numeric     {set type text; #for the time being}
        month       {set type month}
        label=*     {my label     [lindex [split $s =] 1]}
        help_text=* {my help_text [lindex [split $s =] 1]}
        size=*      {my size      [lindex [split $s =] 1]}
        date*       {
          my instvar date
          set type date
          if {[regexp {^date\((.*)\)$} $s _ opts]} {
            foreach o [split "$opts;" ";"] {
              foreach {att value} [split $o =] break
              set date($att) [string map [list _ " "] $value]
            }
          }
        }
        select(*)  {
          regexp {^select\((.*)\)$} $s _ opts
          set type text(select)
          foreach o [split "$opts;" ";"] {
             switch -glob $o {
               options=* {set options [lindex [split $o =] 1]}
             }
          }
        }
        textarea*   {
          my instvar textarea
          set type text(textarea)
          set textarea(cols) 80
          set textarea(rows) 2
          if {[regexp {^textarea\((.*)\)$} $s _ opts]} {
            foreach o [split $opts ";"] {
              switch -glob $o {
                cols=* {set textarea(cols) [lindex [split $o =] 1]}
                rows=* {set textarea(rows) [lindex [split $o =] 1]}
              }
            }
          }
          my size [lindex [split $s =] 1]
        }
        default   {error "unknown spec for entry [my name]: '$s'"}
       }
    }
    switch $type {
      hidden  -
      inform {
        set widget_type text($type)
      }
      boolean  {
        set widget_type text(select)
        set options {{No f} {Yes t}}
      }
      month    {
        set widget_type text(select)
        set options {
          {January 1} {February 2} {March 3} {April 4} {May 5} {June 6}
          {July 7} {August 8} {September 9} {October 10} {November 11} {December 12}
        }
      }
      default {
        set widget_type $type
      }
    }
    #my msg "--formField processing spec $spec -> widget_type = $widget_type"
  }

  FormField instproc asWidgetSpec {} {
    my instvar widget_type options help_text
    set spec $widget_type
    if {![my spell]} {append spec ",nospell"}
    if {![my required]} {append spec ",optional"}
    append spec " {label \"[my label]\"}"
    if {$widget_type eq "text"} {
      if {[my exists size]} {append spec " {html {size [my size]}}"}
    } elseif {$widget_type eq "text(select)"} {
      append spec " {options [list $options]}"
    } elseif {$widget_type eq "text(textarea)"} {
      my instvar textarea
      append spec " {html {cols $textarea(cols) rows $textarea(rows)}}"
    } elseif {$widget_type eq "date" && [my exists date]} {
      if {[my exists date(format)]} {
        append spec " {format \"[my set date(format)]\"}"
      }
      # 	  {pub_date:date,optional {format "YYYY MM DD HH24 MI"} {html {id date}}}
    }
    if {$help_text ne ""} {
      if {[string match "#*#" $help_text]} {
        set internationalized [_ [string trim $help_text #]]
        append spec " {help_text {$internationalized}}"
      } else {
        append spec " {help_text {$help_text}}"
      }
    }
    #my msg "final spec=$spec"
    return $spec
  }

  FormField instproc render_form_widget {} {
    # todo: for all types
    set atts [list type text]
    foreach att {size name value} {
      if {[my exists $att]} {lappend atts $att [my set $att]}
    }

    ::html::div -class form-widget {::html::input $atts {}}
  } 
  FormField instproc render_item {} {
    ::html::div -class form-item-wrapper {
      ::html::div -class form-label {
        ::html::label -for [my name] {
          ::html::t [my label]
        }
        if {[my required]} {
          ::html::div -class form-required-mark {
            ::html::t " (#acs-templating.required#)"
          }
        }
      }
      my render_form_widget
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
 
  #
  # a few test cases
  #
  proc ? {cmd expected {msg ""}} {
    ::xo::Timestamp t1
    set r [uplevel $cmd]
    if {$msg eq ""} {set msg $cmd}
    if {$r ne $expected} {
      regsub -all \# $r "" r
      append ::_ "Error: $msg returned '$r' ne '$expected'\n"
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
        {text,nospell {label "#xowiki.Page-name#"} {html {size 80}} {help_text {Shortname to identify a page within a folder, typically lowercase characters}}} \
        "name with help_text"

    set f0 [$o create_form_field -name test \
                -slot ::xowiki::Page::slot::name -spec inform]
    ? {$f0 asWidgetSpec} \
        {text(inform),nospell {label "#xowiki.Page-name#"} {help_text {Shortname to identify a page within a folder, typically lowercase characters}}} \
        "name with help_text + inform"

    set f0 [$o create_form_field -name test \
                -slot ::xowiki::Page::slot::name -spec optional]
    ? {$f0 asWidgetSpec} \
        {text,nospell,optional {label "#xowiki.Page-name#"} {html {size 80}} {help_text {Shortname to identify a page within a folder, typically lowercase characters}}} \
        "name with help_text + optional"

    set f1 [$o create_form_field -name test \
               -slot ::xowiki::Page::slot::description \
               -spec "textarea(cols=80;rows=2)"]
    ? {$f1 asWidgetSpec} \
        {text(textarea),nospell,optional {label "#xowiki.Page-description#"} {html {cols 80 rows 2}}} \
        "textarea(cols=80;rows=2)"

    set f2 [$o create_form_field -name test \
                -slot ::xowiki::Page::slot::nls_language \
                -spec {select(options=[xowiki::locales])}]
    ? {$f2 asWidgetSpec} \
        {text(select),nospell,optional {label "#xowiki.Page-nls_language#"} {options {[xowiki::locales]}}} \
        {select(options=[xowiki::locales])}


    $o mixin ::xowiki::PodcastItem
    set f3 [$o create_form_field -name test \
                -slot ::xowiki::PodcastItem::slot::pub_date]
    ? {$f3 asWidgetSpec} \
        {date,nospell,optional {label "#xowiki.PodcastItem-pub_date#"} {format "YYYY MM DD HH24 MI"}} \
        {date with format}
  }
}
