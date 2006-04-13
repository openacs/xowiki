# $Id$
# display last visited entries 
# -gustaf neumann
#
# valid parameters from the include are 
#     max_entries: show given number of new entries

::xowiki::Page requireCSS "/resources/acs-templating/lists.css"

if {![info exists max_entries]} {set max_entries 20}
if {![info exists user_id]}     {set user_id [ad_conn user_id]}
if {![info exists package_id]}  {set package_id [ad_conn package_id]}

# get the folder id from the including page
set folder_id    [$__including_page set parent_id]

TableWidget t1 -volatile \
    -columns {
      AnchorField title -label [_ xowiki.page_title]
    }

set content ""
db_foreach get_pages \
    "select p.page_title,r.title,  to_char(x.time,'YYYY-MM-DD HH24:MI:SS') as visited_date  \
     from xowiki_last_visited x, xowiki_page p, cr_items i, cr_revisions r  \
	where x.page_id = i.item_id and i.live_revision = p.page_id  and \
	r.revision_id = p.page_id and x.user_id = $user_id and x.package_id = $package_id
        order by x.time desc limit $max_entries
	" {
ns_log notice "-- GOT $page_title"
	  if {$page_title eq ""} {set page_title $title}

	   t1 add \
	      -title $page_title \
	      -title.href [::xowiki::Page pretty_link $title] 
	}

set content [t1 asHTML]
set link ""
