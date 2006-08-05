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

  Class create Link -parameter {
    type name lang stripped_name label 
    folder_id package_id
  }
  Link instproc init {} {
    set class [self class]::[my type]
    if {[my isclass $class]} {my class $class}
    my log "--L link has class [my info class]"
  }
  Link instproc resolve {} {
    #my log "--lookup of [my name]"
    ::Generic::CrItem lookup -name [my name] -parent_id [my folder_id]
  }
  Link instproc render_found {href label} {
    return "<a href='$href'>$label</a>"
  }
  Link instproc render_not_found {href label} {
    return "<a href='$href'> \[ </a>$label <a href='$href'> \] </a>"
  }
  Link instproc render {} {
    set page [my info parent]
    set item_id [my resolve]
    #my log "--u resolve returns $item_id"
    if {$item_id} {
      $page lappend references [list $item_id [my type]]
      set href [::xowiki::Page pretty_link \
		    -package_id [my package_id] -lang [my lang] \
		    [my stripped_name]]
      my render_found $href [my label]
    } else {
      my instvar package_id
      $page incr unresolved_references
      set object_type [[$page info class] set object_type]
      set name [my name]
      set title [my label]
      set href [export_vars -base [$package_id package_url] \
		    {{edit-new 1} object_type name title}]
      my render_not_found $href [my label]
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
	my log "--LINK found package_id=$package_id [my isobject ::$package_id]"
	if {![my isobject ::$package_id]} {
	  my log "--LINK creating package object"
	  ::xowiki::Package create ::$package_id
	}
	return $package_id
      }
    }
    return 0
  }


  #
  # language links
  #

  Class create ::xowiki::Link::language -superclass ::xowiki::Link
  ::xowiki::Link::language instproc render {} {
    set page [my info parent]
    my instvar lang name package_id
    set item_id [my resolve]
    if {$item_id} {
      set css_class "found"
      set link [::xowiki::Page pretty_link -lang $lang [my stripped_name]]
    } else {
      set css_class "undefined"
      set last_page_id [$page set item_id]
      set object_type  [[$page info class] set object_type]
      set link [export_vars -base [$package_id package_url] \
		    {{edit-new 1} object_type name last_page_id}]
    }
    $page lappend lang_links \
	"<a href='$link'><img class='$css_class' style='height='12' \
		src='/resources/xowiki/flags/$lang.png' alt='$lang'></a>"
    return ""
  }

  #
  # image links
  #
 
  Class create ::xowiki::Link::image -superclass ::xowiki::Link
  ::xowiki::Link::image instproc render {} {
    my instvar name package_id label
    set page [my info parent]
    set item_id [my resolve]
    if {$item_id} {
      set link [export_vars -base [::xowiki::Page pretty_link $name] {{m download}} ]
      $page lappend references [list $item_id [my type]]
      my render_found $link $label
    } else {
      $page incr unresolved_references
      set last_page_id [$page set item_id]
      set title $label
      set link [export_vars -base [$package_id package_url] \
		    {{edit-new 1} {object_type ::xowiki::File} 
		      {return_url "[$package_id url]"}
		      name title last_page_id}]
      my render_not_found $link $label
    }
  }
  ::xowiki::Link::image instproc render_found {link label} {
    set label [string map [list ' "&#39;"] $label]
    return "<img src='$link' alt='$label' title='$label'>"
  }

  Class create ::xowiki::Link::file -superclass ::xowiki::Link::image
  ::xowiki::Link::file instproc render_found {href label} {
    return "<a href='$href' style='background: url(/resources/xowiki/file.jpg) \
	right center no-repeat; padding-right:9px'>$label</a>"
  }

  #
  # glossary links
  #

  Class create ::xowiki::Link::glossary -superclass ::xowiki::Link
  ::xowiki::Link::glossary instproc resolve {} {
    # look for a package instance of xowiki, named "glossary" (the type)
    set id [my lookup_xowiki_package_by_name [my type] \
		[site_node::get_node_id_from_object_id -object_id [my package_id]]]
    my log "--LINK glossary lookup returned package_id $id"
    if {$id} {
      # set correct package id for rendering the link
      my set package_id $id
      my log "--u setting package_id to $id"
      # lookup the item from the found folder
      return [::Generic::CrItem lookup -name [my name] -parent_id [$id set folder_id]]
    }
    my log "--LINK no page found [my name], [my lang], type=[my type]."
    return 0
  }
  ::xowiki::Link::glossary instproc render_found {href label} {
    ::xowiki::Page requireJS  "/resources/xowiki/get-http-object.js"
    ::xowiki::Page requireJS  "/resources/xowiki/popup-handler.js"
    ::xowiki::Page requireJS  "/resources/xowiki/overlib/overlib.js"
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
	if {$id == 0} break ;# don't cache
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