::xo::library doc {
  XoWiki table widget procs - interfacing ::xowiki::Pages with TableWidget

  @creation-date 2020-02-01
  @author Gustaf Neumann
}

::xo::library require -package xotcl-core 30-widget-procs

namespace eval ::xowiki {

  ::xotcl::Class create ::xowiki::TableWidget -superclass ::TableWidget

  ::xowiki::TableWidget proc create_from_form_fields {
    {-form_field_objs:required}
    {-package_id}
    {-buttons {}}
    {-hidden_field_names ""}
    {-bulk_actions ""}
    {-renderer ""}
    {-orderby ""}
  } {

    set actions ""
    set cols ""

    foreach form_field_obj $form_field_objs {
      dict set form_fields [$form_field_obj name] $form_field_obj
    }

    # we currently support only 'export' as bulk action
    set bulk_action_cols ""
    foreach bulk_action $bulk_actions {
      if {$bulk_action eq "export"} {
        append actions [list Action bulk-delete \
                            -label [_ xowiki.export] \
                            -tooltip [_ xowiki.export] \
                            -url [::$package_id package_url]admin/export \
                           ] \n
      }
    }
    if {[llength $bulk_actions] > 0} {
      append cols [subst {BulkAction create objects -id ID -actions {$actions}}] \n
      append cols {HiddenField create ID} \n
    }
    if {"publish_status" in $buttons} {
      append cols {ImageAnchorField create _publish_status \
                       -orderby _publish_status.src -src "" \
                       -width 8 -height 8 -title "Toggle Publish Status" \
                       -alt "publish status" -label [_ xowiki.publish_status] \
                       -CSSclass publish-status-item-button \
                       -html {style "padding: 2px;text-align: center;"}} \n
    }
    if {"edit" in $buttons} {
      append cols {AnchorField create _edit -CSSclass edit-item-button -label "" \
                       -html {style "padding: 2px;"} -no_csv 1 -richtext 1} \n
    }
    if {"duplicate" in $buttons} {
      append cols {AnchorField create _duplicate -CSSclass copy-item-button -label "" \
                       -html {style "padding: 2px;"} -no_csv 1 -richtext 1} \n
    }
    if {"view" in $buttons} {
      append cols {AnchorField create _view -CSSclass view-item-button -label "" \
                       -html {style "padding: 2px;"} -no_csv 1 -richtext 1} \n
    }
    if {"slim_publish_status" in $buttons} {
      append cols {ImageAnchorField create _publish_status \
                       -orderby _publish_status.src -src "" \
                       -width 8 -height 8 -title "Toggle Publish Status" \
                       -alt "publish status" -label "" \
                       -CSSclass publish-status-item-button \
                       -html {style "padding: 2px;text-align: center;"}} \n
    }

    set sort_fields {}
    foreach fn [dict keys $form_fields] {
      if {$fn in $hidden_field_names} continue
      set field_obj [dict get $form_fields $fn]
      set field_orderby [expr {$fn eq "_last_modified" ? "_raw_last_modified" : $fn}]
      set CSSclass [expr {[$field_obj exists td_CSSclass] ? [$field_obj td_CSSclass] : ""}]
      append cols [list AnchorField create $fn \
                       -label [$field_obj label] \
                       -richtext 1 \
                       -orderby $field_orderby \
                       -CSSclass $CSSclass \
                      ] \n
      lappend sort_fields $field_orderby
    }
    if {"delete" in $buttons} {
      #append cols [list ImageField_DeleteIcon _delete -label "" -no_csv 1] \n
      append cols [list AnchorField create _delete \
                       -CSSclass delete-item-button \
                       -label "" \
                       -no_csv 1 \
                       -richtext 1] \n
    }
    #ns_log notice "COLS\n$cols"

    set cmd [list ::xowiki::TableWidget create t1 -columns $cols]
    if {$renderer ne ""} {
      lappend cmd -renderer $renderer
    } else {
      switch [parameter::get_global_value \
                  -package_key xowiki \
                  -parameter PreferredCSSToolkit \
                  -default bootstrap] {
                    bootstrap {set renderer BootstrapTableRenderer}
                    default   {set renderer YUIDataTableRenderer}
                  }
      lappend cmd -renderer $renderer
    }
    set table_widget [{*}$cmd]

    #
    # Sorting is done for the time being in Tcl. This has the advantage
    # that page_order can be sorted with the special mixin and that
    # instance attributes can be used for sorting as well.
    #
    lassign [split $orderby ,] att order
    set sortable 1
    if {$att ni $sort_fields} {
      ad_log warning "Ignore invalid sorting criterion '$att'"
      util_user_message -message "Ignore invalid sorting criterion '$att'"
      set sortable 0
    }
    if {$sortable} {
      if {$att eq "_page_order"} {
        $table_widget mixin add ::xo::OrderedComposite::IndexCompare
      }
      #:msg "order=[expr {$order eq {asc} ? {increasing} : {decreasing}}] $att"
      $table_widget orderby -order [expr {$order eq "asc" ? "increasing" : "decreasing"}] $att
    }
    return $table_widget
  }

