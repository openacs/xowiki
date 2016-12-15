::xo::library doc {
  XoWiki - definition of link types and their renderers

  @creation-date 2006-04-15
  @author Gustaf Neumann
  @cvs-id $Id$
}

namespace eval ::xowiki {
  #
  # generic link methods
  #
  Class create BaseLink -parameter {
    cssclass cssid href label title target extra_query_parameter 
    {anchor ""} {query ""}
  }

  BaseLink instproc built_in_target {} {
    # currently, we do not support named frames, which are mostly deprecated
    return [expr {[my target] in {_blank _self _parent _top}}]
  }
  
  BaseLink instproc anchor_atts {} {
    set atts {}
    if {[my exists title]}  {lappend atts "title='[string map [list ' {&#39;}] [my title]]'"}
    if {[my exists target] && [my built_in_target]} {
      lappend atts "target='[my target]'"
    }
    return [join $atts " "]
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
    my instvar href label
    set css_atts [my mk_css_class_and_id -additional external]
    return "<a [my anchor_atts] href='[ns_quotehtml $href]'>$label<span class='external'>&nbsp;</span></a>"
  }

  #
  # internal links
  #
  Class create Link -superclass BaseLink -parameter {
    {type link} name lang stripped_name page 
    parent_id package_id item_id {form ""} revision_id
    is_self_link
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

  Link instproc render_target {href label} {
    #ns_log notice render_target
    set target [my target]
    if {[info commands ::xowiki::template::$target] ne ""} {
      #
      # The target template exists. use the template
      #
      # This is a situation, where potentially a
      # recursive inclusion is happening. The included content is
      # added to the html output only once, with a unique id, which
      # can be referenced multiple times. The link is included for
      # each occurance.
      #
      set item_id [my item_id]
      set targetId [xowiki::Includelet html_id [my item_id]-$target]
      set page [::xo::db::CrClass get_instance_from_db -item_id $item_id -revision_id 0]
      set content "Loading ..."
      set withBody true
      
      if {[::xowiki::template::$target render_content]} {
        set key ::__xowiki_link_rendered($targetId)
        if {![info exists $key]} {
          set $key 1
          set content [$page render_content]
        } else {
          #ns_log notice "modal with is already included: $key"
          set page ::$item_id
          set withBody false
        }
      }
      set result [::xowiki::template::$target render \
                      -with_body $withBody \
                      -title [$page title] \
                      -id $targetId \
                      -content $content \
                      -label $label \
                      -href $href]
      
      return $result
    } else {
      ns_log notice "xowiki::link: unknown target $target"
      return "<a [my anchor_atts] [my mk_css_class_and_id] href='[ns_quotehtml $href]'>$label</a>"
    }
  }
  
  Link instproc render_found {href label} {
    if {$href eq ""} {
      return "<span class='refused-link'>$label</span>"
    } elseif {[my exists target] && ![my built_in_target]} {
      return [my render_target $href $label]
    } else {
      return "<a [my anchor_atts] [my mk_css_class_and_id] href='[ns_quotehtml $href]'>$label</a>"
    }
  }
  Link instproc render_not_found {href label} {
    if {$href eq ""} {
      return \[$label\]
    } else {
      return "<a [my mk_css_class_and_id -additional missing] href='[ns_quotehtml $href]'> $label</a>"
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
    return [$page new_link \
                {*}[expr {[info exists object_type] ? [list -object_type $object_type] : {}}] \
                -name [my name] -title [my label] -parent_id [my parent_id] \
                -nls_language $nls_language $package_id]
  }

  Link instproc render {} {
    my instvar package_id
    set page [my page]
    set item_id [my resolve]
    if {$item_id} {
      $page references resolved [list $item_id [my type]]
      ::xowiki::Package require $package_id
      if {![my exists href]} {
        my set href [my pretty_link $item_id]
      }
      my render_found [my set href] [my label]
    } else {
      set new_link [my new_link]
      set html [my render_not_found $new_link [my label]]
      $page references unresolved $html
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
  # Link template
  #
  ::xotcl::Class create ::xowiki::LinkTemplate -parameter {link_template body_template {render_content true}}
  ::xowiki::LinkTemplate instproc render {
    {-with_link:boolean true}
    {-with_body:boolean true}
    {-title "TITLE"}
    {-id "ID"}
    {-content ""}
    {-label "LABEL"}
    {-href ""}
  } {
    set result ""    
    # this can be used into templates as id to safely attach event
    # handlers to elements
    set :timed_id [clock microseconds]    
    if {$with_link} {append result [subst [my link_template]]}
    if {$with_body} {append result [subst [my body_template]]}
    return $result
  }

  #
  # Small bootstrap modal
  #
  ::xowiki::LinkTemplate create ::xowiki::template::modal-sm -link_template {
    <a href="#[ns_quotehtml $id]" role="button" data-toggle="modal">$label</a>
  } -body_template {
<div class="modal fade" id="$id" tabindex="-1" role="dialog" aria-hidden="true">
  <div class="modal-dialog modal-sm">
    <div class="modal-content">
      <div class="modal-header">
        <button type="button" class="close" data-dismiss="modal"><span aria-hidden="true">&times;</span><span class="sr-only">#acs-kernel.common_Close#</span></button>
        <h4 class="modal-title">$title</h4>
      </div>
      <div class="modal-body">
        $content
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-default" data-dismiss="modal">#acs-kernel.common_Close#</button>
      </div>
    </div><!-- /.modal-content -->
  </div><!-- /.modal-dialog -->
</div><!-- /.modal -->
  }

  #
  # Large bootstrap modal
  #
  ::xowiki::LinkTemplate create ::xowiki::template::modal-lg -link_template {
    <a href="#[ns_quotehtml $id]" role="button" data-toggle="modal">$label</a>
  } -body_template {
    <div class="modal fade" id="[ns_quotehtml $id]" tabindex="-1" role="dialog" aria-hidden="true">
  <div class="modal-dialog modal-lg">
    <div class="modal-content">
      <div class="modal-header">
        <button type="button" class="close" data-dismiss="modal"><span aria-hidden="true">&times;</span><span class="sr-only">#acs-kernel.common_Close#</span></button>
        <h4 class="modal-title">$title</h4>
      </div>
      <div class="modal-body">
        $content
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-default" data-dismiss="modal">#acs-kernel.common_Close#</button>
      </div>
    </div><!-- /.modal-content -->
  </div><!-- /.modal-dialog -->
</div><!-- /.modal -->
  }

  #
  # Small bootstrap modal using ajax
  #
  ::xowiki::LinkTemplate create ::xowiki::template::modal-sm-ajax -render_content false -link_template {
    <a href="[ns_quotehtml $href]?template_file=view-modal-content" id='[ns_quotehtml $id]-button' role="button" data-target='#$id' data-toggle="modal">$label</a>
  } -body_template {
<div class="modal fade" id="$id" tabindex="-1" role="dialog" aria-hidden="true">
    <div class="modal-dialog modal-sm">
    <div class="modal-content">
       This will be replaced
    </div>
  </div><!-- /.modal-dialog -->
</div><!-- /.modal -->
<script type='text/javascript' nonce='$::__csp_nonce'>
\$('.modal').on('show.bs.modal', function(event) {
    var idx = \$('.modal:visible').length;
    \$(this).css('z-index', 1040 + (10 * idx));
});
\$('.modal').on('shown.bs.modal', function(event) {
    var idx = (\$('.modal:visible').length) -1; // raise backdrop after animation.
    \$('.modal-backdrop').not('.stacked').css('z-index', 1039 + (10 * idx));
    \$('.modal-backdrop').not('.stacked').addClass('stacked');
});
</script>     
  }

  #
  # Large bootstrap modal using ajax
  #
  ::xowiki::LinkTemplate create ::xowiki::template::modal-lg-ajax -render_content false -link_template {
<a href="[ns_quotehtml $href]?template_file=view-modal-content" id='$id-button' role="button" data-target='#$id' data-toggle="modal">$label</a>
  } -body_template {
<div class="modal fade" id="$id" tabindex="-1" role="dialog" aria-hidden="true">
    <div class="modal-dialog modal-lg">
    <div class="modal-content">
       This will be replaced
    </div>
  </div><!-- /.modal-dialog -->
</div><!-- /.modal -->
<script type='text/javascript' nonce='$::__csp_nonce'>
\$('.modal').on('show.bs.modal', function(event) {
    var idx = \$('.modal:visible').length;
    \$(this).css('z-index', 1040 + (10 * idx));
});
\$('.modal').on('shown.bs.modal', function(event) {
    var idx = (\$('.modal:visible').length) -1; // raise backdrop after animation.
    \$('.modal-backdrop').not('.stacked').css('z-index', 1039 + (10 * idx));
    \$('.modal-backdrop').not('.stacked').addClass('stacked');
});
</script>     
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
          "<a href='[ns_quotehtml $link]' [my mk_css_class_and_id]><img class='[ns_quotehtml $image_css_class]' \
                src='/resources/xowiki/flags/$lang.png' alt='$lang'></a>"
    }
    return ""
  }

  #
  # image links
  #
  
  Class create ::xowiki::Link::image -superclass ::xowiki::Link \
      -parameter {
        center float width height 
        padding padding-right padding-left padding-top padding-bottom
        margin margin-left margin-right margin-top margin-bottom
        border border-width position top botton left right
      }
  ::xowiki::Link::image instproc resolve_href {href} {
    set l [[my page] create_link $href]
    if {[$l istype ::xowiki::ExternalLink]} {
      set href [$l href]
    } else {
      set href_item_id [$l resolve]
      set href [$l pretty_link $href_item_id]
    }
    return $href
  }
  ::xowiki::Link::image instproc render {} {
    my instvar name package_id label
    set page [my page]
    set item_id [my resolve]
    #my log "-- image resolve for $page returned $item_id (name=$name, label=$label)"
    if {$item_id} {
      set link [$package_id pretty_link -download true -query [my query] \
                    -absolute [$page absolute_links] -parent_id [my parent_id] $name]
      #my log "--l fully quali [$page absolute_links], link=$link"
      $page references resolved [list $item_id [my type]]
      my render_found $link $label
    } else {
      set last_page_id [$page set item_id]
      set object_type ::xowiki::File
      set link [$package_id make_link $package_id edit-new object_type \
                    [list parent_id [my parent_id]] \
                    [list title [ad_html_to_text -no_format $label]] \
                    [list return_url [::xo::cc url]] \
                    autoname name last_page_id] 
      set html [my render_not_found $link $label]
      $page references unresolved $html
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
    if {[my exists href]} {set href [my set href]} {set href ""}
    set cls [my mk_css_class_and_id -default [expr {$link ne "" ? "image" : "refused-link"}]]
    if {$href ne ""} {
      set href [my resolve_href $href]
      if {[string match "java*" $href]} {set href .}
      if {[my exists revision_id]} {append href ?revision_id=[my revision_id]}
      return "$pre<a $cls href='[ns_quotehtml $href]'><img $cls src='[ns_quotehtml $link]' alt='[ns_quotehtml $label]' title='[ns_quotehtml $label]' $style></a>$post"
    } else {
      if {[my exists revision_id]} {append link ?revision_id=[my revision_id]}
      return "$pre<img $cls src='[ns_quotehtml $link]' alt='[ns_quotehtml $label]' title='[ns_quotehtml $label]' $style>$post"
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
      set pairs {}
      foreach {pair} [my extra_query_parameter] {
        lappend pairs [lindex $pair 0]=[ns_urlencode [lindex $pair 1]]
      }
      append internal_href ?[string map [list ' "&apos;"] [join $pairs &]]
      if {[my exists revision_id]} {append internal_href &revision_id=[my revision_id]}
    } else {
      if {[my exists revision_id]} {append internal_href ?revision_id=[my revision_id]}
    }
    if {![info exists embed_options]} {
      return "<a href='[ns_quotehtml $internal_href]' [my mk_css_class_and_id -additional file]>$label<span class='file'>&nbsp;</span></a>"
    } else {
      set internal_href [string map [list %2e .] $internal_href]
      return "<embed src='[ns_quotehtml $internal_href]' name=\"[my name]\" $embed_options></embed>"
    }
  }

  #
  # css link
  #

  Class create ::xowiki::Link::css -superclass ::xowiki::Link::file -parameter {
    order
  }
  ::xowiki::Link::css instproc render_found {href label} {
    if {[my exists order]} {
      ::xo::Page requireCSS -order [my order] $href
    } else {
      ::xo::Page requireCSS $href
    }
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
    lassign {320 240 7} width height version
    foreach a {width height version} {if {[my exists $a]} {set $a [my set $a]}}
    set id [::xowiki::Includelet html_id [my item_id]]
    set addParams ""
    foreach a {quality wmode align salign play loop menu scale} {
      if {[my exists $a]} {append addParams "so.addParam('$a', '[my set $a]');\n"}
    }
    
    return "<div id='[ns_quotehtml $id]'>$label</div>
    <script type='text/javascript' nonce='$::__csp_nonce'>
    var so = new SWFObject('[ns_quotehtml $href]', '[ns_quotehtml $name]', '[ns_quotehtml $width]', '[ns_quotehtml $height]', '[ns_quotehtml $version]');
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
    if {$id > 0} {
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
    if {![my exists cssid]} {my cssid [::xowiki::Includelet html_id [self]]}
    template::add_event_listener \
        -id [my cssid] \
        -script [subst {showInfo('[ns_quotehtml $href?master=0]','[ns_quotehtml $label]')}]
    return "<a href='[ns_quotehtml $href]' [my mk_css_class_and_id -additional glossary]>$label</a>"
  }

  #
  # link cache
  #

  #   Class create LinkCache
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

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
