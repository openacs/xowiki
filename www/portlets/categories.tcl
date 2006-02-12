# $Id$
# display the category tree with associated pages
# -gustaf neumann
# 
# valid parameters from the include are 
#     tree_name: match pattern, if specified displays only the trees with matching names
#     no_tree_name: if specified, only tree names are not displayed

# get the folder id from the including page
set folder_id   [$__including_page set parent_id]
set package_id  [$folder_id set package_id]
set url_prefix  [site_node::get_url_from_object_id -object_id $package_id]

set content ""
foreach tree [category_tree::get_mapped_trees $package_id] {
  foreach {tree_id my_tree_name ...} $tree {break}
  if {[info exists tree_name] && ![string match $tree_name $my_tree_name]} continue
  if {![info exists no_tree_name]} {
    append content "<h2>$my_tree_name</h2>"
  }
  foreach category [category_tree::get_tree $tree_id] {
    foreach {category_id category_label deprecated_p level} $category {break}
    set cat_content ""
    db_foreach get_pages \
	"select i.item_id, r.title, i.content_type, p.page_title \
	 from category_object_map c, cr_items i, cr_revisions r,  xowiki_page p \
		where c.object_id = i.item_id and i.parent_id = $folder_id \
		and category_id = $category_id \
		and r.revision_id = i.live_revision \
		and p.page_id = r.revision_id \
	" {
	  if {$page_title eq ""} { set page_title $title}
	  if {![::xotcl::Object isclass $content_type]} {
	    # we could check for certain page types as well
	    continue
	  }
	  append cat_content "<a href='[::xowiki::Page pretty_link $title]'>$page_title</a><br>\n"
	}
    if {$cat_content ne ""} {
      append content "<h3>$category_label</h3><blockquote>" $cat_content "</blockquote>\n"
    }
  }
}

set link ""
