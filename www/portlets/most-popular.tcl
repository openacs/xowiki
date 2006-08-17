# $Id$
# display last visited entries 
# -gustaf neumann
#
# valid parameters from the include are 
#     max_entries: show given number of new entries
#     skin: name of adp-file to render content

::xowiki::Page requireCSS "/resources/acs-templating/lists.css"

::xowiki::Page proc __render_html {
  -folder_id 
  -package_id 
  -max_entries
} {              

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
        -title.href [::$package_id pretty_link $name] \
        -count $sum
  }
  return [t1 asHTML]
}

set content [::xowiki::Page __render_html \
                 -folder_id   [$__including_page set parent_id] \
                 -package_id  [$__including_page set package_id] \
                 -max_entries [expr {[info exists max_entries] ? $max_entries : 10}] \
                ]
if {![info exists name]} {set name "Most Popular Pages"}
set link ""

if {![info exists skin]} {set skin portlet-skin}
if {![string match /* $skin]} {set skin [file dir $__adp_stub]/$skin}
template::set_file $skin

