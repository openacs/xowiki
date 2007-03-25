namespace eval ::xowiki {
  #
  # RSS 2.0 support
  #
  Class XMLSyndication -parameter {package_id}

  XMLSyndication instproc init {} {
    my set xmlMap [list & "&amp;" < "&lt;" > "&gt;" \" "&quot;" ' "&apos;"]
  }

  XMLSyndication instproc tag {{-atts } name value} {
    my instvar xmlMap
    set attsXML ""
    if {[info exists atts]} {
      foreach {attName attValue} $atts {
	append attsXML " $attName='[string map [list ' {&apos;} {&nbsp;} { }] $attValue]'"
      }
    }
    return <$name$attsXML>[string map $xmlMap $value]</$name>
  }

  Class RSS -superclass XMLSyndication -parameter {
    maxentries 
    {name_filter ""}
    {days ""}
    {css ""}
    {siteurl "[ad_url]"}
    {description ""}
    {language en-us}
    {title ""}
  } \
      -ad_doc {
    Report content of xowiki folder in rss 2.0 format. The
    reporting order is descending by date. The title of the feed
    is taken from the title, the description
    is taken from the description field of the folder object.
    
    @param maxentries maximum number of entries retrieved
    @param days report entries changed in speficied last days
    @param name_filter include only pages matching the provided regular expression (postgres)
    
  }

  RSS instproc css_link {} {
    my instvar css
    if {$css ne ""} {
      #
      # firefox 2.0 appears to overwrite the style info, so one has to use such ugly tricks:
      #    http://www.blingblog.info/2006/10/30/firefox-big-browser/
      # when we want to use custom style sheets
      #
      set user_agent [string tolower [ns_set get [ns_conn headers] User-Agent]]
      set filler [expr {[string first firefox $user_agent] >- 1 ?
                        "<!-- [string repeat deadbef 100] -->" : ""
                      }]
      set css_link [expr {[string match /* $css] ? $css : "/resources/xowiki/$css"}]
      return "\n<?xml-stylesheet type='text/css' href='$css_link' ?>\n$filler"
    }
    return ""
  }

  RSS instproc head {} {
    my instvar title link description language
    return "<?xml version='1.0' encoding='utf-8'?>[my css_link]
<rss version='2.0'
  xmlns:ent='http://www.purl.org/NET/ENT/1.0/'
  xmlns:dc='http://purl.org/dc/elements/1.1/'>
<channel>
  [my tag title $title]
  [my tag link $link]
  [my tag description $description]
  [my tag language $language]
  [my tag generator xowiki]"
  }

  RSS instproc item {-creator -title -link -guid -description -pubdate } {
    append result <item> \n\
        [my tag dc:creator $creator ] \n\
        [my tag title $title ] \n\
        [my tag link $link ] \n\
        [my tag -atts {isPermaLink false} guid $guid] \n\
        [my tag description $description ] \n\
        [my tag pubDate $pubdate ] \n\
        </item> \n
  }
  
  RSS instproc tail {} {
    return  "\n</channel>\n</rss>\n"
  }
  

  RSS instproc limit_clause {} {
    my instvar maxentries
    if {[info exists maxentries] && $maxentries ne ""} {
      return " limit $maxentries"
    } 
    return ""
  }

  RSS instproc extra_where_clause {} {
    my instvar name_filter days
    set extra_where_clause ""
    if {$name_filter ne ""} {
      append extra_where_clause " and ci.name ~ E'$name_filter' "
    }    
    if {$days ne ""} {
      append extra_where_clause " and p.last_modified > (now() + interval '$days days ago')" 
    }
    return $extra_where_clause
  }

  RSS instproc render {} {
    my instvar package_id max_entries name_filter title days description siteurl
    set folder_id [::$package_id folder_id]

    if {$description eq ""} {set description [::$folder_id set description]}
    my set link $siteurl[site_node::get_url_from_object_id -object_id $package_id]

    #my log "--rss WHERE= [my extra_where_clause]"

    set content [my head]
    db_foreach get_pages \
        "select s.body, p.name, p.creator, p.title, p.page_id,\
                p.object_type as content_type, p.last_modified, p.description  \
        from xowiki_pagex p, syndication s, cr_items ci  \
        where ci.parent_id = $folder_id and ci.live_revision = s.object_id \
                and ci.publish_status <> 'production' \
	        [my extra_where_clause] \
                and s.object_id = p.page_id \
        order by p.last_modified desc [my limit_clause] \
        " {
          
          if {[string match "::*" $name]} continue
          if {$content_type eq "::xowiki::PageTemplate"} continue

          set description [string trim $description]
          if {$description eq ""} {set description $body}
          regexp {^([^.]+)[.][0-9]+(.*)$} $last_modified _ time tz
          
          if {$title eq ""} {set title $name}
          #append title " ($content_type)"
          set time "[clock format [clock scan $time] -format {%a, %d %b %Y %T}] ${tz}00"
          append content [my item \
                              -creator $creator \
                              -title $title \
                              -link [::$package_id pretty_link -absolute true -siteurl $siteurl  $name] \
                              -guid $siteurl/$page_id \
                              -description $description \
                              -pubdate $time \
                             ]
        }
    
    append content [my tail]
    return $content
  }

  Class Podcast -superclass RSS -parameter {
    {subtitle ""} 
    {description ""}
    {summary ""}
    {author ""}
    {explicit "no"}
  }


  Podcast instproc head {} {
    my instvar title link description language subtitle summary author explicit

    return "<?xml version='1.0' encoding='utf-8'?>[my css_link]
<rss xmlns:itunes='http://www.itunes.com/dtds/podcast-1.0.dtd' version='2.0'>
<channel>
  [my tag title $title]
  [my tag link $link]
  [my tag description $description]
  [my tag language $language]
  [my tag generator xowiki]
  [my tag itunes:subtitle $subtitle]
  [my tag itunes:summary $summary]
  [my tag itunes:author $author]
  [my tag itunes:explicit $explicit]
"
  }

  Podcast instproc item {
    -author -title -subtitle -description 
    -link -guid -pubdate 
    -mime_type -duration -keywords} {
    append result \n <item> \
	[my tag title $title] \n\
	[my tag link $link ] \n\
        [my tag -atts {isPermaLink true} guid $guid] \n\
	[my tag pubDate $pubdate] \n\
	[my tag itunes:duration $duration] \n\
	[my tag author $author ] \n\
	[my tag description $description ] \n\
	[my tag itunes:subtitle $subtitle ] \n\
	[my tag itunes:author $author ] \n\
	[my tag itunes:keywords $keywords ] \n\
	"<enclosure url=\"$link\" length=\"$duration\" type=\"$mime_type\"/> " \
        \n </item> \n
  }


  Podcast instproc render {} {
    my instvar package_id max_entries name_filter title days \
	summary subtitle description author siteurl

    set folder_id [::$package_id folder_id]
    if {$description eq ""} {set description [::$folder_id set description]}
    if {$summary eq ""} {set summary $description}
    if {$subtitle eq ""} {set subtitle $title}

    my set link $siteurl[site_node::get_url_from_object_id -object_id $package_id]
    
    set content [my head]
    db_foreach get_pages \
        "select * from xowiki_podcast_itemi p, cr_items ci, cr_mime_types m \
        where ci.parent_id = $folder_id and ci.item_id = p.item_id \
              and ci.live_revision = p.object_id \
              and p.mime_type = m.mime_type \
              and ci.publish_status <> 'production' [my extra_where_clause] \
        order by p.last_modified desc [my limit_clause] \
        " {
          
          if {$content_type ne "::xowiki::PodcastItem"} continue

          #regexp {^([^.]+)[.][0-9]+(.*)$} $last_modified _ time tz
          
          if {$title eq ""} {set title $name}
          #set time "[clock format [clock scan $time] -format {%a, %d %b %Y %T}] ${tz}00"
	  set link [::$package_id pretty_link -absolute true -siteurl $siteurl $name]/download.$file_extension
	  append content [my item \
			      -author $creator -title $title -subtitle $subtitle \
                              -description $description \
			      -link $link -mime_type $mime_type \
			      -guid $link -pubdate $pub_date -duration $duration \
			      -keywords $keywords]
        }
    
    append content [my tail]
    return $content
  }
  
  Class Timeline -superclass XMLSyndication \
	-parameter {user_id {limit 1000}}

  Timeline instproc reverse list {
    set result [list]
    for {set i [expr {[llength $list] - 1}]} {$i >= 0} {incr i -1}  	{
      lappend result [lindex $list $i]
    }
    return $result
  }

  Timeline instproc render {} {
    my instvar package_id 
    set folder_id [::$package_id folder_id]
    set where_clause ""
    set limit_clause ""

    set last_user ""
    set last_item ""
    set last_clock ""
    if {[my exists user_id]} { append where_clause " and creation_user = [my user_id] " }
    if {[my exists limit]} { append limit_clause  " limit [my limit] " }

    ::xo::OrderedComposite items -destroy_on_cleanup
    db_foreach get_pages "
      select ci.name, o.creation_user, cr.publish_date, o2.creation_date, cr.item_id, ci.parent_id, cr.title
      from cr_items ci, cr_revisions cr, acs_objects o, acs_objects o2 
      where cr.item_id = ci.item_id and o.object_id = cr.revision_id 
      and o2.object_id = cr.item_id 
      and ci.parent_id = :folder_id and o.creation_user is not null 
      $where_clause order by revision_id desc $limit_clause
    " {
      regexp {^([^.]+)[.][0-9]+(.*)$} $publish_date _ publish_date tz
      regexp {^([^.]+)[.][0-9]+(.*)$} $creation_date _ creation_date tz
      set clock [clock scan $publish_date]

      if {$last_user == $creation_user && $last_item == $item_id && $last_clock ne ""} {
        #my log "--clockdiff = [expr {$last_clock - $clock }] $name"
        if {($last_clock - $clock) < 7500 } {
          #my log "--clock ignore change due to cockdiff"
          continue
        }
      }
      set o [Object new]
      foreach att {item_id creation_user item_id clock name publish_date parent_id title} {
        $o set $att [set $att]
      }
      $o set operation [expr {$creation_date eq $oublish_date ? "created" : "modified"}]

      items add $o
      foreach {last_user last_item last_clock} [list $creation_user $item_id $clock] break
    }

    # The following loop tries to distinguis between create and modify by age.
    # This does not work in cases, where we get just a limited amount 
    # or restricted entries
#     if {$limit_clause eq ""} {
#       foreach i [my reverse [items children]] {
#         set key seen([$i set item_id])
#         if {[info exists $key]} {
#           $i set operation modified
#         } else {
#           $i set operation created
#           set $key 1
#         }
#       }
#     }

    set result <data>\n
    foreach i [items children] {
      set stamp [clock format [$i set clock] -format "%b %d %Y %X %Z" -gmt true]
      set user [::xo::get_user_name [$i set creation_user]]
      append result [my tag -atts [list \
                                       start $stamp \
                                       title [$i set title] \
                                       link [$package_id pretty_link [$i set name]]] \
                         event "$user [$i set operation] [$i set title]"] \n
    }
    append result </data>\n
    return $result
  }
}
