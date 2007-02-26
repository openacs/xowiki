namespace eval ::xowiki {
  #
  # RSS 2.0 support
  #

  Class RSS -parameter {
    package_id 
    maxentries 
    {name_filter ""}
    {days ""}
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

  RSS instproc init {} {
    my set xmlMap [list & "&amp;" < "&lt;" > "&gt;" \" "&quot;" ' "&apos;"]
  }

  RSS instproc tag {{-atts } name value} {
    my instvar xmlMap
    set attsXML ""
    if {[info exists atts]} {
      foreach {attName attValue} $atts {
	append attsXML " $attName='$attValue'"
      }
    }
    return <$name$attsXML>[string map $xmlMap $value]</$name>
  }

  RSS instproc head {} {
    my instvar title link description language
#<?xml-stylesheet type='text/css' href='http://localhost:8002/resources/xowiki/rss.css' ?>
    return "<?xml version='1.0' encoding='utf-8'?>
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
#<?xml-stylesheet type='text/css' href='http://localhost:8002/resources/xowiki/rss.css' ?>
    return "<?xml version='1.0' encoding='utf-8'?>
<rss xmlns:itunes=\"http://www.itunes.com/dtds/podcast-1.0.dtd\" version=\"2.0\">
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
    -author -title -subtitle 
    -link -guid -pubdate 
    -mime_type -duration -keywords} {
    append result \n <item> \
	[my tag title $title] \n\
	[my tag link $link ] \n\
        [my tag -atts {isPermaLink true} guid $guid] \n\
	[my tag pubDate $pubdate] \n\
	[my tag itunes:duration $duration] \n\
	[my tag author $author ] \n\
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
			      -link $link -mime_type $mime_type \
			      -guid $link -pubdate $pub_date -duration $duration \
			      -keywords $keywords]
        }
    
    append content [my tail]
    return $content
  }
  

}