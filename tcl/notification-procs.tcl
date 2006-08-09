ad_library {
  XoWiki - Notification procs
  
  @creation-date 2006-08-08
  @author Gustaf Neumann
  @cvs-id $Id$
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
	  -delivery_method_id [notification::delivery::get_id -short_name $delivery]
    }
    
    foreach interval {instant hourly daily} {
      notification::type::interval_enable -type_id $type_id \
	  -interval_id [notification::interval::get_id_from_name -name $interval]
    }
  }
  
  
  ad_proc -private ::xowiki::notifications-uninstall {} {
    
    set type_id [notification::type::get_type_id -short_name xowiki_notif]
    
    foreach delivery {email} {
      notification::type::delivery_method_disable -type_id $type_id \
	  -delivery_method_id [notification::delivery::get_id -short_name $delivery]
    }
    foreach interval {instant hourly daily} {
      notification::type::interval_disable -type_id $type_id \
	  -interval_id [notification::interval::get_id_from_name -name $interval]
    }
    
    notification::type::delete -short_name xowiki_notif
    
    acs_sc::impl::delete \
        -contract_name "NotificationType" \
        -impl_name xowiki_notif_type    
  }
}

namespace eval ::xowiki::notification {

  ad_proc -private get_url {revision_id} {
    return [::xowiki::url $revision_id]
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
      set page [::xowiki::Package instantiate_page_from_id -revision_id $revision_id]
      $page volatile
      $page absolute_links 1
      set html [$page render]
      set text [ad_html_text_convert -from text/html -to text/plain -- $html]
    } 
    ns_log notice "xowiki::notification::do_notifications called for item_id [$page set revision_id]"
    set link [::xowiki::Page pretty_link -absolute 1 [$page name]]
    append html "<p>For more details, see <a href='$link'>[$page set title]</a></p>"
    append text "\nFor more details, see $link\n"

    set state [expr {[$page set last_modified] eq [$page set creation_date] ? "New" : "Updated"}]
    
    notification::new \
        -type_id [notification::type::get_type_id -short_name xowiki_notif] \
        -object_id [$page set package_id] \
        -response_id [$page set revision_id] \
        -notif_subject "[$page set title] ($state)" \
        -notif_text $text \
        -notif_html $html \
        -notif_user [$page set creation_user]
  }


  ad_proc -private process_reply { reply_id} {
    handles a reply to an xowiki notif
    
    @author Deds Castillo (deds@i-manila.com.ph)
    @creation-date 2006-06-08
    
  } {
    # DEDS: need to decide on what to do with this
    # do we publish it as comment?
    # for now, drop it
    return "f"
  }  
}
