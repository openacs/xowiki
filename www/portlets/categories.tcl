# $Id$
# display the category tree with associated pages
# -gustaf neumann
# 
# valid parameters from the adp include are 
#     tree_name: match pattern, if specified displays only the trees 
#                with matching names
#     no_tree_name: if specified, only tree names are not displayed
#     open_page: name (e.g. en:iMacs) of the page to be opened initially
#     tree_style: boolean, default: true, display based on mktree 
#     skin: name of adp-file to render content

# get the folder id from the including page
set folder_id    [$__including_page set parent_id]
set package_id   [$folder_id set package_id]
set open_item_id [expr {[info exists open_page] ?
			[CrItem lookup -title $open_page -parent_id $folder_id] : 0}]

if {![info exists tree_style]} {set tree_style 1}
if {![info exists plain_include]} {set plain_include 0}
set renderer     [expr {$tree_style ? "render-li" : "render"}]

set content ""
foreach tree [category_tree::get_mapped_trees $package_id] {
  foreach {tree_id my_tree_name ...} $tree {break}
  if {[info exists tree_name] && ![string match $tree_name $my_tree_name]} continue
  if {![info exists no_tree_name]} {
    append content "<h3>$my_tree_name</h3>"
  }
  set categories [list]
  set pos 0
  foreach category [category_tree::get_tree $tree_id] {
    foreach {category_id category_label deprecated_p level} $category {break}
    set order($category_id) [incr pos]
    lappend categories $category_id
  }
  set cattree [::xowiki::CatTree new -volatile]
  db_foreach get_pages \
      "select i.item_id, r.title, i.content_type, p.page_title, category_id \
	 from category_object_map c, cr_items i, cr_revisions r, xowiki_page p \
		where c.object_id = i.item_id and i.parent_id = $folder_id \
		and category_id in ([join $categories ,]) \
		and r.revision_id = i.live_revision \
		and p.page_id = r.revision_id \
	" {
	  
	  if {$page_title eq ""} {set page_title $title}
	  set itemobj [Object new]
	  set prefix ""
	  foreach var {title page_title prefix} {$itemobj set $var [set $var]}
	  $cattree add_to_category \
	      -category_id $category_id \
	      -itemobj $itemobj \
	      -pos $order($category_id) \
	      -open_item [expr {$item_id == $open_item_id}]
	}
  $cattree orderby pos
  append content [$cattree $renderer]
}

if {[info exists skin]} {
  template::set_file "[file dir $__adp_stub]/$skin"
}
set link ""
