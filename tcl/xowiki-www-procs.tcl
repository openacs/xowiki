ad_library {
    XoWiki - www procs. These procs are the methods called on xowiki pages via 
    the web interface.

    @creation-date 2006-04-10
    @author Gustaf Neumann
    @cvs-id $Id$
}


namespace eval ::xowiki {
  
  Page instproc htmlFooter {{-content ""}} {
    my instvar package_id description
    if {[my exists __no_footer]} {return ""}

    set footer "<hr/>"

    if {$description eq ""} {
      set description [my get_description $content]
    }

    if {[ns_conn isconnected]} {
      set url         "[ns_conn location][::xo::cc url]"
      set package_url "[ns_conn location][$package_id package_url]"
    }

    if {[$package_id get_parameter "with_tags" 1] && 
        ![my exists_query_parameter no_tags] &&
        [::xo::cc user_id] != 0
      } {
      set tag_content "[my include_portlet my-tags]<br>"
      set tag_includelet [my set __last_includelet]
      set tags [$tag_includelet set tags]
    } else {
      set tag_content ""
      set tags ""
    }

    if {[$package_id get_parameter "with_digg" 0] && [info exists url]} {
      append footer "<div style='float: right'>" \
          [my include_portlet [list digg -description $description -url $url]] "</div>\n"
    }

    if {[$package_id get_parameter "with_delicious" 0] && [info exists url]} {
      append footer "<div style='float: right; padding-right: 10px;'>" \
          [my include_portlet [list delicious -description $description -url $url -tags $tags]] \
          "</div>\n"
    }

    if {[$package_id get_parameter "with_yahoo_publisher" 0] && [info exists package_url]} {
      append footer "<div style='float: right; padding-right: 10px;'>" \
          [my include_portlet [list my-yahoo-publisher \
                                   -publisher [::xo::get_user_name [::xo::cc user_id]] \
                                   -rssurl "$package_url?rss"]] \
          "</div>\n"
    }

    append footer [my include_portlet my-references]  <br>
    
    if {[$package_id get_parameter "show_per_object_categories" 1]} {
      append footer [my include_portlet my-categories]  <br>
      set categories_includelet [my set __last_includelet]
    }

    append footer $tag_content

    if {[$package_id get_parameter "with_general_comments" 0] &&
        ![my exists_query_parameter no_gc]} {
      append footer [my include_portlet my-general-comments] <br>
    }

    return  "<div style='clear: both; text-align: left; font-size: 85%;'>$footer</div>\n"
  }

  
  Page instproc view {} {
    # view is used only for the toplevel call, when the xowiki page is viewed
    # this is not inteded for embedded wiki pages
    my instvar package_id item_id 
    $package_id instvar folder_id  ;# this is the root folder
    ::xowiki::Page set recursion_count 0

    set template_file [my query_parameter "template_file" \
                           [::$package_id get_parameter template_file view-default]]

    if {[my isobject ::xowiki::$template_file]} {
      $template_file before_render [self]
    }
    
    set content [my render]
    my log "--after render"
    set footer [my htmlFooter -content $content]

    set top_portlets ""
    set vp [$package_id get_parameter "top_portlet" ""]
    if {$vp ne ""} {
      set top_portlets [my include_portlet $vp]
    }

    if {[$package_id get_parameter "with_user_tracking" 1]} {
      my record_last_visited
    }

    # Deal with the views package (many thanks to Malte for this snippet!)
    if {[$package_id get_parameter with_views_package_if_available 1] 
	&& [apm_package_installed_p "views"]} {
      views::record_view -object_id $item_id -viewer_id [::xo::cc user_id]
      array set views_data [views::get -object_id $item_id]
    }

    # export title, name and text into current scope
    my instvar title name text

    ### this was added by dave to address a problem with notifications
    ### however, this does not work, when e.g. a page is renamed.
    #set return_url [ad_return_url]

    if {[my exists_query_parameter return_url]} {
      set return_url [my query_parameter return_url]
    }
    
    if {[$package_id get_parameter "with_notifications" 1]} {
      if {[::xo::cc user_id] != 0} { ;# notifications require login
        set notifications_return_url [expr {[info exists return_url] ? $return_url : [ad_return_url]}]
        set notification_type [notification::type::get_type_id -short_name xowiki_notif]
        set notification_text "Subscribe the XoWiki instance"
        set notification_subscribe_link \
            [export_vars -base /notifications/request-new \
                 {{return_url $notifications_return_url}
                   {pretty_name $notification_text} 
                   {type_id $notification_type} 
                   {object_id $package_id}}]
        set notification_image \
           "<img style='border: 0px;' src='/resources/xowiki/email.png' \
	    alt='$notification_text' title='$notification_text'>"
      }
    }
    #my log "--after notifications [info exists notification_image]"

    set master [$package_id get_parameter "master" 1]
    #if {[my exists_query_parameter "edit_return_url"]} {
    #  set return_url [my query_parameter "edit_return_url"]
    #}
    my log "--after options"

    if {$master} {
      set context [list $title]
      set autoname    [$package_id get_parameter autoname 0]
      set object_type [$package_id get_parameter object_type [my info class]]
      set rev_link    [$package_id make_link [self] revisions]
      set edit_link   [$package_id make_link [self] edit return_url]
      set delete_link [$package_id make_link [self] delete return_url] 
      set new_link    [$package_id make_link $package_id edit-new object_type return_url autoname] 
      set admin_link  [$package_id make_link -privilege admin -link admin/ $package_id {} {}] 
      set index_link  [$package_id make_link -privilege public -link "" $package_id {} {}]
      set create_in_req_locale_link ""
      if {[$package_id get_parameter use_connection_locale 0]} {
        $package_id get_name_and_lang_from_path \
            [$package_id set object] req_lang req_local_name
        set default_lang [$package_id default_language]
        if {$req_lang ne $default_lang} {
          set l [Link create new -destroy_on_cleanup \
                     -page [self] -type language -stripped_name $req_local_name \
                     -name ${default_lang}:$req_local_name -lang $default_lang \
                     -label $req_local_name -folder_id $folder_id \
                     -package_id $package_id -init \
                     -return_only undefined]
          $l render
        }
      }

      my log "--after context delete_link=$delete_link "
      set template [$folder_id get_payload template]
      set page [self]

      if {$template ne ""} {
        set __including_page $page
        set __adp_stub [acs_root_dir]/packages/xowiki/www/view-default
        set template_code [template::adp_compile -string $template]
        if {[catch {set content [template::adp_eval template_code]} errmsg]} {
          ns_return 200 text/html "Error in Page $name: $errmsg<br/>$template"
        } else {
          ns_return 200 text/html $content
        }
      } else {
        # use adp file
        foreach css [$package_id get_parameter extra_css ""] {::xowiki::Page requireCSS $css}

        if {![regexp {^[./]} $template_file]} {
          set template_file /packages/xowiki/www/$template_file
        }
        set header_stuff [::xowiki::Page header_stuff]
        $package_id return_page -adp $template_file -variables {
          name title item_id context header_stuff return_url
          content footer package_id
          rev_link edit_link delete_link new_link admin_link index_link 
          notification_subscribe_link notification_image 
          top_portlets page
          views_data
        }
      }
    } else {
      ns_return 200 [::xo::cc get_parameter content-type text/html] $content
    }
  }

