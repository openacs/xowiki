# $Id$
# display last visited entries 
# -gustaf neumann
#
# valid parameters from the include are 
#     max_entries: show given number of new entries

::xowiki::Page requireCSS "/resources/acs-templating/lists.css"

# get the folder id from the including page
set folder_id    [$__including_page set parent_id]

if {![info exists max_entries]} {set max_entries 20}
if {![info exists package_id]}  {set package_id [$folder_id set package_id]}

TableWidget t1 -volatile \
    -columns {
      AnchorField title -label [_ xowiki.page_title]
      Field count -label Count -html { align right }
    }

set content ""
db_foreach get_pages \
    "select sum(x.count), x.page_id, p.page_title,r.title  \
	from xowiki_last_visited x, xowiki_page p, cr_items i, cr_revisions r  \
	where x.page_id = i.item_id and i.live_revision = p.page_id  and r.revision_id = p.page_id \
	and x.package_id = $package_id group by x.page_id, p.page_title, r.title \
	order by sum desc limit $max_entries \
	" {
	  if {$page_title eq ""} {set page_title $title}

	   t1 add \
	      -title $page_title \
	      -title.href [::xowiki::Page pretty_link $title] \
	      -count $sum
	}

set content [t1 asHTML]
set link ""
