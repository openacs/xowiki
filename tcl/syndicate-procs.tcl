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

  Class create RSS -superclass XMLSyndication -parameter {
    maxentries 
    {parent_ids ""}
    {name_filter ""}
    {entries_of ""}
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
      set css_link [expr {[string match "/*" $css] ? $css : "/resources/xowiki/$css"}]
      return "\n<?xml-stylesheet type='text/css' href='$css_link' ?>\n$filler"
    }
    return ""
  }

  RSS instproc head {} {
    my instvar title link description language
    return "<?xml version='1.0' encoding='utf-8'?>[my css_link]
<rss version='2.0'
  xmlns:ent='http://www.purl.org/NET/ENT/1.0/'
  xmlns:content='http://purl.org/rss/1.0/modules/content/'
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
  

  RSS instproc limit {} {
    my instvar maxentries
    if {[info exists maxentries] && $maxentries ne ""} {
      return $maxentries
    } 
    return ""
  }

  RSS instproc extra_where_clause {} {
    my instvar name_filter days entries_of package_id
    set extra_where_clause ""
    if {$name_filter ne ""} {
      append extra_where_clause " and ci.name ~ E'$name_filter' "
    }    
    if {$days ne ""} {
      append extra_where_clause "and " \
          [::xo::db::sql since_interval_condition p.publish_date "$days days"]
    }
    if {$entries_of ne ""} {
      if {[regexp {^[0-9 ]+$} $entries_of]} {
        # form item_ids were provided as a filter
        set form_items $entries_of
      } else {
        set form_items [::xowiki::Weblog instantiate_forms \
                            -forms $entries_of \
                            -package_id $package_id]
      }

      if {[llength $form_items] == 0} {
	# In case, we have no form_items to select on, let the query fail 
	# without causing a SQL error.
	set form_items [list -1]
      }
      append extra_where_clause " and p.page_template in ('[join $form_items ',']') and p.page_instance_id = p.revision_id "

      my set base_table xowiki_form_pagex
    }
    return $extra_where_clause
  }

  RSS instproc render {} {
    my instvar package_id max_entries name_filter title days description siteurl base_table

    if {[my parent_ids] ne ""} {
      set folder_ids [my parent_ids]
    } else {
      set folder_ids [::$package_id folder_id]
    }

    my set link $siteurl[lindex [site_node::get_url_from_object_id -object_id $package_id] 0]
    
    set base_table xowiki_pagex 
    set extra_where_clause [my extra_where_clause]

    if {$base_table ne "xowiki_pagex"} {
      # we assume, we retrieve the entries for a form
      set extra_from ""
    } else {
      # return always instance_attributes
      set extra_from "left join \
		xowiki_page_instance on (p.revision_id = page_instance_id)"
    }

    set sql [::xo::db::sql select \
                 -vars "s.body, s.rss_xml_frag, p.name, p.creator, p.title, p.page_id, instance_attributes, \
                p.object_type as content_type, p.publish_date, p.description" \
                 -from "syndication s, cr_items ci, $base_table p $extra_from" \
                 -where "ci.parent_id in ([join $folder_ids ,]) \
			and ci.live_revision = s.object_id \
                	and ci.publish_status <> 'production' \
                	and s.object_id = p.page_id \
	        	$extra_where_clause"\
                 -orderby "p.publish_date desc" \
                 -limit [my limit]]

    set content [my head]
    db_foreach [my qn get_pages] $sql {
      if {[string match "::*" $name]} continue
      if {$content_type eq "::xowiki::PageTemplate" || $content_type eq "::xowiki::Form"} continue
      append content $rss_xml_frag
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

    set folder_ids [::$package_id folder_id]
    if {$summary  eq ""} {set summary $description}
    if {$subtitle eq ""} {set subtitle $title}

    my set link $siteurl[lindex [site_node::get_url_from_object_id -object_id $package_id] 0]
    
    set content [my head]
    set sql [::xo::db::sql select \
                 -vars * \
                 -from "xowiki_podcast_itemi p, cr_items ci, cr_mime_types m" \
                 -where  "ci.parent_id in ([join $folder_ids ,]) and ci.item_id = p.item_id \
              and ci.live_revision = p.object_id \
              and p.mime_type = m.mime_type \
              and ci.publish_status <> 'production' [my extra_where_clause]" \
                 -orderby "p.pub_date asc" \
                 -limit [my limit]]
             
    db_foreach [my qn get_pages] $sql {
      if {$content_type ne "::xowiki::PodcastItem"} continue
      if {$title eq ""} {set title $name}
      set link [::$package_id pretty_link -download true -absolute true -siteurl $siteurl \
                    -parent_id $parent_id $name]
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
    set folder_ids [::$package_id folder_id]
    set where_clause ""
    set limit ""

    set last_user ""
    set last_item ""
    set last_clock ""
    if {[my exists user_id]} { append where_clause " and o.creation_user = [my user_id] " }
    if {[my exists limit]} { set limit  [my limit] }

    ::xo::OrderedComposite items -destroy_on_cleanup
    set sql [::xo::db::sql select \
                 -vars "ci.name, ci.parent_id, o.creation_user, cr.publish_date, o2.creation_date, \
			cr.item_id, cr.title" \
                 -from "cr_items ci, cr_revisions cr, acs_objects o, acs_objects o2" \
                 -where "cr.item_id = ci.item_id and o.object_id = cr.revision_id 
      			and o2.object_id = cr.item_id 
		      	and ci.parent_id in ([join $folder_ids ,]) and o.creation_user is not null 
      			$where_clause" \
                 -orderby "revision_id desc" \
                 -limit $limit]
    db_foreach [my qn get_pages] $sql {
      set publish_date [::xo::db::tcl_date $publish_date tz]
      set creation_date [::xo::db::tcl_date $creation_date tz]
      set clock [clock scan $publish_date]

      if {$last_user == $creation_user && $last_item == $item_id && $last_clock ne ""} {
        #my log "--clockdiff = [expr {$last_clock - $clock }] $name [clock format $clock -format {%b %d %Y %X %Z} -gmt true]"
        if {($last_clock - $clock) < 7500 } {
          #my log "--clock ignore change due to cockdiff"
          continue
        }
      }
      set o [Object new]
      foreach att {item_id creation_user clock name publish_date parent_id title} {
        $o set $att [set $att]
      }
      $o set operation [expr {$creation_date eq $publish_date ? "created" : "modified"}]

      items add $o
      foreach {last_user last_item last_clock} [list $creation_user $item_id $clock] break
    }

    # The following loop tries to distinguis between create and modify by age.
    # This does not work in cases, where we get just a limited amount 
    # or restricted entries
#     if {$limit eq ""} {
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

    foreach i [items children] {
      set key contrib([clock format [$i set clock] -format "%Y-%m-%d" -gmt true],[$i set creation_user],[$i set item_id])
      lappend $key $i
    }

    set result <data>\n

    foreach c [lsort -decreasing [array names contrib]] {
      if {[llength $contrib($c)] == 1} {
         set i $contrib($c)
         set title [$i set title]
      set user [::xo::get_user_name [$i set creation_user]]
         set event "$user [$i set operation] [$i set title] [$i set name]"
      } else {
         set i [lindex $contrib($c) 0]
         set event "Contributions by [::xo::get_user_name [$i set creation_user]] on [clock format [$i set clock] -format {%b %d %Y} -gmt true]\n<ul>"
         set title "[$i set title] ([llength $contrib($c)])"
         foreach j $contrib($c) {
            set stamp [clock format [$j set clock] -format "%X %Z" -gmt true]
            append  event "<li>$stamp: [$j set operation]</li>" \n
         }
         append event "</ul>" \n
      }
      set stamp [clock format [$i set clock] -format "%b %d %Y %X %Z" -gmt true]
      set user [::xo::get_user_name [$i set creation_user]]
      append result [my tag -atts [list \
                                       start $stamp \
                                       title $title \
                                       link [$package_id pretty_link \
                                                 -parent_id [$i set parent_id] \
                                                 [$i set name]]] \
                         event $event]  \n
    }
    append result </data>\n
    return $result
  }
}

namespace eval ::xowiki {
  # This is the class representing an RSS client
  Class create RSS-client -parameter url
    
  # Constructor for a given URI
  RSS-client instproc init {} {
    set XML [my load]
    if {$XML ne ""} {
      my parse $XML
    }
  }
  
  RSS-client instproc load { } {
    set r [::xo::HttpRequest new -url [my url] -volatile]
    #my msg "statuscode = [$r set status_code], content_type=[$r set content_type]"
    #set f [open /tmp/feed w]; fconfigure $f -translation binary; puts $f [$r set data]; close $f
    if {[$r exists status] && [$r set status] eq "canceled"} {
      my set errorMessage [$r set cancel_message]
    }
    return [$r set data]
    # the following does not appear to be necessary due to changes in http-client-procs. 
    #set charset utf-8
    #regexp {^<\?xml\s+version\s*=\s*\S+\s+encoding\s*=\s*[\"'](\S+)[\"']} $xml _ charset
    #ns_log notice "charse=$charset,xml=$xml"
    #return [encoding convertfrom [string tolower $charset] $xml]
  }

  RSS-client instproc parse {data} {
    set doc [ dom parse $data ]
    set root [ $doc documentElement ]

    switch [RSS-client getRSSVersion $doc] {
      0.91 - 0.92 - 0.93 - 2.0 {
        my array set xpath {
          title		{/rss/channel/title/text()}
          link		{/rss/channel/link/text()}
          imgNode	{/rss/channel/image/title}
          imgTitle	{/rss/channel/image/title/text()}
          imgLink	{/rss/channel/image/url/text()}
          imgWidth	{/rss/channel/image/width/text()}
          imgHeight	{/rss/channel/image/height/text()}
          stories	{/rss/channel/item}
          itemTitle	{title/text()}
          itemLink	{link/text()}
          itemPubDate	{pubDate/text()}
          itemDesc	{description/text()}
        }
      }
      1.0 {
        my array set xpath {
          title		{/rdf:RDF/*[local-name()='channel']/*[local-name()='title']/text()}
          link		{/rdf:RDF/*[local-name()='channel']/*[local-name()='link']/text()}
          imgNode	{/rdf:RDF/*[local-name()='image']}
          imgTitle	{/rdf:RDF/*[local-name()='image']/*[local-name()='title']/text()}
          imgLink	{/rdf:RDF/*[local-name()='image']/*[local-name()='url']/text()}
          imgWidth	{/rdf:RDF/*[local-name()='image']/*[local-name()='width']/text()}
          imgHeight	{/rdf:RDF/*[local-name()='image']/*[local-name()='height']/text()}
          stories	{/rdf:RDF/*[local-name()='item']}
          itemTitle	{*[local-name()='title']/text()}
          itemLink	{*[local-name()='link']/text()}
          itemPubDate	{*[local-name()='pubDate']/text()}
          itemDesc	{*[local-name()='description']/text()}
        }
        
      }
      default {
	my set errorMessage "Unsupported RSS schema [RSS-client getRSSVersion $doc]"
	return
        #error "Unsupported schema [RSS-client getRSSVersion $doc]"
      }
    }

    # Channel
    set cN [ $root child 1 channel ]
    set channel [::xowiki::RSS-client::channel create [self]::channel -root $cN]

    # Items
    my set items {}
    set stories [$root selectNodes [my set xpath(stories)] ]
    foreach iN $stories {
      my lappend items [::xowiki::RSS-client::item new -childof [self] -node $iN ]
    }
  }

  # returns the XPath Query for a given type
  RSS-client instproc xpath { key } {
    return [my set xpath($key)]
  }

  # returns the channel object
  RSS-client instproc channel {} {
    return [self]::channel
  }

  # returns a list of items
  RSS-client instproc items {} {
    return [my set items]
  }

  # detects the RSS version of the document
  RSS-client proc getRSSVersion {doc} {
    set root [$doc documentElement]
    switch [$root nodeName] {
      rss {
        if {[$root hasAttribute version]} {
          return [$root getAttribute version]
        }
        # Best guess as most stuff is optional...
        return 0.92
      }
      rdf:RDF {
        return 1.0
      }
      default {
        return 0
      }
    }
  }

  # this namespace contains some utility methods
  RSS-client proc node_uri {node xpath} {
    set n [$node selectNode $xpath]
    if {$n ne ""} {
      # Only if there is a lonely &, quote it back to an entity.
      return [string map { & %26 } [$n nodeValue]]
    } else {
      return ""
    }
  }
  
  RSS-client proc node_text {node xpath} {
    set n [$node selectNode $xpath]
    if {$n ne ""} {
      return [$n nodeValue]
    } else {
      return ""
    }
  }

  # this class is used to contain rss items
  Class create RSS-client::item -parameter node
  RSS-client::item instforward xpath {%my info parent} %proc

  # get the title
  RSS-client::item instproc title { } {
    return [::xowiki::RSS-client node_text [my node] [my xpath itemTitle]]
  }

  # get the link
  RSS-client::item instproc link {} {
    return [::xowiki::RSS-client node_uri [my node] [my xpath itemLink]]
  }

  # get the description
  RSS-client::item instproc description {} {
    return [::xowiki::RSS-client node_text [my node] [my xpath itemDesc]]
  }

  # return the publication date as string
  RSS-client::item instproc pubDate {} {
    return [::xowiki::RSS-client node_text [my node] [my xpath itemPubDate]]
  }


  # this class contains information on the channel
  Class create RSS-client::channel -parameter root
  RSS-client::channel instforward xpath {%my info parent} %proc

  # get the title
  RSS-client::channel instproc title { } {
    return [::xowiki::RSS-client node_text [my root] [my xpath title]]
  }

  # get the image link
  RSS-client::channel instproc imgLink {} {
    return [::xowiki::RSS-client node_uri [my root] [my xpath imgLink]]
  }

  # get the image title
  RSS-client::channel instproc imgTitle {} {
    return [::xowiki::RSS-client node_text [my root] [my xpath imgTitle]]
  }
  
  # get the image width
  RSS-client::channel instproc imgWidth {} {
    return [::xowiki::RSS-client node_text [my root] [my xpath imgWidth]]
  }
  # get the image height
  RSS-client::channel instproc imgHeight {} {
    return [::xowiki::RSS-client node_text [my root] [my xpath imgHeight]]
  }
  

}

::xo::library source_dependent 