  Page instproc edit {{-new:boolean false} {-autoname:boolean false}} {
    my instvar package_id item_id revision_id
    $package_id instvar folder_id  ;# this is the root folder

    # set some default values if they are provided
    foreach key {name title last_page_id} {
      if {[$package_id exists_query_parameter $key]} {
        my set $key [$package_id query_parameter $key]
      }
    }

    set object_type [my info class]
    if {!$new && $object_type eq "::xowiki::Object" && [my set name] eq "::$folder_id"} {
      # if we edit the folder object, we have to do some extra magic here, 
      # since  the folder object has slightly different naming conventions.
      # ns_log notice "--editing folder object ::$folder_id, FLUSH $page"
      ns_cache flush xotcl_object_cache [self]
      ns_cache flush xotcl_object_cache ::$folder_id
      my move ::$folder_id
      set page ::$folder_id
      #ns_log notice "--move page=$page"
    } 

    #
    # setting up folder id for file selector (use community folder if available)
    #
    set fs_folder_id ""
    if {[info commands ::dotlrn_fs::get_community_shared_folder] ne ""} {
      set fs_folder_id [::dotlrn_fs::get_community_shared_folder \
                            -community_id [::dotlrn_community::get_community_id]]
    }

    # the following line is like [$package_id url], but works as well with renamed objects
    set myurl [expr {$new ? [$package_id url] :
                     [$package_id pretty_link [my form_parameter name]]}]

    set myurl [$package_id pretty_link [my form_parameter name]]

    if {[my exists_query_parameter "return_url"]} {
      set submit_link [my query_parameter "return_url" $myurl]
      set return_url $submit_link
    } else {
      set submit_link $myurl
    }
    #my log "--u my-url=$myurl, sumit_link=$submit_link qp=[my query_parameter return_url]"

    # we have to do template mangling here; ad_form_template writes form 
    # variables into the actual parselevel, so we have to be in our
    # own level in order to access an pass these
    variable ::template::parse_level
    lappend parse_level [info level]    
    set action_vars [expr {$new ? "{edit-new 1} object_type return_url" : "{m edit} return_url"}]
my log "--X get_form"
    [$object_type getFormClass -data [self]] create ::xowiki::f1 -volatile \
        -action  [export_vars -base [$package_id url] $action_vars] \
        -data [self] \
        -folderspec [expr {$fs_folder_id ne "" ?"folder_id $fs_folder_id":""}] \
        -submit_link $submit_link \
        -autoname $autoname

    if {[info exists return_url]} {
      ::xowiki::f1 generate -export [list [list return_url $return_url]]
    } else {
      ::xowiki::f1 generate
    }
my log "--X after generate"
    ::xowiki::f1 instvar edit_form_page_title context formTemplate
    
    if {[info exists item_id]} {
      set rev_link    [$package_id make_link [self] revisions]
      set view_link   [$package_id make_link [self] view]
    }
    if {[info exists last_page_id]} {
      set back_link [$package_id url]
    }
my log "--X call returnb_page"
    set index_link  [$package_id make_link -privilege public -link "" $package_id {} {}]
    set html [$package_id return_page -adp /packages/xowiki/www/edit \
                  -form f1 \
                  -variables {item_id edit_form_page_title context formTemplate
                    view_link back_link rev_link index_link}]
    template::util::lpop parse_level
    #my log "--e html length [string length $html]"
    return $html
  }

