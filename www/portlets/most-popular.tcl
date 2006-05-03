# $Id$
# display last visited entries 
# -gustaf neumann
#
# valid parameters from the include are 
#     max_entries: show given number of new entries

::xowiki::Page requireCSS "/resources/acs-templating/lists.css"

::xowiki::Page proc __render_html {
  -folder_id 
  -max_entries
} {		 
  set package_id [$folder_id set package_id]

  TableWidget t1 -volatile \
      -columns {
	AnchorField title -label [_ xowiki.page_title]
	Field count -label Count -html { align right }
      }

  db_foreach get_pages \
    "select sum(x.count), x.page_id, r.title,i.name  \
	from xowiki_last_visited x, xowiki_page p, cr_items i, cr_revisions r  \
	where x.page_id = i.item_id and i.live_revision = p.page_id  and r.revision_id = p.page_id \
	and x.package_id = $package_id group by x.page_id, r.title, i.name \
	order by sum desc limit $max_entries " \
  {
    if {$title eq ""} {set title $name}
    
    t1 add \
	-title $title \
	-title.href [::xowiki::Page pretty_link $name] \
	-count $sum
  }
  return [t1 asHTML]
}

set content [::xowiki::Page __render_html \
		 -folder_id   [$__including_page set parent_id] \
		 -max_entries [expr {[info exists max_entries] ? $max_entries : 10}] \
		]
if {![info exists name]} {set name "Most Popular Pages"}
set link ""
