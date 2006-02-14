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

Class CatTree -volatile -superclass ::xo::OrderedComposite 
CatTree instproc add_to_category {-category_id -itemobj} {
  set catobj [self]::$category_id
  if {![my isobject $catobj]} {::xo::OrderedComposite create $catobj; my add $catobj}
  $catobj add $itemobj
}
CatTree instproc render {} {
  set content ""
  foreach c [my children] {
    set cat_content ""
    foreach i [$c children] {
      $i instvar title page_title publish_date
      append cat_content "$publish_date <a href='[::xowiki::Page pretty_link $title]'>$page_title</a><br>\n"
    }
    append content "<h3>[category::get_name [namespace tail $c]]</h3><blockquote>" \
	$cat_content "</blockquote>\n"
  }
  return $content
}
set cattree [CatTree new -volatile]

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
	  foreach var {title page_title publish_date} {$itemobj set $var [set $var]}
	  $cattree add_to_category -category_id $category_id -itemobj $itemobj
	}

set content [$cattree render]
set link ""