  File instproc download {} {
    my instvar text mime_type package_id item_id revision_id
    $package_id set mime_type $mime_type
    set use_bg_delivery [expr {![catch {ns_conn contentsentlength}] && 
                               [info command ::bgdelivery] ne ""}]
    $package_id set delivery \
        [expr {$use_bg_delivery ? "ad_returnfile_background" : "ns_returnfile"}]
    #my log "--F FILE=[my full_file_name]"
    return [my full_file_name]
  }

  Page instproc revisions {} {
    my instvar package_id name item_id
    set context [list [list [$package_id url] $name ] [_ xotcl-core.revisions]]
    set title "[_ xotcl-core.revision_title] '$name'"
    set content [next]
    $package_id return_page -adp /packages/xowiki/www/revisions -variables {
      content context {page_id $item_id} title
    }
  }

  Page instproc make-live-revision {} {
    my instvar revision_id item_id package_id
    my log "--M set_live_revision($revision_id)"
    ::xo::db::CONTENT_ITEM SET_LIVE_REVISION revision_id
    set page_id [my query_parameter "page_id"]
    ns_cache flush xotcl_object_cache ::$item_id
    ::$package_id returnredirect [my query_parameter "return_url" \
              [export_vars -base [$package_id url] {{m revisions}}]]
  }
  

  Page instproc delete-revision {} {
    my instvar revision_id package_id item_id 
    db_1row [my qn get_revision] "select latest_revision,live_revision from cr_items where item_id = $item_id"
    ns_cache flush xotcl_object_cache ::$item_id
    ns_cache flush xotcl_object_cache ::$revision_id
    ::xo::db::CONTENT_REVISION DEL {revision_id}
    set redirect [my query_parameter "return_url" \
                      [export_vars -base [$package_id url] {{m revisions}}]]
    if {$live_revision == $revision_id} {
      # latest revision might have changed by delete_revision, so we have to fetch here
      db_1row [my qn get_revision] "select latest_revision from cr_items where item_id = $item_id"
      if {$latest_revision eq ""} {
        # we are out of luck, this was the final revision, delete the item
        my instvar package_id name
        $package_id delete -name $name -item_id $item_id
      } else {
        ::xo::db::CONTENT_ITEM SET_LIVE_REVISION {{revision_id $latest_revision}}
      }
    }
    if {$latest_revision ne ""} {
      # otherwise, "delete" did already the redirect
      ::$package_id returnredirect [my query_parameter "return_url" \
                                      [export_vars -base [$package_id url] {{m revisions}}]]
    }
  }

