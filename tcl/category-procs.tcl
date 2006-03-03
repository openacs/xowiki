namespace eval ::xowiki {
  Class CatTree -superclass ::xo::OrderedComposite -parameter order_items_by

  CatTree instproc add_to_category {
    -category_id 
    -itemobj 
    {-pos 0} 
    {-open_item:boolean false}
  } {
    set catobj [self]::$category_id
    if {![my isobject $catobj]} {
      ::xo::OrderedComposite create $catobj
      if {[my exists order_items_by]} {
	$catobj orderby [my set order_items_by]
      }
      $catobj set pos $pos
      $catobj set open_requests 0
      my add $catobj
    }
    if {$open_item} {
      $catobj incr open_requests
      $itemobj set open_item 1
    }
    $catobj add $itemobj
  }

  CatTree instproc render {} {
    set content ""
    foreach c [my children] {
      set cat_content ""
      foreach i [$c children] {
	$i instvar title page_title prefix open_item
	set openProps [expr {[info exists open_item] ? [list <b> </b>] : {}}]
	append cat_content [lindex $openProps 0] $prefix " <a href='" \
	    [::xowiki::Page pretty_link $title] \
	    "'>$page_title</a>" [lindex $openProps 1] "<br>\n"
      }
      append content "<h3>[category::get_name [namespace tail $c]]</h3><blockquote>" \
	  $cat_content "</blockquote>\n"
    }
    return $content
  }

  CatTree instproc render-li {} {
    ::xowiki::Page requireCSS "/resources/acs-templating/mktree.css"
    ::xowiki::Page requireJS  "/resources/acs-templating/mktree.js"
    set content "<ul class='mktree' id='[self]'>"
    foreach c [my children] {
      set cat_content ""
      foreach i [$c children] {
	$i instvar title page_title prefix open_item
	set openProps [expr {[info exists open_item] ? [list <b> </b>] : {}}]
	append cat_content "<li style='padding-left: -0px; list-style: none;'>" \
	    [lindex $openProps 0] $prefix "<a href='[::xowiki::Page pretty_link $title]'>$page_title</a>" \
	    [lindex $openProps 1] "</li>\n"
      }
      set open_state [expr {[$c set open_requests]>0?"class='liOpen'" : "class='liClosed'"}]
      append content "<li $open_state>[category::get_name [namespace tail $c]]" \
	  "<ul>" $cat_content "</ul>\n"
    }
    return "$content</ul>"
  }

}
