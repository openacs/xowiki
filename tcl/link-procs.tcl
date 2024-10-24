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
    return [expr {${:target} in {_blank _self _parent _top}}]
  }

  BaseLink instproc anchor_atts {} {
    set atts {}
    if {[info exists :title]}  {lappend atts "title='[string map [list ' {&#39;}] ${:title}]'"}
    if {[info exists :target] && [:built_in_target]} {
      lappend atts "target='${:target}'"
    }
    return [join $atts " "]
  }

  BaseLink instproc mk_css_class {{-additional ""} {-default ""}} {
    set cls [expr {[info exists :cssclass] ? ${:cssclass} : $default}]
    if {$additional ne ""} {
      if {$cls eq ""} {set cls $additional} else {append cls " " $additional}
    }
    if {$cls ne ""} {set cls "class='$cls'"}
    return $cls
  }

  BaseLink instproc mk_css_class_and_id {{-additional ""} {-default ""}} {
    if {[info exists :cssid]} {set id "id='${:cssid}'"} else {set id ""}
    set cls [:mk_css_class -additional $additional -default $default]
    return [string trim "$cls $id"]
  }

  #
  # external links
  #
  Class create ExternalLink -superclass BaseLink
  ExternalLink instproc render {} {
    set css_atts [:mk_css_class_and_id -additional external]
    return "<a [:anchor_atts] href='[ns_quotehtml ${:href}]' class='external'>${:label}</a>"
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
    #:log "--L link '${:name}' has item_id <[expr {[info exists :item_id] ? ${:item_id} : {none}}]>"
    set class [self class]::${:type}
    if {[:isclass $class]} {:class $class}
    if {![info exists :name]} {
      set :name [string trimleft ${:lang}:${:stripped_name} :]
    } elseif {![info exists :stripped_name]} {
      # set stripped name and lang from provided name or to the default
      if {![regexp {^(..):(.*)$} ${:name} _ lang :stripped_name]} {
        set :stripped_name ${:name}
        set :lang ""
      }
    }
    if {![info exists :label]}      {set :label ${:name}}
    if {![info exists :parent_id]}  {set :parent_id [${:page} parent_id]}
    if {![info exists :package_id]} {set :package_id [${:page} package_id]}
    #:log "--L link '${:name}' has class [:info class] // $class // ${:type} // parent ${:parent_id} // page ${:page} // [info exists :item_id]"
  }
  Link instproc link_name {-lang -stripped_name} {
    return $lang:$stripped_name
  }
  Link instproc resolve {} {
    return ${:item_id}
  }

  Link instproc render_target {href label} {
    #ns_log notice render_target
    if {[info commands ::xowiki::template::${:target}] ne ""} {
      #
      # The target template exists. Use the template
      #
      # This is a situation, where potentially a
      # recursive inclusion is happening. The included content is
      # added to the html output only once, with a unique id, which
      # can be referenced multiple times. The link is included for
      # each occurrence.
      #
      set targetId [xowiki::Includelet html_id ${:item_id}-${:target}]
      set page [::xo::db::CrClass get_instance_from_db -item_id ${:item_id} -revision_id 0]
      set content "Loading ..."
      set withBody true

      if {[::xowiki::template::${:target} render_content]} {
        set key ::__xowiki_link_rendered($targetId)
        if {![info exists $key]} {
          set $key 1
          set content [$page render_content]
        } else {
          #ns_log notice "modal with is already included: $key"
          set page ::${:item_id}
          set withBody false
        }
      }
      set result [::xowiki::template::${:target} render \
                      -with_body $withBody \
                      -title [$page title] \
                      -id $targetId \
                      -content $content \
                      -label $label \
                      -href $href]

      return $result
    } else {
      ns_log notice "xowiki::link: unknown target ${:target}"
      return "<a [:anchor_atts] [:mk_css_class_and_id] href='[ns_quotehtml $href]'>$label</a>"
    }
  }

  Link instproc render_found {href label} {
    if {$href eq ""} {
      return "<span class='refused-link'>$label</span>"
    } elseif {[info exists :target] && ![:built_in_target]} {
      return [:render_target $href $label]
    } else {
      return "<a [:anchor_atts] [:mk_css_class_and_id] href='[ns_quotehtml $href]'>$label</a>"
    }
  }
  Link instproc render_not_found {href label} {
    if {$href eq ""} {
      return \[$label\]
    } else {
      return "<a [:mk_css_class_and_id -additional missing] href='[ns_quotehtml $href]'>$label</a>"
    }
  }
  Link instproc pretty_link {item_id} {
    if {$item_id == 0} {
      set pageArg ""
    } else {
      set obj ::$item_id
      if {![nsf::is object $obj]} {
         set obj [::xo::db::CrClass get_instance_from_db -item_id $item_id]
       }
      set pageArg [list -page $obj]
    }
    return [::${:package_id} pretty_link \
                -parent_id ${:parent_id} \
                -lang ${:lang} \
                -anchor ${:anchor} \
                -query ${:query} \
                {*}$pageArg \
                ${:name}]
  }
  Link instproc new_link {} {
    set nls_language [${:page} get_nls_language_from_lang ${:lang}]
    if {${:form} ne ""} {
      return [::${:package_id} make_form_link \
                  -form ${:form} \
                  -parent_id ${:parent_id} \
                  -name ${:name} \
                  -nls_language $nls_language]
    }

    if {[${:page} exists __unresolved_object_type]} {
      #
      # get the desired object_type for unresolved entries
      #
      set object_type [${:page} set __unresolved_object_type]
    } else {
      set object_type [[${:page} info class] set object_type]
      if {$object_type ne "::xowiki::Page" && $object_type ne "::xowiki::PlainPage"} {
        #
        # TODO: this is a temporary solution. We should find a way to
        # pass similar to file or image entries the type of this
        # entry. Maybe we can get the type as well from a kind of
        # blackboard, where the type of the "edit" wiki-menu-entry is
        # stored as well.
        #
        set object_type ::xowiki::Page
      }
    }
    return [${:page} new_link \
                {*}[expr {[info exists object_type] ? [list -object_type $object_type] : {}}] \
                -name ${:name} -title ${:label} -parent_id ${:parent_id} \
                -nls_language $nls_language ${:package_id}]
  }

  Link instproc render {} {
    set item_id [:resolve]
    if {$item_id} {
      ${:page} references resolved [list $item_id ${:type}]
      ::xowiki::Package require ${:package_id}
      if {![info exists :href]} {
        set :href [:pretty_link $item_id]
      }
      :render_found ${:href} ${:label}
    } else {
      set new_link [:new_link]
      set html [:render_not_found $new_link ${:label}]
      ${:page} references unresolved \
          [list parent_id ${:parent_id} name ${:name} link_type ${:type} html $html]
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
        #:log "--LINK found package_id=$package_id [nsf::is object ::$package_id]"
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
    set timed_id [clock microseconds]
    if {$with_link} {append result [subst [:link_template]]}
    if {$with_body} {append result [subst [:body_template]]}
    return $result
  }

#   #
#   # Small bootstrap modal
#   #
#   ::xowiki::LinkTemplate create ::xowiki::template::modal-sm -link_template {
#     <a href="#[ns_quotehtml $id]" role="button" data-toggle="modal">$label</a>
#   } -body_template {
# <div class="modal fade" id="$id" tabindex="-1" role="dialog" aria-hidden="true">
#   <div class="modal-dialog modal-sm">
#     <div class="modal-content">
#       <div class="modal-header">
#         <button type="button" class="close" data-dismiss="modal"><span aria-hidden="true">&times;</span><span class="sr-only">#acs-kernel.common_Close#</span></button>
#         <h4 class="modal-title">$title</h4>
#       </div>
#       <div class="modal-body">
#         $content
#       </div>
#       <div class="modal-footer">
#         <button type="button" class="btn [::template::CSS class btn-default]" data-dismiss="modal">#acs-kernel.common_Close#</button>
#       </div>
#     </div><!-- /.modal-content -->
#   </div><!-- /.modal-dialog -->
# </div><!-- /.modal -->
#   }

#   #
#   # Large bootstrap modal
#   #
#   ::xowiki::LinkTemplate create ::xowiki::template::modal-lg -link_template {
#     <a href="#[ns_quotehtml $id]" role="button" data-toggle="modal">$label</a>
#   } -body_template {
#     <div class="modal fade" id="[ns_quotehtml $id]" tabindex="-1" role="dialog" aria-hidden="true">
#   <div class="modal-dialog modal-lg">
#     <div class="modal-content">
#       <div class="modal-header">
#         <button type="button" class="close" data-dismiss="modal"><span aria-hidden="true">&times;</span><span class="sr-only">#acs-kernel.common_Close#</span></button>
#         <h4 class="modal-title">$title</h4>
#       </div>
#       <div class="modal-body">
#         $content
#       </div>
#       <div class="modal-footer">
#         <button type="button" class="btn [::template::CSS class btn-default]" data-dismiss="modal">#acs-kernel.common_Close#</button>
#       </div>
#     </div><!-- /.modal-content -->
#   </div><!-- /.modal-dialog -->
# </div><!-- /.modal -->
#   }

#   #
#   # Small bootstrap modal using ajax
#   #
#   ::xowiki::LinkTemplate create ::xowiki::template::modal-sm-ajax -render_content false -link_template {
#     <a href="[ns_quotehtml $href]?template_file=view-modal-content" id='[ns_quotehtml $id]-button' role="button" data-target='#$id' data-toggle="modal">$label</a>
#   } -body_template {
# <div class="modal fade" id="$id" tabindex="-1" role="dialog" aria-hidden="true">
#     <div class="modal-dialog modal-sm">
#     <div class="modal-content">
#        This will be replaced
#     </div>
#   </div><!-- /.modal-dialog -->
# </div><!-- /.modal -->
#     <script type='text/javascript' nonce='[security::csp::nonce]'>
# \$('.modal').on('show.bs.modal', function(event) {
#     var idx = \$('.modal:visible').length;
#     \$(this).css('z-index', 1040 + (10 * idx));
# });
# \$('.modal').on('shown.bs.modal', function(event) {
#     var idx = (\$('.modal:visible').length) -1; // raise backdrop after animation.
#     \$('.modal-backdrop').not('.stacked').css('z-index', 1039 + (10 * idx));
#     \$('.modal-backdrop').not('.stacked').addClass('stacked');
# });
# </script>
#   }

#   #
#   # Large bootstrap modal using ajax
#   #
#   ::xowiki::LinkTemplate create ::xowiki::template::modal-lg-ajax -render_content false -link_template {
# <a href="[ns_quotehtml $href]?template_file=view-modal-content" id='$id-button' role="button" data-target='#$id' data-toggle="modal">$label</a>
#   } -body_template {
# <div class="modal fade" id="$id" tabindex="-1" role="dialog" aria-hidden="true">
#     <div class="modal-dialog modal-lg">
#     <div class="modal-content">
#        This will be replaced
#     </div>
#   </div><!-- /.modal-dialog -->
# </div><!-- /.modal -->
# <script type='text/javascript' nonce='[security::csp::nonce]'>
# \$('.modal').on('show.bs.modal', function(event) {
#     var idx = \$('.modal:visible').length;
#     \$(this).css('z-index', 1040 + (10 * idx));
# });
# \$('.modal').on('shown.bs.modal', function(event) {
#     var idx = (\$('.modal:visible').length) -1; // raise backdrop after animation.
#     \$('.modal-backdrop').not('.stacked').css('z-index', 1039 + (10 * idx));
#     \$('.modal-backdrop').not('.stacked').addClass('stacked');
# });
# </script>
# }

  #
  # folder links
  #
  Class create ::xowiki::Link::folder -superclass ::xowiki::Link
  ::xowiki::Link::folder instproc link_name {-lang -stripped_name} {
    return $stripped_name
  }
  ::xowiki::Link::folder instproc pretty_link {item_id} {
    set page [expr {$item_id == 0 ? "" : "-page ::$item_id"}]
    return [::${:package_id} pretty_link \
                -anchor ${:anchor} -parent_id ${:parent_id} -query ${:query} \
                {*}$page \
                ${:name} ]
  }

  #
  # language links
  #
  Class create ::xowiki::Link::language -superclass ::xowiki::Link -parameter {
    return_only
  }
  ::xowiki::Link::language instproc render {} {
    set item_id [:resolve]
    if {$item_id} {
      set image_css_class "found"
      set link [::${:package_id} pretty_link \
                    -lang ${:lang} -parent_id ${:parent_id} \
                    -page $item_id \
                    ${:stripped_name}]
    } else {
      set image_css_class "undefined"
      set last_page_id [${:page} set item_id]
      set object_type  [[${:page} info class] set object_type]
      set name ${:name}
      set link [::${:package_id} make_link ${:package_id} \
                    edit-new object_type name last_page_id]
    }
    # :log "--lang_link=$link"
    if {[info exists :return_only] && ${:return_only} ne $image_css_class} {
      set link ""
    }
    if {$link ne ""} {
      ${:page} lappend lang_links($image_css_class) \
          "<a href='[ns_quotehtml $link]' [:mk_css_class_and_id]><img class='[ns_quotehtml $image_css_class]' \
                src='/resources/xowiki/flags/${:lang}.png' alt='${:lang}'></a>"
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
        border border-width position top bottom left right
      }
  ::xowiki::Link::image instproc resolve_href {href} {
    set l [${:page} create_link $href]
    if {[$l istype ::xowiki::ExternalLink]} {
      set href [$l href]
    } else {
      set href_item_id [$l resolve]
      set href [$l pretty_link $href_item_id]
    }
    return $href
  }
  ::xowiki::Link::image instproc render {} {
    set item_id [:resolve]
    #:log "-- image resolve for ${:page} returned $item_id (name=${:name}, label=${:label})"
    if {$item_id != 0} {
      set link [::${:package_id} pretty_link \
                    -download true \
                    -query ${:query} \
                    -absolute [expr {[${:page} exists absolute_links] ? [${:page} absolute_links] : 0}] \
                    -parent_id ${:parent_id} \
                    -page $item_id \
                    ${:name}]
      #:log "--l fully quali [${:page} absolute_links], link=$link [info commands ::$item_id]"
      ${:page} references resolved [list $item_id ${:type}]
      :render_found $link ${:label}
    } else {
      set last_page_id [${:page} set item_id]
      set object_type ::xowiki::File
      set name ${:name}
      set link [::${:package_id} make_link ${:package_id} edit-new object_type \
                    [list parent_id ${:parent_id}] \
                    [list title [ad_html_to_text -no_format -- ${:label}]] \
                    [list return_url [::xo::cc url]] \
                    autoname name last_page_id]
      set html [:render_not_found $link ${:label}]
      ${:page} references unresolved \
          [list parent_id ${:parent_id} name ${:name} link_type ${:type} html $html]
      return $html
    }
  }
  ::xowiki::Link::image instproc render_found {link label} {
    set style ""; set pre ""; set post ""
    foreach a {
      float width height center
      padding padding-right padding-left padding-top padding-bottom
      margin margin-left margin-right margin-top margin-bottom
      border border-width position top bottom left right
    } {
      if {[info exists :$a]} {
        if {$a eq "center"} {set pre "<center>"; set post "</center>"; continue}
        append style "$a: [set :$a];"
      }
    }
    if {$style ne ""} {
      set style "style='$style'"
    }
    if {[info exists :geometry]} {
      append link "?geometry=${:geometry}"
    }
    #set label [string map [list ' "&#39;"] $label]
    set href [expr {[info exists :href] ? ${:href} : ""}]
    set cls [:mk_css_class_and_id -default [expr {$link ne "" ? "image" : "refused-link"}]]
    if {$href ne ""} {
      set href [:resolve_href $href]
      if {[string match "java*" $href]} {
        set href .
      }
      if {[info exists :revision_id]} {
        append href ?revision_id=${:revision_id}
      }
      return [subst {$pre<a $cls href='[ns_quotehtml $href]'><img $cls src='[ns_quotehtml $link]' alt='$label' title='$label' $style></a>$post}]
    } else {
      if {[info exists :revision_id]} {append link ?revision_id=${:revision_id}}
      return [subst {$pre<img $cls src='[ns_quotehtml $link]' alt='$label' title='$label' $style>$post}]
    }
  }


  #
  # localimage link
  #

  Class create ::xowiki::Link::localimage -superclass ::xowiki::Link::image
  ::xowiki::Link::localimage instproc render {} {
    :render_found ${:href} ${:label}
  }

  #
  #
  # file link
  #

  Class create ::xowiki::Link::file -superclass ::xowiki::Link::image -parameter {
    width height hidden
  }
  foreach deprecated_attribute {
    align name pluginspage pluginurl href autostart
    loop volume controls controller mastersound starttime endtime
  } {

    ::xowiki::Link::file ad_instproc -private -deprecated $deprecated_attribute {value:optional} {
      Provide warning for deprecated HTML attribute;
      this will be removed in releases after OpenACS 5.10.
    } {
      if {[info exists value]} {
        set :[self proc] $value
      }
      return [set :[self proc]]
    }

  }

  ::xowiki::Link::file instproc render_found {internal_href label} {
    #
    # Many of the attributes below are from HTML4 and deprecated (see
    # "deprecated_attribute" above). We just removed "href" from the list
    # of still accepted attributes, since this is set often via BaseLink,
    # and it could harm applications, where the "<EMBED href> variant of the
    # stopped working due to newer browsers, stopping to support legacy
    # HTML attributes.
    #
    foreach f {
      width height align pluginspage pluginurl hidden href
      autostart loop volume controls controller mastersound starttime endtime
    } {
      if {[info exists :$f]} {
        append embed_options "$f = '[set :$f]' "
      }
    }
    if {[info exists :extra_query_parameter]} {
      set pairs {}
      foreach {pair} ${:extra_query_parameter} {
        lappend pairs [lindex $pair 0]=[ns_urlencode [lindex $pair 1]]
      }
      append internal_href ?[string map [list ' "&apos;"] [join $pairs &]]
      if {[info exists :revision_id]} {append internal_href &revision_id=${:revision_id}}
    } else {
      if {[info exists :revision_id]} {append internal_href ?revision_id=${:revision_id}}
    }
    if {![info exists embed_options]} {
      return "<a href='[ns_quotehtml $internal_href]' [:mk_css_class_and_id -additional file]>$label</a>"
    } else {
      set internal_href [string map [list %2e .] $internal_href]
      return "<embed src='[ns_quotehtml $internal_href]' name=\"${:name}\" $embed_options></embed>"
    }
  }

  #
  # css link
  #

  Class create ::xowiki::Link::css -superclass ::xowiki::Link::file -parameter {
    order
  }
  ::xowiki::Link::css instproc render_found {href label} {
    if {[info exists :order]} {
      ::xo::Page requireCSS -order ${:order} $href
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
    #set link [::${:package_id} pretty_link -absolute true  -siteurl http://localhost:8003 ${:name}]/download.swf
    lassign {320 240 7} width height version
    foreach a {width height version} {if {[info exists :$a]} {set $a [set :$a]}}
    set id [::xowiki::Includelet html_id ${:item_id}]
    set addParams ""
    foreach a {quality wmode align salign play loop menu scale} {
      if {[info exists :$a]} {append addParams "so.addParam('$a', '[set :$a]');\n"}
    }

    return [ns_trim [subst {<div id='[ns_quotehtml $id]'>$label</div>
      <script type='text/javascript' nonce='[security::csp::nonce]'>
      var so = new SWFObject('[ns_quotehtml $href]', '[ns_quotehtml ${:name}]',
                             '[ns_quotehtml $width]', '[ns_quotehtml $height]', '[ns_quotehtml $version]');
      $addParams so.write('$id');
      </script>
    }]]
  }

  #
  # glossary links
  #

  Class create ::xowiki::Link::glossary -superclass ::xowiki::Link
  ::xowiki::Link::glossary instproc resolve {} {
    # look for a package instance of xowiki, named "glossary" (the type)
    set id [:lookup_xowiki_package_by_name ${:type} \
                [site_node::get_node_id_from_object_id -object_id ${:package_id}]]
    #:log "--LINK glossary lookup returned package_id $id"
    if {$id > 0} {
      # set correct package id for rendering the link
      set :package_id $id
      #:log "-- INITIALIZE $id"
      #::xowiki::Package initialize -package_id $id
      #:log "--u setting package_id to $id"
      # lookup the item from the found folder
      return [::xo::db::CrClass lookup -name ${:name} -parent_id [$id set parent_id]]
    }
    #:log "--LINK no page found ${:name}, ${:lang}, type=${:type}."
    return 0
  }
  ::xowiki::Link::glossary instproc render_found {href label} {
    ::xo::Page requireJS urn:ad:js:get-http-object
    ::xo::Page requireJS  "/resources/xowiki/popup-handler.js"
    ::xo::Page requireJS  "/resources/xowiki/overlib/overlib.js"
    if {![info exists :cssid]} {:cssid [::xowiki::Includelet html_id [self]]}
    template::add_event_listener \
    -id ${:cssid} \
        -script [subst {showInfo('[ns_quotehtml $href?master=0]','$label')}]
    return "<a href='[ns_quotehtml $href]' [:mk_css_class_and_id -additional glossary]>$label</a>"
  }

  #
  # Link cache - deactivated.
  # When it will become activated again, it should get its own cache.
  #
  #   Class create LinkCache
  #   LinkCache proc flush {parent_id {item_id ""}} {
  #     if {$item_id eq ""} {
  #       :acs::clusterwide acs::cache_flush_pattern xowiki_cache link-*-$name-$parent_id
  #     } else {
  #       foreach entry [ns_cache names xowiki_cache link-*-$parent_id] {
  #         array set tmp [ns_cache get xowiki_cache $entry]
  #         if {$tmp(item_id) == $item_id} {
  #           ::acs::clusterwide ns_cache flush xowiki_cache $entry
  #         }
  #       }
  #     }
  #   }
  #   LinkCache instproc resolve {} {
  #     set key link-${:type}-${:name}-${:parent_id}
  #     while {1} {
  #       array set r [ns_cache eval xowiki_cache $key {
  #         set id [next]
  #         if {$id == 0 || $id eq ""} break ;# don't cache
  #         return [list item_id $id package_id ${:package_id}]
  #       }]
  #       break
  #     }
  #     if {![info exists r(item_id)]} {return 0}
  #     # we have a valid item. Set the package_id and return the item_id
  #     :package_id $r(package_id)
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
