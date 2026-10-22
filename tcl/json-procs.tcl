::xo::library doc {
  Typed JSON export of XoWiki pages.

  Mapping rules:
  <ul>
    <li>Export all attributes except transient attributes prefixed with "__".</li>
    <li>Determine scalar types from inherited slot metadata; use explicit
        mappings for otherwise untyped built-in IDs and rendering flags.</li>
    <li>Export instance_attributes as an object, using form-field metadata
        to determine each stored value's type.</li>
    <li>Export numeric fields as numbers and boolean fields as true/false.
        Empty numeric and boolean values become null; empty text remains "".</li>
    <li>Preserve unknown types and invalid nonempty scalar values as strings.
        Numeric fields with keep_string_rep retain nonempty strings.</li>
    <li>Export multiple-value fields as arrays of strings.</li>
    <li>Export compound fields recursively as objects, removing the containing
        field's name prefix from component keys.</li>
    <li>Export repeated fields recursively as arrays in numeric occurrence
        order, omitting the occurrence-zero template. Repeated compound
        fields therefore become arrays of objects.</li>
    <li>Export stored values without applying form defaults. Preserve stored
        attributes no longer declared in the form; omit absent attributes.</li>
  </ul>

  Encode using ns_json, guarded by acs::icanuse. The web method returns
  pretty-printed JSON and requires site-wide administrator privileges.
  
  @creation-date 2026-10-22
  @author Gustaf Neumann

}

::xo::library require -package xowiki xowiki-www-procs
::xo::library require -package xowiki repeat-procs

namespace eval ::xowiki {
  
  ad_proc -private json_scalar {type value} {
    Return an ns_json type/payload pair. Empty typed scalars become null;
    invalid nonempty legacy values remain strings.

    @param type Requested JSON scalar type: number, boolean, or string.
    @param value Stored scalar value, without applying form defaults.
    @return Two-element list containing the ns_json type and payload.
  } {
    if {$value eq "" && $type in {number boolean}} {
      return [list null ""]
    }
    switch -- $type {
      boolean {
        switch -nocase -- $value {
          t - true - yes - on - 1 {return {boolean true}}
          f - false - no - off - 0 {return {boolean false}}
        }
      }
      number {
        # JSON numbers exclude NaN, infinity, hexadecimal and leading zeros.
        if {[regexp {^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$} $value]} {
          return [list number $value]
        }
      }
    }
    return [list string $value]
  }

  Page ad_instproc json_data {} {
    Collect all non-transient attributes as typed JSON members. Resolve
    instance attributes through form metadata without applying defaults.

    @return Flat list of name/type/payload triples for an ns_json object.
  } {
    set members {}
    foreach name [lsort [:info vars]] {
      if {[string match __* $name]} {
        continue
      }
      if {[:array exists $name]} {
        set entries {}
        foreach key [lsort [:array names $name]] {
          lappend entries $key string [:set ${name}($key)]
        }
        lappend members $name object $entries
        continue
      }
      set value [:set $name]
      if {$name eq "instance_attributes" && [:istype ::xowiki::PageInstance]} {
        set entries {}
        # Resolve effective form constraints, including @fields/@cr_fields.
        set form_fields [:create_form_fields [:field_names -form [:get_form]]]
        dict for {att stored_value} $value {
          if {[string match __* $att]} {
            continue
          }
          set f [:lookup_form_field -name $att $form_fields]
          lassign [$f json_value $stored_value] type payload
          lappend entries $att $type $payload
        }
        lappend members $name object $entries
      } else {
        lassign [::xowiki::json_scalar [:json_attribute_type $name] $value] type payload
        lappend members $name $type $payload
      }
    }
    return $members
  }

  Page ad_instproc json_attribute_type {name} {
    Resolve an attribute's JSON scalar type from inherited slot metadata
    and the known types of otherwise untyped built-in parameters.

    @param name Object attribute name, without a form-field underscore prefix.
    @return JSON scalar type: number, boolean, or string when unknown.
  } {
    # A presentation-only slot (e.g. Page.creation_user) can mask the
    # database slot's datatype. Inspect the full inheritance chain.
    set cl [:info class]
    foreach owner [list $cl {*}[$cl info heritage]] {
      set slot ${owner}::slot::$name
      if {![nsf::is object $slot]} {
        continue
      }
      foreach property {datatype type sqltype} {
        if {![$slot exists $property]} {
          continue
        }
        switch -- [$slot set $property] {
          boolean - bool {return boolean}
          integer - int - int4 - int8 - bigint - smallint - naturalnum -
          float - double - real - numeric - number {return number}
        }
      }
    }
    # These built-in parameters have no typed slot declaration.
    switch -- $name {
      parent_id {return number}
      absolute_links - do_substitutions - render_adp {return boolean}
    }
    return string
  }

