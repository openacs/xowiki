::xo::library doc {
    XoWiki - definition of link types and their renderers

    @creation-date 2006-04-15
    @author Gustaf Neumann
    @cvs-id $Id$
}
  
namespace eval ::xowiki {
  #
  # generic links
  #
  Class create BaseLink -parameter {
    cssclass cssid href label title target extra_query_parameter 
    {anchor ""} {query ""}
  }

  BaseLink instproc mk_css_class {{-additional ""} {-default ""}} {
    set cls [expr {[my exists cssclass] ? [my cssclass] : $default}]
    if {$additional ne ""} {
      if {$cls eq ""} {set cls $additional} else {append cls " " $additional}
    }
    if {$cls ne ""} {set cls "class='$cls'"}
    return $cls 
  }

  BaseLink instproc mk_css_class_and_id {{-additional ""} {-default ""}} {
    if {[my exists cssid]} {set id "id='[my cssid]'"} else {set id ""}
    set cls [my mk_css_class -additional $additional -default $default]
    return [string trim "$cls $id"]
  }

  #
  # external links
  #
  Class create ExternalLink -superclass BaseLink 
  ExternalLink instproc render {} {
    my instvar href label title target
    set title_att ""
    if {[info exists title]}  {append  title_att " title='[string map [list ' {&#39;}] $title]'"}
    if {[info exists target]} {append title_att " target='$target'"}
    set css_atts [my mk_css_class_and_id -additional external]
    return "<a $title_att $css_atts href='$href'>$label<span class='external'>&nbsp;</span></a>"
  }

  #
  # internal links
  #
  Class create Link -superclass BaseLink -parameter {
    {type link} name lang stripped_name page 
    parent_id package_id item_id {form ""}
  }
  Link instproc atts {} {
    set atts ""
    if {[my exists title]}  {append atts " title='[string map [list ' {&#39;}] [my title]]'"}
    if {[my exists target]} {append atts " target='[my target]'"}
  }
  Link instproc init {} {
    my instvar page name
    set class [self class]::[my type]
    if {[my isclass $class]} {my class $class}
    if {![my exists name]} {
      set name [string trimleft [my lang]:[my stripped_name] :]
    } elseif {![my exists stripped_name]} {
      # set stripped name and lang from provided name or to the default
      my instvar stripped_name lang
      if {![regexp {^(..):(.*)$} $name _ lang stripped_name]} {
        set stripped_name $name; set lang ""
      }
    }
    if {![my exists label]}      {my label $name}
    if {![my exists parent_id]}  {my parent_id [$page parent_id]}
    if {![my exists package_id]} {my package_id [$page package_id]}
    #my msg "--L link has class [my info class] // $class // [my type] // [my parent_id]"
  }
  Link instproc link_name {-lang -stripped_name} {
    return $lang:$stripped_name
  }
  Link instproc resolve {} {
    return [my item_id]
  }
  Link instproc render_found {href label} {
    return "<a [my atts] [my mk_css_class_and_id] href='$href'>$label</a>"
  }
  Link instproc render_not_found {href label} {
    if {$href eq ""} {
      return \[$label\]
    } else {
      return "<a [my mk_css_class_and_id -additional missing] href='$href'> $label</a>"
    }
  }
  Link instproc pretty_link {item_id} {
    my instvar package_id
    return [::$package_id pretty_link -parent_id [my parent_id] -lang [my lang] \
                -anchor [my anchor] -query [my query] [my name]]
  }
  Link instproc new_link {} {
    my instvar package_id form
    set page [my page]
    set nls_language [$page get_nls_language_from_lang [my lang]]
    if {$form ne ""} {
      return [$package_id make_form_link -form $form \
                  -parent_id [my parent_id] \
                  -name [my name] \
                  -nls_language $nls_language]
    }
    if {[$page exists __unresolved_object_type]} {
      # get the desired object_type for unresoved entries
      set object_type [$page set __unresolved_object_type]
    } else {
      set object_type [[$page info class] set object_type]
      if {$object_type ne "::xowiki::Page" && $object_type ne "::xowiki::PlainPage"} {
        # TODO: this is a temporary solution. we should find a way to
        # pass similar to file or image entries the type of this
        # entry. Maybe we can get the type as well from a kind of
        # blackboard, where the type of the "edit" wiki-menu-entry is
        # stored as well.
        set object_type ::xowiki::Page
      }
    }
    return [$page new_link -name [my name] -title [my label] -parent_id [my parent_id] \
                -nls_language $nls_language $package_id]
  }

