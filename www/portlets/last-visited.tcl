# $Id$
# display last visited entries 
# -gustaf neumann
#
# valid parameters from the include are 
#     max_entries: show given number of new entries
#     user_id
#     skin: name of adp-file to render content

::xowiki::Page requireCSS "/resources/acs-templating/lists.css"

::xowiki::Page proc __render_html {
  -folder_id 
  -user_id 
  -max_entries
} {
  set package_id   [$folder_id set package_id]

  TableWidget t1 -volatile \
      -columns {
	AnchorField title -label [_ xowiki.page_title]
      }

  db_foreach get_pages \
      "select r.title,i.name, to_char(x.time,'YYYY-MM-DD HH24:MI:SS') as visited_date  \
       from xowiki_last_visited x, xowiki_page p, cr_items i, cr_revisions r  \
	 where x.page_id = i.item_id and i.live_revision = p.page_id  and \
	 r.revision_id = p.page_id and x.user_id = $user_id and x.package_id = $package_id
         order by x.time desc limit $max_entries
      " {
	if {$title eq ""} {set title $name}

	t1 add \
	    -title $title \
	    -title.href [::xowiki::Page pretty_link $name] 
      }
  return [t1 asHTML]
}

set link ""
if {![info exists name]} {set name "Last Visited Pages"}
set content [::xowiki::Page __render_html \
		 -folder_id   [$__including_page set parent_id] \
		 -max_entries [expr {[info exists max_entries] ? $max_entries : 20}] \
		 -user_id     [expr {[info exists user_id] ? $user_id : \
					 [ad_conn isconnected] ? [ad_conn user_id] : 0}] \
		]

if {![info exists skin]} {set skin portlet-skin}
if {![string match /* $skin]} {set skin [file dir $__adp_stub]/$skin}
template::set_file $skin