  Page instproc delete {} {
    my instvar package_id item_id name parent_id
    $package_id delete -name $name -item_id $item_id
  }

  Page instproc save-tags {} {
    my instvar package_id item_id
    ::xowiki::Page save_tags -user_id [::xo::cc user_id] -item_id $item_id \
        -package_id $package_id [my form_parameter new_tags]

    ::$package_id returnredirect \
        [my query_parameter "return_url" [$package_id url]]
  }

  Page instproc popular-tags {} {
    my instvar package_id item_id parent_id
    set limit       [my query_parameter "limit" 20]
    set weblog_page [$package_id get_parameter weblog_page weblog]
    set href        [$package_id pretty_link $weblog_page]?summary=1

    set entries [list]
    db_foreach [my qn get_popular_tags] \
        "select count(*) as nr,tag from xowiki_tags \
         where item_id=$item_id group by tag order by nr limit $limit" {
           lappend entries "<a href='$href&ptag=[ad_urlencode $tag]'>$tag ($nr)</a>"
         }
    ns_return 200 text/html "[_ xowiki.popular_tags_label]: [join $entries {, }]"
  }

  Page instproc diff {} {
    my instvar package_id
    set compare_id [my query_parameter "compare_revision_id" 0]
    if {$compare_id == 0} {
      return ""
    }
    set my_page [::xowiki::Package instantiate_page_from_id -revision_id [my set revision_id]]
    $my_page volatile

    set html1 [$my_page render]
    set text1 [ad_html_text_convert -from text/html -to text/plain -- $html1]
    set user1 [::xo::get_user_name [$my_page set creation_user]]
    set time1 [$my_page set creation_date]
    set revision_id1 [$my_page set revision_id]
    regexp {^([^.]+)[.]} $time1 _ time1

    set other_page [::xowiki::Package instantiate_page_from_id -revision_id $compare_id]
    $other_page volatile
    #$other_page absolute_links 1

    set html2 [$other_page render]
    set text2 [ad_html_text_convert -from text/html -to text/plain -- $html2]
    set user2 [::xo::get_user_name [$other_page set creation_user]]
    set time2 [$other_page set creation_date]
    set revision_id2 [$other_page set revision_id]
    regexp {^([^.]+)[.]} $time2 _ time2

    set title "Differences for [my set name]"
    set context [list $title]

    set content [::xowiki::html_diff $text2 $text1]
    $package_id return_page -adp /packages/xowiki/www/diff -variables {
      content title context
      time1 time2 user1 user2 revision_id1 revision_id2
    }
  }

  proc html_diff {doc1 doc2} {
    set out ""
    set i 0
    set j 0
    
    #set lines1 [split $doc1 "\n"]
    #set lines2 [split $doc2 "\n"]
    
    regsub -all \n $doc1 " <br/>" doc1
    regsub -all \n $doc2 " <br/>" doc2
    set lines1 [split $doc1 " "]
    set lines2 [split $doc2 " "]
    
    foreach { x1 x2 } [list::longestCommonSubsequence $lines1 $lines2] {
      foreach p $x1 q $x2 {
        while { $i < $p } {
          set l [lindex $lines1 $i]
          incr i
          #puts "R\t$i\t\t$l"
          append out "<span class='removed'>$l</span>\n"
        }
        while { $j < $q } {
          set m [lindex $lines2 $j]
          incr j
          #puts "A\t\t$j\t$m"
          append out "<span class='added'>$m</span>\n"
        }
        set l [lindex $lines1 $i]
        incr i; incr j
        #puts "B\t$i\t$j\t$l"
      append out "$l\n"
      }
    }
    while { $i < [llength $lines1] } {
      set l [lindex $lines1 $i]
      incr i
      puts "$i\t\t$l"
      append out "<span class='removed'>$l</span>\n"
    }
    while { $j < [llength $lines2] } {
      set m [lindex $lines2 $j]
      incr j
      #puts "\t$j\t$m"
      append out "<span class='added'>$m</span>\n"
    }
    return $out
  }

}