  Link instproc render {} {
    my instvar package_id
    set page [my page]
    set item_id [my resolve]
    if {$item_id} {
      $page lappend references [list $item_id [my type]]
      ::xowiki::Package require $package_id
      my render_found [my pretty_link $item_id] [my label]
    } else {
      $page incr unresolved_references
      set new_link [my new_link]
      set html [my render_not_found $new_link [my label]]
      $page lappend __unresolved_references $html
      return $html
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
  # folder links
  #
  Class create ::xowiki::Link::folder -superclass ::xowiki::Link
  ::xowiki::Link::folder instproc link_name {-lang -stripped_name} {
    return $stripped_name
  }
  ::xowiki::Link::folder instproc pretty_link {item_id} {
    my instvar package_id
    return [::$package_id pretty_link \
                -anchor [my anchor] -parent_id [my parent_id] -query [my query] [my name] ]
  }
  ::xowiki::Link::folder instproc new_link {} {
    my instvar package_id
    return [$package_id make_link -with_entities 0 \
                $package_id \
                edit-new \
                [list object_type ::xo::db::CrFolder] \
                [list name [my name]] \
                [list parent_id [my parent_id]] \
                [list return_url [::xo::cc url]] \
                autoname]
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
      set image_css_class "found"
      set link [$package_id pretty_link -lang $lang -parent_id [my parent_id] [my stripped_name]]
    } else {
      set image_css_class "undefined"
      set last_page_id [$page set item_id]
      set object_type  [[$page info class] set object_type]
      set link [$package_id make_link $package_id \
                    edit-new object_type name last_page_id]
    }
    # my log "--lang_link=$link"
    if {[my exists return_only] && [my return_only] ne $image_css_class} {
      set link ""
    }
    if {$link ne ""} {
      $page lappend lang_links($image_css_class) \
          "<a href='$link' [my mk_css_class_and_id]><img class='$image_css_class' \
                src='/resources/xowiki/flags/$lang.png' alt='$lang'></a>"
    }
    return ""
  }

  #
  # image links
  #
 
  Class create ::xowiki::Link::image -superclass ::xowiki::Link \
      -parameter {
        href
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
      set link [$package_id pretty_link -download true -query [my query] \
                    -absolute [$page absolute_links] -parent_id [my parent_id] $name]
      #my log "--l fully quali [$page absolute_links], base=$base"
      $page lappend references [list $item_id [my type]]
      my render_found $link $label
    } else {
      $page incr unresolved_references
      set last_page_id [$page set item_id]
      set title $label
      set object_type ::xowiki::File
      set return_url [::xo::cc url]
      set link [$package_id make_link $package_id edit-new object_type \
		    return_url autoname name title] 
      set html [my render_not_found $link $label]
      return $html
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
    if {[my exists geometry]} {append link "?geometry=[my set geometry]"}
    set label [string map [list ' "&#39;"] $label]
    set cls [my mk_css_class_and_id -default image]
    if {[my exists href]} {
      set href [my set href]
      if {[string match "java*" $href]} {set href .}
      return "$pre<a $cls href='$href'><img $cls src='$link' alt='$label' title='$label' $style></a>$post"
    } else {
      return "$pre<img $cls src='$link' alt='$label' title='$label' $style>$post"
    }
  }


  #
  # localimage link
  #
 
  Class create ::xowiki::Link::localimage -superclass ::xowiki::Link::image
  ::xowiki::Link::localimage instproc render {} {
    my render_found [my href] [my label]
  }

  #
  # file link
  #

  Class create ::xowiki::Link::file -superclass ::xowiki::Link::image -parameter {
    width height align pluginspage pluginurl hidden href
    autostart loop volume controls controller mastersound starttime endtime
  }

  ::xowiki::Link::file instproc render_found {internal_href label} {
    foreach f {
      width height align pluginspage pluginurl hidden href
      autostart loop volume controls controller mastersound starttime endtime
    } {
      if {[my exists $f]} {
	append embed_options "$f = '[my set $f]' "
      }
    }
    if {[my exists extra_query_parameter]} {
      set internal_href [export_vars -base $internal_href [my extra_query_parameter]]
    }
    if {![info exists embed_options]} {
      return "<a href='$internal_href' [my mk_css_class_and_id -additional file]>$label<span class='file'>&nbsp;</span></a>"
    } else {
      set internal_href [string map [list %2e .] $internal_href]
      return "<embed src='$internal_href' name=\"[my name]\" $embed_options></embed>"
    }
  }

  #
  # css link
  #

  Class create ::xowiki::Link::css -superclass ::xowiki::Link::file -parameter {
  }
  ::xowiki::Link::css instproc render_found {href label} {
    ::xo::Page requireCSS $href
    return ""
  }

  #
  # js link
  #
  Class create ::xowiki::Link::js -superclass ::xowiki::Link::file -parameter {
  }
  ::xowiki::Link::js instproc render_found {href label} {
    ::xo::Page requireJS $href
    return ""
  }

  #
  # swf link
  #
  Class create ::xowiki::Link::swf -superclass ::xowiki::Link::file -parameter {
    width height bgcolor version
    quality wmode align salign play loop menu scale
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
  # plugin link
  #
#   Class create ::xowiki::Link::plugin -superclass ::xowiki::Link::file -parameter {
#       classid width height autostart params
#   }

#   ::xowiki::Link::plugin instproc render_found {href label} {
#     my instvar package_id name

#     foreach {width height autostart} {320 240 true} break
#     foreach a {classid width height autostart} {if {[my exists $a]} {set $a [my set $a]}}
#     set arguments [list width height autostart]
    
#     set object_params ""
#     if {[my exists params]} {
#       set paramlist [split [my set params] ,]
#       foreach p $paramlist {
#         set pair [split $p =]
#         set param([lindex $pair 0]) [lindex $pair 1]
#       }
#     }

#     #my msg [my name]-guess-type=[::xowiki::guesstype [my name]]
#     set mime [::xowiki::guesstype [my name]]

#     switch $mime {
#       video/x-ms-wmv {
#         # TODO: using classid will stop firefox loading plugin,
#         # without classid IE asks user to allow addon
#         # also possible: application/x-mplayer2
#         if {![my exists classid]} {set classid "CLSID:6BF52A52-394A-11d3-B153-00C04F79FAA6"}
#         foreach f $arguments {if {[info exists $f]} {append object_params "<PARAM NAME='$f' VALUE='[set $f]'/>"}}
#         set objectElement \
# 		"<OBJECT WIDTH='$width' HEIGHT='$height' TYPE='$mime' DATA='$href'>\n\
# 		<PARAM NAME='SRC' VALUE='$href'/>\n$object_params\n\
# 		</OBJECT>"
#       }
#       video/quicktime  {
#         if {![my exists classid]} {set classid "CLSID:02BF25D5-8C17-4B23-BC80-D3488ABDDC6B"}
#         foreach f $arguments {if {[info exists $f]} {append object_params "<PARAM NAME='$f' VALUE='[set $f]'/>"}}
#         set objectElement \
# 		"<OBJECT WIDTH='$width' HEIGHT='$height' \n\
# 		CLASSID='$classid' CODEBASE='http://www.apple.com/qtactivex/qtplugin.cab'> \n\
#             	<PARAM NAME='SRC' VALUE='$href'/> \n\
# 	        <OBJECT TYPE='$mime' DATA='$href' WIDTH='$width' HEIGHT='$height'> \n\
#             	$object_params \n\
#             	</OBJECT>\n</OBJECT>\n"
#       }
#       application/x-shockwave-flash {
#         if {![my exists classid]} {set classid "CLSID:D27CDB6E-AE6D-11cf-96B8-444553540000"}
#         set embed_options ""
#         set app_params "?"
#         foreach f $arguments {if {[info exists $f]} { append embed_options "$f = '[set $f]' " }}
#         foreach {att value} [array get param] {append app_params "$att=$value&"} ;# replace with export_vars
#         set objectElement \
# 		"<OBJECT WIDTH='$width' HEIGHT='$height' \n\
#         	CLASSID='$classid' TYPE='$mime' \n\
#             	CODEBASE='http://download.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version=6,0,0,0'> \n\
#             	<PARAM NAME='movie' VALUE='$href$app_params'/>\n\
#                 <EMBED SRC='$href$app_params' NAME='[my stripped_name]' TYPE='$mime'\n\
#             	PLUGINSPACE='http://www.macromedia.com/go/getflashplayer' $embed_options />\n\
#             	</OBJECT>\n"
#       }
#       application/java {
#         if {![my exists classid]} {set classid "clsid:CAFEEFAC-0015-0000-0000-ABCDEFFEDCBA"}
#         if {![info exists param(code)]} {set param(code) [my stripped_name]}
#         if {![info exists codebase]} {set codebase [$package_id pretty_link -lang [my lang] -download true ""]}

#         foreach {att value} [array get param] {append object_params "<PARAM NAME='$att' VALUE='$value'/>\n"}
#         set objectElement \
# 		"<OBJECT WIDTH='$width' HEIGHT='$height' \n\
#         	CLASSID='$classid' CODETYPE='application/x-java-applet;jpi-version=1.6.0_03'>\n\
#             	<APPLET WIDTH='$width' HEIGHT='$height' NAME='[my stripped_name]' CODEBASE='$codebase' TYPE='$mime'>\n\
#             	$object_params \n\
#             	<NOEMBED>No Java Support.</NOEMBED> \n\
#             	</APPLET>\n\
#             	$object_params \n\
#             	</OBJECT>\n"
#       }
#       default {
#         my msg "unknown mime type '$mime' for plugin"
#         #set mime "application/x-oleobject"
#       }
#     }

#     return "$objectElement
#               <DIV ID='[my name]'>$label ([my name])</DIV>  <!-- TODO REMOVE ME -->
#              "
#   }



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
      #my log "--u setting package_id to $id"
      # lookup the item from the found folder
      return [::xo::db::CrClass lookup -name [my name] -parent_id [$id set parent_id]]
    }
    #my log "--LINK no page found [my name], [my lang], type=[my type]."
    return 0
  }
  ::xowiki::Link::glossary instproc render_found {href label} {
    ::xo::Page requireJS  "/resources/xowiki/get-http-object.js"
    ::xo::Page requireJS  "/resources/xowiki/popup-handler.js"
    ::xo::Page requireJS  "/resources/xowiki/overlib/overlib.js"
    return "<a href='$href' onclick=\"showInfo('$href?master=0','$label'); return false;\"\
        [my mk_css_class_and_id -additional glossary]>$label</a>"
  }

  #
  # link cache
  #

#   Class LinkCache
#   LinkCache instproc resolve {} {
#     set key link-[my type]-[my name]-[my parent_id]
#     while {1} {
#       array set r [ns_cache eval xowiki_cache $key {
#         set id [next]
#         if {$id == 0 || $id eq ""} break ;# don't cache
#         return [list item_id $id package_id [my package_id]]
#       }]
#       break
#     }
#     if {![info exists r(item_id)]} {return 0}
#     # we have a valid item. Set the the package_id and return the item_id
#     my package_id $r(package_id)
#     return $r(item_id)
#   }

#   Link instmixin add LinkCache
}
::xo::library source_dependent 

