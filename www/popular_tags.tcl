# 
# gustaf neumann, fecit june 2006
ad_page_contract {
  load popular tags for a certain page

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date June 2006
  @cvs-id $Id$

  @param item_id show popular tags for the give item_id
} -query {
  item_id
  {limit 20}
}
set package_id  [ad_conn package_id]
set folder_id   [::xowiki::Page require_folder -package_id $package_id -name xowiki]

set href [site_node::get_url_from_object_id -object_id $package_id]weblog?summary=1
set entries [list]
db_foreach get_popular_tags \
    "select count(*) as nr,tag from xowiki_tags \
       where item_id=$item_id group by tag order by nr limit $limit" {
   lappend entries "<a href='$href&ptag=[ad_urlencode $tag]'>$tag ($nr)</a>"
}
ns_return 200 text/html "[_ xowiki.popular_tags_label]: [join $entries {, }]"

