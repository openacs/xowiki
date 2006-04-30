# $Id$
# display the category tree with associated pages
# -gustaf neumann
# 
# valid parameters from the adp include are 
#     tree_name: match pattern, if specified displays only the trees 
#                with matching names
#     no_tree_name: if specified, tree names are not displayed
#     open_page: name (e.g. en:iMacs) of the page to be opened initially
#     tree_style: boolean, default: true, display based on mktree
#     skin: name of adp-file to render content

# get the folder id from the including page
set folder_id    [$__including_page set parent_id]
set package_id   [$folder_id set package_id]
set open_item_id [expr {[info exists open_page] ?
			[CrItem lookup -title $open_page -parent_id $folder_id] : 0}]

if {![info exists name]} {set name "Categories"}
if {![info exists tree_style]} {set tree_style 1}
if {![info exists plain_include]} {set plain_include 0}
if {![info exists count]} {set count 0}

set content ""
foreach tree [category_tree::get_mapped_trees $package_id] {
  foreach {tree_id my_tree_name ...} $tree {break}
  if {[info exists tree_name] && ![string match $tree_name $my_tree_name]} continue
  if {![info exists no_tree_name]} {
    append content "<h3>$my_tree_name</h3>"
  }
  set categories [list]
  set pos 0
  set cattree(0) [::xowiki::CatTree new -volatile -orderby pos -name $my_tree_name]
  foreach category_info [category_tree::get_tree $tree_id] {
    foreach {category_id category_label deprecated_p level} $category_info {break}
    set c [::xowiki::Category new -orderby pos -category_id $category_id \
	       -level $level -label $category_label -pos [incr pos]]
    set cattree($level) $c
    set plevel [expr {$level -1}]
    $cattree($plevel) add $c
    set category($category_id) $c
    lappend categories $category_id
  }
  
  set sql "category_object_map c, cr_items ci, cr_revisions r, xowiki_page p \
		where c.object_id = ci.item_id and ci.parent_id = $folder_id \
		and ci.content_type not in ('::xowiki::PageTemplate') \
		and category_id in ([join $categories ,]) \
		and r.revision_id = ci.live_revision \
		and p.page_id = r.revision_id"
  if {$count} {
    db_foreach get_counts \
	"select count(*),category_id from $sql group by category_id" {
	  $category($category_id) set count $count
	  $category($category_id) href [ad_conn url]?category_id=$category_id
	  $category($category_id) open_tree
	}
    append content [$cattree(0) render -tree_style $tree_style]
  } else {
   db_foreach get_pages \
	"select ci.item_id, r.title, ci.content_type, p.page_title, category_id from $sql" {
	  if {$page_title eq ""} {set page_title $title}
	  set itemobj [Object new]
	  set prefix ""
	  set suffix ""
	  foreach var {title page_title prefix suffix} {$itemobj set $var [set $var]}
	  $cattree(0) add_to_category \
	      -category $category($category_id) \
	      -itemobj $itemobj \
	      -orderby title \
	      -open_item [expr {$item_id == $open_item_id}]
	}
    append content [$cattree(0) render -tree_style $tree_style]
  }
}

if {[info exists skin]} {
  template::set_file "[file dir $__adp_stub]/$skin"
}
set link ""
