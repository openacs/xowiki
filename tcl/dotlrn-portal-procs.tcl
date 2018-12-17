::xo::library doc {
  XoWiki Portlets

  @author Gustaf Neumann
  @creation-date 2007-10-10
}

if {![apm_package_installed_p dotlrn]} {
  #
  # We have no dotlrn installed
  #
  return 
}


::xo::library require includelet-procs
::xo::library require xowiki-procs

namespace eval ::xowiki::includelet {
  #############################################################################
  #
  # dotlrn portlets
  #
  ::xowiki::IncludeletClass create dotlrn-portlet \
      -superclass ::xowiki::Includelet \
      -parameter {
        {cf ""}
        {shaded false}
        {community_id}
        {adp_file}
        {allow_multiple_community_ids true}
        {parameter_declaration {
          {-community_id:integer}
        }}
      }
  
  dotlrn-portlet instproc initialize {} {
    :get_parameters
    #
    # The community_id(s) can be determined currently in three ways

    #  1) The community_id(s) might be specified in the includelet
    #     definition: This makes it possible, to list on one portal
    #     page dotlrn portlets from different packages
    #
    #  2) The community_id(s) might be taken from a form page: This
    #     option can be used to make easily portal pages for different
    #     communities.
    #
    #  3) The community_id might be taken from the mount point via
    #     dotlrn_community::get_community_id (not implemented yet)
    #
    #  4) If non of the above is applicable, the list of community_ids
    #     is the list of all approved community memberships of the
    #     current user.  This option is typically used for a personal
    #     portal page.
    #
    if {[info exists community_id]} {
      #
      # case (1)
      #
      set :community_id $community_id
    } elseif {[info exists :__including_page]} {
      #
      # check case (2)
      #
      set including_page ${:__including_page}
      if {[$including_page exists instance_attributes]} {
        array set __ia [$including_page set instance_attributes]
        if {[info exists __ia(community_id)]} {
          # we get the community_id from the form page.
          set :community_id $__ia(community_id)
        }
      }
    }
    
    if {![info exists :community_id]} {
      #
      # we have no community_id, try to get it from site map, case (3)
      #
      set :community_id [dotlrn_community::get_community_id]
      #my msg "got from context ${:community_id}"
    }

    if {![info exists :community_id] || ${:community_id} eq ""} {
      #
      # we have no community_id, get all :community ids, case (4)
      #
      set user_id [::xo::cc user_id]
      set community_ids [db_list get_memberships {
        select community_id 
        from dotlrn_member_rels_approved
        where user_id = :user_id
      }]
      set :community_id $community_ids
    }
    
    if {${:community_id} eq ""} {
      error "Cannot determine community_id(s);\nmaybe, you are not logged in?\n"
    }
    if {[llength ${:community_id}]>1 && ![:allow_multiple_community_ids]} {
      error "This dotrln portlet allows only a single community_id;\nuse it only on community portals\n"
    }
    #
    # for multiple community_ids, compute a corresponding list of package_ids
    #
    set package_ids [list]
    foreach c ${:community_id} {
      if {[info exists :package_key]} {
        lappend package_ids [dotlrn_community::get_applet_package_id -community_id $c \
                                 -applet_key [dotlrn_[:package_key]::applet_key]]
      }
    }
    #my msg community_id=${:community_id}-package_ids=$package_ids
    :cf [list shaded_p [:shaded] community_id ${:community_id} package_id $package_ids]
  }

  dotlrn-portlet instproc render {} {
    :get_parameters
    return [template::adp_include ${:adp_file} [list cf ${:cf}]]
  }

  # MAIN (groups)
  ::xowiki::IncludeletClass create dotlrn-main -superclass dotlrn-portlet \
      -parameter {
        {adp_file "/packages/dotlrn/www/dotlrn-main-portlet"}
        {title "#dotlrn.dotlrn_main_portlet_pretty_name#"}
      }
  dotlrn-main instproc initialize {} {
    :cf [list shaded_p [:shaded]]
  }

  # DOTLRN (subgroups)
  ::xowiki::IncludeletClass create dotlrn-dotlrn -superclass dotlrn-portlet \
      -parameter {
        {allow_multiple_community_ids false}
        {adp_file "/packages/dotlrn-portlet/www/dotlrn-portlet"}
        {title "#dotlrn.subcommunities_pretty_plural#"}
      }

  # FORUMS
  ::xowiki::IncludeletClass create dotlrn-forums -superclass dotlrn-portlet \
      -parameter {
        {package_key "forums"}
        {adp_file "/packages/forums-portlet/www/forums-portlet"}
        {title "#forums-portlet.pretty_name#"}
      }
  
  # FAQ
  ::xowiki::IncludeletClass create dotlrn-faq -superclass dotlrn-portlet \
      -parameter {
        {package_key "faq"}
        {adp_file "/packages/faq-portlet/www/faq-portlet"}
        {title "#faq-portlet.pretty_name#"}
      }

  # NEWS
  ::xowiki::IncludeletClass create dotlrn-news -superclass dotlrn-portlet \
      -parameter {
        {package_key "news"}
        {adp_file "/packages/news-portlet/www/news-portlet"}
        {title "#news-portlet.pretty_name#"}
      }

  # CALENDAR
  ::xowiki::IncludeletClass create dotlrn-calendar -superclass dotlrn-portlet \
      -parameter {
        {package_key "calendar"}
        {adp_file "/packages/calendar-portlet/www/calendar-portlet"}
        {title "#calendar-portlet.pretty_name#"}
      }
  dotlrn-calendar instproc initialize {} {
    ::xo::Page requireCSS "/resources/calendar/calendar.css"
    next
    foreach c ${:community_id} {
      lappend calendar_ids [dotlrn_calendar::get_group_calendar_id -community_id $c]
    }
    lappend :cf default_view day scoped_p f calendar_id $calendar_ids
  }

  # SCHEDULE
  ::xowiki::IncludeletClass create dotlrn-schedule -superclass dotlrn-calendar \
      -parameter {
        {package_key "calendar"}
        {adp_file "/packages/calendar-portlet/www/calendar-list-portlet"}
        {title "#calendar-portlet.Schedule#"}
      }

  # Extra includelet (somewhat similar to static info portlet)
  ::xowiki::IncludeletClass create dotlrn-info -superclass dotlrn-portlet \
      -parameter {
        {allow_multiple_community_ids false}
        {title}
      }
  dotlrn-info instproc initialize {} {
    next
    :title [dotlrn_community::get_community_name ${:community_id}]
  }
  dotlrn-info instproc render {} {
    set key [dotlrn_community::get_community_key -community_id ${:community_id}]
    set page [${:package_id} resolve_page $key method]
    if {$page ne ""} {
      return [$page render]
    } else {
      #
      # If the content page does not exist, offer the user to create it.
      #
      set edit_snippet [${:package_id} create_new_snippet $key]
      return $edit_snippet
    }
  }

}

::xo::library source_dependent

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