  #
  # Render a table with xowiki::FormPage elements with viewing,
  # editing, and deleting controls.
  #
  ::xowiki::TableWidget instproc render_page_items_as_table {
    {-form_field_objs:required}
    -package_id
    -items:required
    {-init_vars ""}
    {-uc {tcl false h "" vars "" sql ""}}
    {-view_field _name}
    {-buttons ""}
    {-package_relative_url:boolean false}
    {-form_item_ids ""}
    {-with_form_link:boolean false}
    {-csv:boolean false}
    {-generate}
    {-voting_dict ""}
    {-wf}
    {-view_filter_link}
    -return_url
    {-return_url_att return_url}
  } {

    foreach form_field_obj $form_field_objs {
      dict set form_fields [$form_field_obj name] $form_field_obj
    }
    set field_names [dict keys $form_fields]

    foreach p [$items children] {
      $p set package_id $package_id
      $p add_computed_instance_attributes
    }

    foreach p [$items children] {
      set __ia [dict merge $init_vars [$p instance_attributes]]

      if {[expr [dict get $uc tcl]]} continue
      #if {![expr $wc(tcl)]} continue ;# already handled in get_form_entries

      set page_link [$p pretty_link -path_encode false]
      if {[info exists view_filter_link]} {
        if {[info exists return_url] && $return_url_att ne "return_url"} {
          set $return_url_att $return_url
        }
        # we seem to need the extra subst for the $return_url_att
        set view_link [export_vars -base $view_filter_link [subst {{id "[$p item_id]"} $return_url_att}]]
      } elseif {[info exists wf]} {
        set view_link [export_vars -base $wf_link {{m create-or-use} {p.form "[$p name]"}}]
      } else {
        set view_link $page_link
      }
      :add
      set __c [:last_child]

      if {$package_relative_url} {
        # xowiki/www/admin/export expects a path to the object
        # relative to the package url
        set url [[$p package_id] folder_path -parent_id [$p parent_id]][$p name]
        $__c set ID $url
      }
      if {"publish_status" in $buttons || "slim_publish_status" in $buttons} {
        $__c set _publish_status "&nbsp;"
        $__c set _publish_status.title #xowiki.publish_status#
        if {[$p set publish_status] eq "ready"} {
          set image active.png
          set state "production"
        } else {
          set image inactive.png
          set state "ready"
        }
        set url [export_vars -base [::$package_id package_url]admin/set-publish-state \
                     {state {revision_id "[$p set revision_id]"} return_url}]
        $__c set _publish_status.src /resources/xowiki/$image
        $__c set _publish_status.href $url
      }
      if {"edit" in $buttons} {
        $__c set _edit "&nbsp;"
        $__c set _edit.title #xowiki.edit#
        $__c set _edit.href [::$package_id make_link -link $page_link $p edit return_url template_file]
      }
      if {"duplicate" in $buttons} {
        $__c set _duplicate "&nbsp;"
        $__c set _duplicate.title #xowiki.duplicate#
        $__c set _duplicate.href [::$package_id make_link -link $page_link $p duplicate return_url template_file]
      }
      if {"delete" in $buttons} {
        $__c set _delete "&nbsp;"
        $__c set _delete.title #xowiki.delete#
        $__c set _delete.href [::$package_id make_link -link $page_link $p delete return_url]
      }
      if {"view" in $buttons} {
        $__c set _view "&nbsp;"
        $__c set _view.title #xowiki.view#
        $__c set _view.href $view_link
      } elseif {"no-view" ni $buttons} {
        #
        # Set always a view link, if we have no view button ...
        #
        if {[dict exists $form_fields $view_field]} {
          # .... on $view_field) (per default: _name) ....
          $__c set $view_field.href $view_link
        } else {
          # .... otherwise on the first form_field
          $__c set _[lindex $field_names 0].href $view_link
        }
      }

      # set always last_modified for default sorting
      $__c set _last_modified [$p set last_modified]
      $__c set _raw_last_modified [$p set last_modified]

      foreach __fn $field_names form_field_obj $form_field_objs {
        $form_field_obj object $p
        set value [$p property $__fn]
        $__c set $__fn [$form_field_obj pretty_value $value]
      }
      $__c set _name [::$package_id external_name -parent_id [$p parent_id] [$p name]]
    }

    #
    # If there are multiple includelets on a single page,
    # we have to identify the right one for e.g. producing the
    # csv table. Therefore, we compute an includelet_key
    #
    set includelet_key ""
    foreach var {:name form_item_ids form publish_states field_names unless} {
      if {[info exists $var]} {append includelet_key $var : [set $var] ,}
    }

    set given_includelet_key [ns_base64urldecode [::xo::cc query_parameter includelet_key:graph ""]]
    if {$given_includelet_key ne ""} {
      if {![info exists generate]} {
        set generate [::xo::cc query_parameter generate:wordchar ""]
      }
      if {$given_includelet_key eq $includelet_key
          && [info exists generate] && $generate ne ""
        } {

        switch $generate {
          "csv" {
            return [:write_csv]
          }
          "voting_form" {
            if {[dict exists $voting_dict renderer]} {
              return [{*}[dict get $voting_dict renderer]]
            } else {
              ns_log warning "requested voting_form, but no renderer provided."
            }
          }
        }
      }
      return ""
    }

    set links [list]

    if {$with_form_link} {
      set form_links ""
      foreach form_item_id $form_item_ids {
        set base [::$form_item_id pretty_link]
        set label [::$form_item_id name]
        lappend form_links "<a href='[ns_quotehtml $base]'>[ns_quotehtml $label]</a>"
      }

      append html [_ xowiki.entries_using_form [list form [join $form_links ", "]]]
    }
    append html [:asHTML]

    if {$csv} {
      set encoded_includelet_key [ns_urlencode [ns_base64urlencode $includelet_key]]
      set csv_href "[::xo::cc url]?[::xo::cc actual_query]&includelet_key=$encoded_includelet_key&generate=csv"
      lappend links "<a href='[ns_quotehtml $csv_href]'>csv</a>"
    }
    if {[llength $voting_dict] != 0} {
      set voting_form [dict get $voting_dict voting_form]
      set encoded_includelet_key [ns_urlencode [ns_base64urlencode $includelet_key]]
      set href "[::xo::cc url]?[::xo::cc actual_query]&includelet_key=$encoded_includelet_key&generate=voting_form"
      lappend links " <a href='[ns_quotehtml $href]'>Generate Voting Form $voting_form</a>"
    }
    append html [join $links ,]
    #:log "render done"

    if {[info exists with_categories]} {
      set category_html [$o include [list categories -count 1 -tree_name $with_categories \
                                         -ordered_composite $base_items]]
      return "<div style='width: 15%; float: left;'>$category_html</div></div width='69%'>$html</div>\n"
    }
    return $html
  }

}
#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
