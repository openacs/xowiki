# $Id$
# display recent entries 
# -gustaf neumann
#
# valid parameters from the include are 
#     max_entries: show given number of new entries
#     skin: name of adp-file to render content

::xowiki::Page requireCSS "/resources/acs-templating/lists.css"

::xowiki::Page proc __render_html {
  -folder_id 
  -max_entries
} {
  TableWidget t1 -volatile \
      -columns {
	Field date -label "Modification Date"
	AnchorField title -label [_ xowiki.page_title]
      }

  db_foreach get_pages \
      "select i.name, r.title, \
		to_char(r.publish_date,'YYYY-MM-DD HH24:MI:SS') as publish_date \
	 from cr_items i, cr_revisions r, xowiki_page p \
	 where i.parent_id = $folder_id \
		and r.revision_id = i.live_revision \
		and p.page_id = r.revision_id \
		order by r.publish_date desc limit $max_entries\
      " {
	if {$title eq ""} {set title $name}
	
	t1 add \
	    -title $title \
	    -title.href [::xowiki::Page pretty_link $name] \
	    -date $publish_date
      }

  return [t1 asHTML]
}

set link ""
set content [::xowiki::Page __render_html \
		 -folder_id   [$__including_page set parent_id] \
		 -max_entries [expr {[info exists max_entries] ? $max_entries : 20}] \
		]

if {![info exists skin]} {set skin portlet-skin}
if {![string match /* $skin]} {set skin [file dir $__adp_stub]/$skin}
template::set_file $skin

