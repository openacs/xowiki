::xo::library doc {
  XoWiki - Notification procs

  @creation-date 2006-08-08
  @author Gustaf Neumann
}

namespace eval ::xowiki {

  ad_proc -private ::xowiki::notifications-install {} {

    set impl_id [acs_sc::impl::new_from_spec -spec {
      name xowiki_notif_type
      contract_name NotificationType
      owner xowiki
      aliases {
        GetURL xowiki::notification::get_url
        ProcessReply xowiki::notification::process_reply
      }
    }]

    set type_id [notification::type::new \
                     -sc_impl_id $impl_id \
                     -short_name xowiki_notif \
                     -pretty_name "XoWiki Notification" \
                     -description "Notification of a new XoWiki page"]

    foreach delivery {email} {
      notification::type::delivery_method_enable -type_id $type_id \
          -delivery_method_id [notification::delivery::get_id \
                                   -short_name $delivery]
    }

    foreach interval {instant hourly daily} {
      notification::type::interval_enable -type_id $type_id \
          -interval_id [notification::interval::get_id_from_name \
                            -name $interval]
    }
  }


  ad_proc -private ::xowiki::notifications-uninstall {} {

    set type_id [notification::type::get_type_id -short_name xowiki_notif]

    foreach delivery {email} {
      notification::type::delivery_method_disable -type_id $type_id \
          -delivery_method_id [notification::delivery::get_id \
                                   -short_name $delivery]
    }
    foreach interval {instant hourly daily} {
      notification::type::interval_disable -type_id $type_id \
          -interval_id [notification::interval::get_id_from_name \
                            -name $interval]
    }

    notification::type::delete -short_name xowiki_notif

    acs_sc::impl::delete \
        -contract_name "NotificationType" \
        -impl_name xowiki_notif_type
  }
}

namespace eval ::xowiki::notification {

  ad_proc -private get_url {id} {
    if {[::xo::dc 0or1row is_package_id {
      select 1 from apm_packages where package_id = :id}]
      } {
      #
      # the specified id is a package_id
      #
      set node_id [::xo::dc get_value get_node_id {
        select node_id from site_nodes where object_id = :id
      }]
      set url [site_node::get_url -node_id $node_id]
      return $url
    }
    if {[category::get_name $id] ne ""} {
      #
      # the specified id is a category_id
      #
      # if we would know the package_id here, we could return something like
      #     /xowiki/weblog-portlet?summary=1&category_id=8380
      # however, since we have only a category_id, which might be mapped to
      # multiple xowiki instances, we give up here.
      return /categories
    }
    # id is a revision_id
    return [::xowiki::url $id]
  }


  ad_proc -public do_notifications {
    {-revision_id}
    {-page}
    {-html}
    {-text}
    {-new:boolean true}
  } {
    generate a notification
    @param revision_id
    @param new new or modified item
  } {

    if {![info exists page]} {
      set page [::xowiki::Package instantiate_page_from_id \
                    -revision_id $revision_id]
      $page volatile
    } else {
      set revision_id [$page set revision_id]
    }

    #ns_log notice "--n notification proc called for page [$page name] (revision_id $revision_id) in state [$page publish_status]"

    if {[$page set publish_status] eq "production"} {
      #
      # Don't do notification for pages under construction.
      #
      ns_log notice "--n xowiki::notification NO notification due to production state"
      return
    }
    set pretty_link [$page pretty_link]
    $page absolute_links 1
    if {![info exists html]} {
      set html [$page notification_render]
    }

    if {$html eq ""} {
      #
      # The notification renderer returned empty. Nothing to do.
      #
      #ns_log notice "--n notification renderer returned empty for page [$page name] (revision_id $revision_id). Nothing to do"
      return
    }

    #
    # Turn relative URLs into absolute URLs in the HTML text such that
    # links in notification still work. The function supports as well
    # non-wiki links. Here we are able to provide an accurate
    # pretty_link as base-url.
    #
    set html [ad_html_qualify_links -path [ad_file dirname $pretty_link] $html]

    if {![info exists text]} {
      set text [ad_html_text_convert -from text/html -to text/plain -- $html]
    }

    #ns_log notice "--n xowiki do_notifications called for revision_id $revision_id publish_status=[$page set publish_status]"
    set details [$page notification_detail_link]
    append html [dict get $details html]
    append text [dict get $details text]

    $page instvar package_id
    set state [expr {[$page set last_modified] eq [$page set creation_date]
                     ? "New" : "Updated"}]
    set instance_name [::$package_id instance_name]

    set notif_user_id [expr {[$page exists modifying_user]
                             ? [$page set modifying_user]
                             : [$page set creation_user]}]

    #ns_log notice "--n per directory [$page set title] ($state)"
    notification::new \
        -type_id [notification::type::get_type_id -short_name xowiki_notif] \
        -object_id [$page set package_id] \
        -response_id [$page set revision_id] \
        -notif_subject [$page notification_subject \
                            -instance_name $instance_name \
                            -state $state] \
        -notif_text $text \
        -notif_html $html \
        -notif_user $notif_user_id

    #ns_log notice "--n find categories [$page set title] ($state)"

    foreach cat_id [category::get_mapped_categories [$page set item_id] ] {
      set tree_id [category::get_tree $cat_id]
      array unset cat
      array unset label
      foreach category_info [::xowiki::Category get_category_infos \
                                 -tree_id $tree_id] {
        lassign $category_info category_id category_label deprecated_p level
        set cat($level) $category_id
        set label($level) $category_label
        if {$category_id == $cat_id} break
      }
      foreach level [array names cat] {
        #ns_log notice "--n category $cat($level) $label($level): [$page set title] ($state)"
        notification::new \
            -type_id [notification::type::get_type_id \
                          -short_name xowiki_notif] \
            -object_id $cat($level) \
            -response_id [$page set revision_id] \
            -notif_subject [$page notification_subject \
                                -instance_name $instance_name \
                                -category_label $label($level) \
                                -state $state] \
            -notif_text $text \
            -notif_html $html \
            -notif_user $notif_user_id
      }
    }
  }


  ad_proc -private process_reply { reply_id} {
    Handles a reply to an xowiki notification.

    @author Deds Castillo (deds@i-manila.com.ph)
    @creation-date 2006-06-08

  } {
    # DEDS: need to decide on what to do with this
    # do we publish it as comment?
    # for now, drop it
    return "f"
  }
}
::xo::library source_dependent

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
