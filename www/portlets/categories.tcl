
# get the folder id from the including page
set folder_id [$__including_page set parent_id]
set package_id [db_string get_package_id \
		    "select package_id from acs_objects where object_id = $folder_id"]
set content ""
foreach tree [category_tree::get_mapped_trees $package_id] {
  foreach {tree_id tree_name ...} $tree {break}
  foreach category [category_tree::get_tree $tree_id] {
    foreach {category_id category_label deprecated_p level} $category {break}
    set cat_content ""
    db_foreach get_pages \
	"select i.item_id, r.title, i.content_type from category_object_map c, cr_items i, cr_revisions r \
		where c.object_id = i.item_id and i.parent_id = $folder_id \
		and category_id = $category_id \
		and r.revision_id = i.live_revision \
	" {
	  if {![::xotcl::Object isclass $content_type]} {
	    # we could check for certain page types as well
	    continue
	  }
	  append cat_content "<a href='[ad_urlencode $title]'>$title</a><br>\n"
	}
    if {$cat_content ne ""} {
      append content "<h3>$category_label</h3><blockquote>" $cat_content "</blockquote>\n"
    }
  }
}

set link ""
