namespace eval ::xowiki {
  #
  # ::xowiki::CatTree  (category tree)
  #

  Class CatTree -superclass ::xo::OrderedComposite -parameter {name ""}

  CatTree instproc add_to_category {
    -category
    -orderby
    -itemobj
    {-increasing:boolean true} 
    {-open_item:boolean false}
  } {
    set items ${category}::items
    if {![my isobject $items]} { 
      ::xo::OrderedComposite create $items
      if {[info exists orderby]} {
	set direction [expr {$increasing?"increasing":"decreasing"}]
	$items orderby -order $direction $orderby
      }
    }
    $items add $itemobj
    if {$open_item} {
      $category openTree
      $itemobj set open_item 1
    }
  }
  CatTree instproc openTree {} {;}

  CatTree instproc render {{-tree_style:boolean false}} {
    if {$tree_style} {
      #::xowiki::Page requireCSS "/resources/acs-templating/mktree.css"
      ::xowiki::Page requireCSS  "/resources/xowiki/cattree.css"
      ::xowiki::Page requireJS  "/resources/acs-templating/mktree.js"
      
      foreach c [my children] {append content [$c render] \n}
      return "<ul class='mktree' id='[my name]'>$content</ul>"
    } else {
      Category instmixin Category::section_style
      foreach c [my children] {append content [$c render] \n}
      Category instmixin ""
      return $content
    }
  }

  #
  # ::xowiki::Category 
  #
  
  Class Category -superclass ::xo::OrderedComposite -parameter {
    level label pos category_id {open_requests 0}
  }
  Category instproc destroy {} {
    my log --
    next
  }
  Category instproc openTree {} {
    my set open_requests 1
    if {[my exists __parent]} {[my set __parent] openTree}
  }

  Category instproc render {} {
    set content ""
    if {[my isobject [self]::items]} {
      foreach i [[self]::items children] {
	$i instvar title page_title prefix suffix
	set entry "$prefix<a href='[::xowiki::Page pretty_link $title]'>$page_title</a>$suffix"
	append cat_content [my render_item -highlight [$i exists open_item] $entry]
      }
      foreach c [my children] {append cat_content [$c render] \n}
      append content [my render_category -open [expr {[my set open_requests]>0}] $cat_content]
    }
    return $content
  }

  #
  # These are the list-specific rendering functions
  #

  Category instproc render_item {{-highlight:boolean false} item} {
    if {$highlight} {
      return "<li class='liItem'><b>$item</b></li>\n"
    } else {
      return "<li class='liItem'>$item</li>\n"
    }
  }
  Category instproc render_category {{-open:boolean false} cat_content} {
    set open_state [expr {[my set open_requests]>0?"class='liOpen'" : "class='liClosed'"}]
    return "<li $open_state>[my label]\n <ul>$cat_content</ul>\n"
  }

  #
  # These are the section-specific rendering functions
  #
  
  Class Category::section_style
  Category::section_style instproc render_item {{-highlight:boolean false} item} {
    if {$highlight} {
      return "<b>$item</b><br>\n"
    } else {
      return "$item<br>\n"
    }
  }
  Category::section_style instproc render_category {{-open:boolean false} cat_content} {
    set section [expr {[my level] + 2}]
    return "<H$section>[my label]</H$section>\n<p>\
	<blockquote style='margin-left: 2em; margin-right:0px;'>$cat_content</blockquote>\n"
  }


}
