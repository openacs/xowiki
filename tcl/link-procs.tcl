ad_library {
    XoWiki - definition of link types and their renderers

    @creation-date 2006-04-15
    @author Gustaf Neumann
    @cvs-id $Id$
}
  
namespace eval ::xowiki {

  #
  # generic links
  #
  Class create ExternalLink -parameter {
    href label title target
  }
  ExternalLink instproc render {} {
    my instvar href label title target
    set title_att ""
    if {[info exists title]} {append  title_att " title='$title'"}
    if {[info exists target]} {append title_att " target='$target'"}
    return "<a $title_att class='external' href='$href'>$label</a>"
  }

  Class create Link -parameter {
    type name lang stripped_name label page 
    folder_id package_id 
    title target
    href
  }
  Link instproc atts {} {
    set atts ""
    if {[my exists title]} {append atts " title='[my title]'"}
    if {[my exists target]} {append atts " target='[my target]'"}
  }
  Link instproc init {} {
    set class [self class]::[my type]
    if {[my isclass $class]} {my class $class}
    #my log "--L link has class [my info class] // $class"
  }
  Link instproc resolve {} {
    #my log "--lookup of [my name] -page [my page]"
    if {![regexp {(.*?)(\#|%23)+(.*)$} [my name] full_name name anchor_tag anchor]} {
      set name [my name]
    }
    ::xo::db::CrClass lookup -name $name -parent_id [my folder_id]
  }
  Link instproc render_found {href label} {
    return "<a [my atts] href='$href'>$label</a>"
  }
  Link instproc render_not_found {href label} {
    if {$href eq ""} {
      return \[$label\]
    } else {
      return "<a href='$href'> \[ </a>$label <a href='$href'> \] </a>"
    }
  }
  Link instproc render {} {
    my instvar package_id
    set page [my page]
    set item_id [my resolve]
    my log "--u resolve returns $item_id"
    if {$item_id} {
      $page lappend references [list $item_id [my type]]
      ::xowiki::Package require $package_id
	if {![regexp {(.*?)(\#|%23)+(.*)$} [my stripped_name] full_name name anchor_tag anchor]} {
	    set name [my stripped_name]
	    set anchor ""
	}
	set href [::$package_id pretty_link -lang [my lang] -anchor $anchor $name]

      my render_found $href [my label]
    } else {
      $page incr unresolved_references
      set object_type [[$page info class] set object_type]
      set name [my name]
      set title [my label]
      set new_link  [$package_id make_link $package_id edit-new object_type name title] 
      #set href [export_vars -base [$package_id package_url] \
      #              {{edit-new 1} object_type name title}]

      my render_not_found $new_link [my label]
    }
  }

  Link instproc lookup_xowiki_package_by_name {name start_package_id} {
    set ancestors [site_node::get_ancestors \
                       -node_id $start_package_id \
                       -element node_id]
    foreach a $ancestors {
      set package_id [site_node::get_children -node_id $a -package_key xowiki \
                          -filters [list name $name] -element package_id]
      if {$package_id ne ""} {
        #my log "--LINK found package_id=$package_id [my isobject ::$package_id]"
        ::xowiki::Package require $package_id
        return $package_id
      }
    }
    return 0
  }


  #
  # language links
  #

  Class create ::xowiki::Link::language -superclass ::xowiki::Link -parameter {
    return_only
  }
  ::xowiki::Link::language instproc render {} {
    set page [my page]
    my instvar lang name package_id
    set item_id [my resolve]
    if {$item_id} {
      set css_class "found"
      set link [$package_id pretty_link -lang $lang [my stripped_name]]
    } else {
      set css_class "undefined"
      set last_page_id [$page set item_id]
      set object_type  [[$page info class] set object_type]
      set link [$package_id make_link $package_id \
                    edit-new object_type name last_page_id]
    }
    # my log "--lang_link=$link"
    if {[my exists return_only] && [my return_only] ne $css_class} {
      set link ""
    }
    if {$link ne ""} {
      $page lappend lang_links($css_class) \
          "<a href='$link'><img class='$css_class' \
                src='/resources/xowiki/flags/$lang.png' alt='$lang'></a>"
    }
    return ""
  }

  #
  # image links
  #
 
  Class create ::xowiki::Link::image -superclass ::xowiki::Link \
      -parameter {
        href cssclass
        center float width height 
        padding padding-right padding-left padding-top padding-bottom
        margin margin-left margin-right margin-top margin-bottom
        border border-width position top botton left right
      }
  ::xowiki::Link::image instproc render {} {
    my instvar name package_id label
    set page [my page]
    set item_id [my resolve]
    #my log "-- image resolve for $page returned $item_id (name=$name, label=$label) "
    if {$item_id} {
      set link [[my package_id] pretty_link -download true \
                    -absolute [$page absolute_links] $name]
      #my log "--l fully quali [$page absolute_links], base=$base"
      #set link [export_vars -base $base {{m download}} ]
      $page lappend references [list $item_id [my type]]
      my render_found $link $label
    } else {
      $page incr unresolved_references
      set last_page_id [$page set item_id]
      set title $label
      set object_type ::xowiki::File
      set return_url [$package_id url]
      set link [$package_id make_link $package_id edit-new object_type \
		    return_url autoname name title] 
      my render_not_found $link $label
    }
  }
  ::xowiki::Link::image instproc render_found {link label} {
    set style ""; set pre ""; set post ""
    foreach a {
      float width height center
      padding padding-right padding-left padding-top padding-bottom
      margin margin-left margin-right margin-top margin-bottom
      border border-width position top botton left right
    } {
      if {[my exists $a]} {
        if {$a eq "center"} {set pre "<center>"; set post "</center>"; continue}
        append style "$a: [my set $a];"
      }
    }
    if {$style ne ""} {set style "style='$style'"}
    set label [string map [list ' "&#39;"] $label]
    set cls [expr {[my exists cssclass] ? [my cssclass] : "xowikiimage"}]
    if {[my exists href]} {
      set href [my set href]
      if {[string match "java*" $href]} {set href .}
      return "<a href='$href'><img class='$cls' src='$link' alt='$label' title='$label' $style></a>"
    } else {
      
      return "$pre<img class='$cls' src='$link' alt='$label' title='$label' $style>$post"
    }
  }

  Class create ::xowiki::Link::localimage -superclass ::xowiki::Link::image
  ::xowiki::Link::localimage instproc render {} {
    my render_found [my href] [my label]
  }

  Class create ::xowiki::Link::file -superclass ::xowiki::Link::image  -parameter {
    width height align pluginspage pluginurl hidden href target
    autostart loop volume controls controller mastersound starttime endtime
  }
  ::xowiki::Link::file instproc resolve {} {
    set item_id [next]
    # my log "-- file, lookup of [my name] returned $item_id"
    if {$item_id == 0 && [regsub {^file:} [my name] image: name]} {
      set item_id [::xo::db::CrClass lookup -name $name -parent_id [my folder_id]]
    }
    return $item_id
  }
  ::xowiki::Link::file instproc render_found {internal_href label} {
    foreach f {
      width height align pluginspage pluginurl hidden href target
      autostart loop volume controls controller mastersound starttime endtime
    } {
      if {[my exists $f]} {
	append embed_options "$f = '[my set $f]' "
      }
    }
    if {![info exists embed_options]} {
      return "<a href='$internal_href' style='background: url(/resources/xowiki/file.jpg) \
        right center no-repeat; padding-right:9px'>$label</a>"
    } else {
      set internal_href [string map [list %2e .] $internal_href]
      return "<embed src='$internal_href' name=\"[my name]\" $embed_options></embed>"
    }
  }

  Class create ::xowiki::Link::css -superclass ::xowiki::Link::file -parameter {
  }
  ::xowiki::Link::css instproc render_found {href label} {
    ::xo::Page requireCSS $href
    return ""
  }
  Class create ::xowiki::Link::js -superclass ::xowiki::Link::file -parameter {
  }
  ::xowiki::Link::js instproc render_found {href label} {
    ::xo::Page requireJS $href
    return ""
  }

  Class create ::xowiki::Link::swf -superclass ::xowiki::Link::file -parameter {
    width height bgcolor version
    quality wmode align salign play loop menu scale
  }
  ::xowiki::Link::swf instproc resolve {} {
    set item_id [next]
    my log "--file, lookup of [my name] returned $item_id"
    if {$item_id == 0 && [regsub {^swf:} [my name] file: name]} {
      set item_id [::xo::db::CrClass lookup -name $name -parent_id [my folder_id]]
      my log "--file, 2nd lookup of $name returned $item_id"
    }
    return $item_id
  }
  ::xowiki::Link::swf instproc render_found {href label} {
    ::xo::Page requireJS /resources/xowiki/swfobject.js
    my instvar package_id name
    #set link [$package_id pretty_link -absolute true  -siteurl http://localhost:8003 $name]/download.swf
    foreach {width height bgcolor version} {320 240 #999999 7} break
    foreach a {width height bgcolor version} {if {[my exists $a]} {set $a [my set $a]}}
    set id [::xowiki::Includelet self_id]
    set addParams ""
    foreach a {quality wmode align salign play loop menu scale} {
      if {[my exists $a]} {append addParams "so.addParam('$a', '[my set $a]');\n"}
    }
    
    return "<div id='$id'>$label</div>
    <script type='text/javascript'>
    var so = new SWFObject('$href', '$name', '$width', '$height', '$version', '$bgcolor');
    $addParams so.write('$id');
    </script>
    "
  }


  #
  # glossary links
  #

  Class create ::xowiki::Link::glossary -superclass ::xowiki::Link
  ::xowiki::Link::glossary instproc resolve {} {
    # look for a package instance of xowiki, named "glossary" (the type)
    set id [my lookup_xowiki_package_by_name [my type] \
                [site_node::get_node_id_from_object_id -object_id [my package_id]]]
    #my log "--LINK glossary lookup returned package_id $id"
    if {$id} {
      # set correct package id for rendering the link
      my set package_id $id
      #my log "-- INITIALIZE $id"
      #::xowiki::Package initialize -package_id $id
      my log "--u setting package_id to $id"
      # lookup the item from the found folder
      return [::xo::db::CrClass lookup -name [my name] -parent_id [$id set folder_id]]
    }
    #my log "--LINK no page found [my name], [my lang], type=[my type]."
    return 0
  }
  ::xowiki::Link::glossary instproc render_found {href label} {
    ::xo::Page requireJS  "/resources/xowiki/get-http-object.js"
    ::xo::Page requireJS  "/resources/xowiki/popup-handler.js"
    ::xo::Page requireJS  "/resources/xowiki/overlib/overlib.js"
    return "<a href='$href' onclick=\"showInfo('$href?master=0','$label'); return false;\"\
        style='background: url(/resources/xowiki/glossary.gif) right center no-repeat; padding-right:14px'
        >$label</a>"
  }

  #
  # link cache
  #

  Class LinkCache
  LinkCache instproc resolve {} {
    set key link-[my type]-[my name]-[my folder_id]
    while {1} {
      array set r [ns_cache eval xowiki_cache $key {
        set id [next]
        if {$id == 0 || $id eq ""} break ;# don't cache
        return [list item_id $id package_id [my package_id]]
      }]
      break
    }
    if {![info exists r(item_id)]} {return 0}
    # we have a valid item. Set the the package_id and return the item_id
    my package_id $r(package_id)
    return $r(item_id)
  }

  Link instmixin add LinkCache
}