  Page ad_instproc as_json {{-pretty:boolean false}} {
    Serialize all non-transient attributes, using form metadata for instance attributes.
    Use -pretty true for indented JSON output.

    @param pretty Whether to indent the generated JSON.
    @return JSON object string. Requires ns_json support.
  } {
    if {![::acs::icanuse "ns_json"]} {
      error "JSON export requires ns_json support"
    }
    set options {}
    if {$pretty} {
      lappend options -pretty
    }
    return [ns_json value -type object {*}$options [:json_data]]
  }

  Page ad_instproc www-json {} {
    Send the content object's attributes as pretty-printed JSON.
    Access is restricted to site-wide administrators by the package policy.
    Return HTTP 501 when ns_json is unavailable, then abort request processing.
  } {
    if {![::acs::icanuse "ns_json"]} {
      ns_return 501 text/plain "JSON export requires ns_json support"
      ad_script_abort
    }
    ns_set put [ns_conn outputheaders] Cache-Control no-store
    ns_return 200 application/json [:as_json -pretty true]
    ad_script_abort
  }
}

namespace eval ::xowiki::formfield {
  FormField ad_instproc json_value {value} {
    Export a stored value as text, or as an array of strings for a
    multiple-value field. Unknown field types retain their text values.

    @param value Stored field value.
    @return Two-element ns_json type/payload pair; array payloads contain triples.
  } {
    if {[:exists multiple] && [:set multiple]} {
        if {[catch {llength $value}]} {
            return [list string $value]}
      set entries {}
      set i 0
      foreach v $value {
        lappend entries $i string $v
        incr i
      }
      return [list array $entries]
    }
    return [list string $value]
  }

  foreach cl {boolean boolean_checkbox boolean_image} {
    $cl ad_instproc json_value {value} {
      Export a boolean, mapping an empty value to null and preserving
      invalid nonempty values as strings.

      @param value Stored boolean field value.
      @return Two-element ns_json type/payload pair.
    } {
      return [::xowiki::json_scalar boolean $value]
    }
  }
  foreach cl {number range} {
    $cl ad_instproc json_value {value} {
      Export a JSON number, mapping an empty value to null and preserving
      invalid nonempty values as strings.

      @param value Stored numeric field value.
      @return Two-element ns_json type/payload pair.
    } {
      return [::xowiki::json_scalar number $value]
    }
  }
  numeric ad_instproc json_value {value} {
    Export a normalized numeric value, or preserve a nonempty string when
    keep_string_rep is enabled. Empty values are exported as null.

    @param value Stored numeric field value.
    @return Two-element ns_json type/payload pair.
  } {
    # Stored numeric values are already normalized. keep_string_rep explicitly
    # requests preservation of the original (possibly localized) string.
    if {${:keep_string_rep} && $value ne ""} {
      return [list string $value]
    }
    return [::xowiki::json_scalar number $value]
  }

  CompoundField ad_instproc json_value {value} {
    Recursively export stored components as a JSON object. Strip the
    containing field's name prefix from component keys, omit transient
    components, and retain unknown components as strings. Invalid legacy
    values that are not dictionaries remain strings.

    @param value Stored dictionary of fully qualified component names and values.
    @return Two-element ns_json type/payload pair; object payloads contain triples.
  } {
    if {[catch {dict size $value}]} {
      return [list string $value]
    }
    set entries {}
    dict for {name v} $value {
      set key $name
      set prefix ${:name}.
      if {[string first $prefix $name] == 0} {
        set key [string range $name [string length $prefix] end]
      }
      if {[string match __* $key]} {
        continue
      }
      set type string
      set payload $v
      foreach c ${:components} {
        if {[$c name] eq $name} {
          lassign [$c json_value $v] type payload
          break
        }
      }
      lappend entries $key $type $payload
    }
    return [list object $entries]
  }

  repeatContainer ad_instproc json_value {value} {
    Recursively export repeated occurrences as a JSON array in numeric
    occurrence order. Omit the occurrence-zero template and create field
    metadata for stored occurrences on demand. Invalid legacy values
    remain strings.

    @param value Stored dictionary of occurrence names and values.
    @return Two-element ns_json type/payload pair; array payloads contain triples.
  } {
    if {[catch {dict size $value}]} {
      return [list string $value]
    }
    set occurrences {}
    dict for {name v} $value {
      set prefix ${:name}.
      if {[string first $prefix $name] != 0} {
        return [list string $value]
      }
      set index [string range $name [string length $prefix] end]
      if {![regexp {^(0|[1-9][0-9]*)$} $index]} {
        return [list string $value]
      }
      # Occurrence zero is the client-side template, not content.
      if {$index > 0} {
        lappend occurrences [list $index $name $v]
      }
    }
    set entries {}
    set i 0
    foreach occurrence [lsort -integer -index 0 $occurrences] {
      lassign $occurrence index name v
      set c ""
      foreach component ${:components} {
        if {[$component name] eq $name} {
          set c $component
          break
        }
      }
      if {$c eq ""} {
        set c [:require_component $index]
      }
      lassign [$c json_value $v] type payload
      lappend entries $i $type $payload
      incr i
    }
    return [list array $entries]
  }
}

::xo::library source_dependent

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
