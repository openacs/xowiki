# $Id$
# display recent entries by categories
# -gustaf neumann
#
# valid parameters from the include are 
#     tree_name: match pattern, if specified displays only the trees with matching names
#     max_entries: show given number of new entries
#     skin: name of adp-file to render content

::xowiki::Page proc __render_html {
  -package_id 
  -max_entries
  -tree_name
} {		 
  set cattree [::xowiki::CatTree new -volatile -name "categories-recent"]

  foreach tree [category_tree::get_mapped_trees $package_id] {
    foreach {tree_id my_tree_name ...} $tree {break}
    if {$tree_name ne "" && ![string match $tree_name $my_tree_name]} continue
    lappend trees $tree_id
  }
  if {[info exists trees]} {
    set tree_select_clause "and c.tree_id in ([join $trees ,])"
  } else {
    set tree_select_clause ""
  }
  
  db_foreach get_pages \
    "select c.category_id, i.name, r.title, \
	 to_char(r.publish_date,'YYYY-MM-DD HH24:MI:SS') as publish_date \
       from category_object_map_tree c, cr_items i, cr_revisions r, xowiki_page p \
       where c.object_id = i.item_id and i.parent_id = [$package_id folder_id] \
	 and r.revision_id = i.live_revision \
	 and p.page_id = r.revision_id $tree_select_clause \
	 order by r.publish_date desc limit $max_entries
     " {
       if {$title eq ""} {set title $name}
       set itemobj [Object new]
       set prefix  "$publish_date "
       set suffix  ""
       foreach var {name title prefix suffix} {$itemobj set $var [set $var]}
       if {![info exists categories($category_id)]} {
	 set categories($category_id) [::xowiki::Category new \
                                           -package_id $package_id \
					   -label [category::get_name $category_id]\
					   -level 1]
	 $cattree add  $categories($category_id)
       }
       $cattree add_to_category -category $categories($category_id) -itemobj $itemobj
     }
  return [$cattree render]
}

set content [::xowiki::Page __render_html \
		 -max_entries [expr {[info exists max_entries] ? $max_entries : 10}] \
		 -tree_name   [expr {[info exists tree_name] ? $tree_name : ""}] \
		 -package_id  [$__including_page set package_id] \
		]
if {![info exists name]} {set name "Recently Changed Pages by Categories"}
set link ""

if {![info exists skin]} {set skin portlet-skin}
if {![string match /* $skin]} {set skin [file dir $__adp_stub]/$skin}
template::set_file $skin

