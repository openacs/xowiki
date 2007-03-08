ad_library {
    XoWiki - www procs. These procs are the methods called on xowiki pages via 
    the web interface.

    @creation-date 2006-04-10
    @author Gustaf Neumann
    @cvs-id $Id$
}

namespace eval ::xowiki {
  
  Page instproc view {} {
    # view is used only for the toplevel call, when the xowiki page is viewed
    # this is not inteded for embedded wiki pages
    my instvar package_id item_id 
    $package_id instvar folder_id  ;# this is the root folder
    ::xowiki::Page set recursion_count 0

    set content [my render]
    my log "--after render"

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

    #my log "--after user_tracking"
    set references [my references]
    #my log "--after references = <$references>"

    # export title, name and text into current scope
    my instvar title name text

    set tags ""
    set no_tags 1
    if {[$package_id get_parameter "with_tags" 1] && 
        ![my exists_query_parameter no_tags]} {
      # only activate tags when the user is logged in
      set no_tags [expr {[::xo::cc user_id] == 0}]
      set tags ""
      if {!$no_tags} {
        ::xowiki::Page requireJS  "/resources/xowiki/get-http-object.js"
        set entries [list]
        set tags [lsort [::xowiki::Page get_tags -user_id [::xo::cc user_id] \
                             -item_id $item_id -package_id $package_id]]
        set href [$package_id package_url]weblog?summary=1
        foreach tag $tags {lappend entries "<a href='$href&tag=[ad_urlencode $tag]'>$tag</a>"}
        set tags_with_links [join $entries {, }]
      }
    }
    #my log "--after tags"

    ### this was added by dave to address a problem with notifications
    ### however, this does not work, when e.g. a page is renamed.
    #set return_url [ad_return_url]

    if {[my exists_query_parameter return_url]} {
      set return_url [my query_parameter return_url]
    }
    
    if {[$package_id get_parameter "with_notifications" 1]} {
      if {[::xo::cc user_id] != 0} { ;# notifications require login
        set notifications_return_url [expr {[info exists return_url] ? $return_url : [ad_return_url]}]
        set notification_type [notification::type::get_type_id \
                                   -short_name xowiki_notif]
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
    

    if {[$package_id get_parameter "show_per_object_categories" 1]} {
      set entries [list]
      set href [$package_id package_url]weblog?summary=1
      foreach cat_id [category::get_mapped_categories $item_id] {
        foreach {category_id category_name tree_id tree_name} [category::get_data $cat_id] break
        #my log "--cat $cat_id $category_id $category_name $tree_id $tree_name"
        set entry "<a href='$href&category_id=$category_id'>$category_name ($tree_name)</a>"
        if {[info exists notification_image]} {
          set notification_text "Subscribe category $category_name in tree $tree_name"
          set cat_notif_link [export_vars -base /notifications/request-new \
                                  {{return_url $notifications_return_url} \
                                       {pretty_name $notification_text} \
                                       {type_id $notification_type} \
                                       {object_id $category_id}}]
          append entry "<a href='$cat_notif_link'> " \
              "<img style='border: 0px;' src='/resources/xowiki/email.png' " \
              "alt='$notification_text' title='$notification_text'>" </a>
        }
        lappend entries $entry
      }
      set per_object_categories_with_links [join $entries {, }]
    }
    #my log "--after tags"

    if {[$package_id get_parameter "with_general_comments" 0] && 
        ![my exists_query_parameter no_gc]} {
      set gc_return_url [$package_id url]
      set gc_link     [general_comments_create_link -object_name $title $item_id $gc_return_url]
      set gc_comments [general_comments_get_comments $item_id $gc_return_url]
    } else {
      set gc_link ""
      set gc_comments ""
    }
    #my log "--after gc title=$title"

    if {[$package_id get_parameter "with_digg" 0] && [ns_conn isconnected]} {
      set digg_description [my set description]
      if {$digg_description eq ""} {
	set digg_description [ad_html_text_convert -from text/html -to text/plain -- $content]
      }
      set digg_link [export_vars -base "http://digg.com/submit" {
        {phase 2} 
        {url       "[ns_conn location][::xo::cc url]"}
        {title     "[string range $title 0 74]"}
        {body_text "[string range $digg_description 0 349]"}
      }]
    }
    if {[$package_id get_parameter "with_delicious" 0] && [ns_conn isconnected]} {
      set delicious_description [my set description]
      if {$delicious_description eq ""} {
        set delicious_description [ad_html_text_convert -from text/html -to text/plain -- $content]
      }
      # the following opens a window, where a user can edit the posted info.
      # however, it seems not possible to add tags this way automatically.
      # Alternatively, one could use the api as descibed below; this allows
      # tags, but no editing...
      # http://farm.tucows.com/blog/_archives/2005/3/24/462869.html#adding
      set delicious_link [export_vars -base "http://del.icio.us/post" {
        {v 4}
        {url   "[ns_conn location][::xo::cc url]"}
        {title "[string range $title 0 79]"}
        {notes "[string range $delicious_description 0 199]"}
        tags
      }]
    }
    #my log "--after delicious"

    set my_yahoo_publisher [$package_id get_parameter "my_yahoo_publisher" ""]
    if {$my_yahoo_publisher ne "" && [ns_conn isconnected]} {
      set my_yahoo_publisher [ad_urlencode $my_yahoo_publisher]
      set feedname [ad_urlencode [$folder_id set title]]
      set rssurl [ad_urlencode "[ad_url][$package_id package_url]?rss"]
      set my_yahoo_link "http://us.rd.yahoo.com/my/atm/$my_yahoo_publisher/$feedname/*http://add.my.yahoo.com/rss?url=$rssurl"
    }

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
      set admin_link  [$package_id make_link -privilege admin -url admin/ $package_id {} {}] 
      set index_link  [$package_id make_link -privilege public -url "" $package_id {} {}]
      set save_tag_link [$package_id make_link [self] save-tags]
      set popular_tags_link [$package_id make_link [self] popular-tags]
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

      foreach i [my array names lang_links] {
        set lang_links($i) [join [my set lang_links($i)] ", "]
        #my log "--lang_links($i) = '$lang_links($i)'"
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
        set template_file [my query_parameter "template_file" \
                               [::$package_id get_parameter template_file view-default]]

        if {![regexp {^[./]} $template_file]} {
          set template_file /packages/xowiki/www/$template_file
        }
        set header_stuff [::xowiki::Page header_stuff]
        $package_id return_page -adp $template_file -variables {
          references name title item_id page context header_stuff return_url
          content references lang_links package_id
          rev_link edit_link delete_link new_link admin_link index_link 
          tags no_tags tags_with_links save_tag_link popular_tags_link 
          create_in_req_locale_link req_lang
          per_object_categories_with_links 
          digg_link delicious_link my_yahoo_link
          gc_link gc_comments notification_subscribe_link notification_image 
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
    ::xowiki::f1 instvar edit_form_page_title context formTemplate
    
    if {[info exists item_id]} {
      set rev_link    [$package_id make_link [self] revisions]
      set view_link   [$package_id make_link [self] view]
    }
    if {[info exists last_page_id]} {
      set back_link [$package_id url]
    }

    set index_link  [$package_id make_link -privilege public -url "" $package_id {} {}]
    set html [$package_id return_page -adp /packages/xowiki/www/edit \
                  -form f1 \
                  -variables {item_id edit_form_page_title context formTemplate
                    view_link back_link rev_link index_link}]
    template::util::lpop parse_level
    my log "--e html length [string length $html]"
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
    db_exec_plsql make_live {select content_item__set_live_revision(:revision_id)}
    set page_id [my query_parameter "page_id"]
    ns_cache flush xotcl_object_cache ::$item_id
    ::$package_id returnredirect [my query_parameter "return_url" \
              [export_vars -base [$package_id url] {{m revisions}}]]
  }
  

  Page instproc delete-revision {} {
    my instvar revision_id package_id item_id 
    db_1row get_revision "select latest_revision,live_revision from cr_items where item_id = $item_id"
    ns_cache flush xotcl_object_cache ::$item_id
    ns_cache flush xotcl_object_cache ::$revision_id
    db_exec_plsql delete_revision {select content_revision__del(:revision_id)}
    set redirect [my query_parameter "return_url" \
                      [export_vars -base [$package_id url] {{m revisions}}]]
    if {$live_revision == $revision_id} {
      # latest revision might have changed by delete_revision, so we have to fetch here
      db_1row get_revision "select latest_revision from cr_items where item_id = $item_id"
      if {$latest_revision eq ""} {
        # we are out of luck, this was the final revision, delete the item
        my instvar package_id name
        $package_id delete -name $name -item_id $item_id
      } else {
        db_0or1row make_live "select content_item__set_live_revision($latest_revision)"
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
    set limit [my query_parameter "limit" 20]
    set href [$package_id package_url]weblog?summary=1
    set entries [list]
    db_foreach get_popular_tags \
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
