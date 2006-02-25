# $Id$
# display recent entries 
# -gustaf neumann
#
# valid parameters from the include are 
#     max_entries: show given number of new entries

::xowiki::Page requireCSS "/resources/acs-templating/lists.css"

if {![info exists max_entries]} {set max_entries 20}

# get the folder id from the including page
set folder_id    [$__including_page set parent_id]

TableWidget t1 -volatile \
    -columns {
      Field date -label "Modification Date"
      AnchorField title -label [_ xowiki.page_title]
    }

set content ""
db_foreach get_pages \
    "select r.title, p.page_title, \
		to_char(r.publish_date,'YYYY-MM-DD HH24:MI:SS') as publish_date \
	 from cr_items i, cr_revisions r, xowiki_page p \
	 where i.parent_id = $folder_id \
		and r.revision_id = i.live_revision \
		and p.page_id = r.revision_id \
		order by r.publish_date desc limit $max_entries
	" {
	  if {$page_title eq ""} {set page_title $title}

	   t1 add \
	      -title $page_title \
	      -title.href [::xowiki::Page pretty_link $title] \
	      -date $publish_date
	}

set content [t1 asHTML]
set link ""
