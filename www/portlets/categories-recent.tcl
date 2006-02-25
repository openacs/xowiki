# $Id$
# display recent entries by categories
# -gustaf neumann
#
# valid parameters from the include are 
#     tree_name: match pattern, if specified displays only the trees with matching names
#     max_entries: show given number of new entries

if {![info exists max_entries]} {set max_entries 10}

# get the folder id from the including page
set folder_id    [$__including_page set parent_id]
set package_id   [$folder_id set package_id]
set cattree      [::xowiki::CatTree new -volatile]

## provide also a three level display with tree names?

foreach tree [category_tree::get_mapped_trees $package_id] {
  foreach {tree_id my_tree_name ...} $tree {break}
  if {[info exists tree_name] && ![string match $tree_name $my_tree_name]} continue
  lappend trees $tree_id
}
if {[info exists trees]} {
  set tree_select_clause "and c.tree_id in ([join $trees ,])"
} else {
  set tree_select_clause ""
}

db_foreach get_pages \
    "select c.category_id, r.title, p.page_title, \
		to_char(r.publish_date,'YYYY-MM-DD HH24:MI:SS') as publish_date \
	 from category_object_map_tree c, cr_items i, cr_revisions r, xowiki_page p \
	 where c.object_id = i.item_id and i.parent_id = $folder_id \
		and r.revision_id = i.live_revision \
		and p.page_id = r.revision_id $tree_select_clause \
		order by r.publish_date desc limit $max_entries
	" {
	  if {$page_title eq ""} {set page_title $title}
	  set itemobj [Object new]
	  set prefix  $publish_date
	  foreach var {title page_title prefix} {$itemobj set $var [set $var]}
	  $cattree add_to_category -category_id $category_id -itemobj $itemobj
	}

set content [$cattree render]
set link ""
