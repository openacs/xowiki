# $Id$
# display the tags
# -gustaf neumann
# 
# valid parameters from the adp include are 
#     popular: list tags from all users
#     skin: name of adp-file to render content

::xowiki::Page proc __render_html {
  -folder_id 
  -user_id
  {-limit 20}
  {-summary 0}
  {-popular 0}
} {

  # get the folder id from the including page
  set package_id   [$folder_id set package_id]

  if {$popular} {
    set label [_ xowiki.popular_tags_label]
    set tag_type ptag
    set sql "select count(*) as nr,tag from xowiki_tags where \
	package_id=$package_id group by tag order by tag limit $limit"
  } else {
    set label [_ xowiki.your_tags_label]
    set tag_type tag 
    set sql "select count(*) as nr,tag from xowiki_tags where \
	user_id=$user_id and package_id=$package_id group by tag order by tag"
  }
  set content "<h3>$label</h3> <BLOCKQUOTE>"
  set entries [list]
  db_foreach get_counts $sql {
    set s [expr {$summary ? "&summary=$summary" : ""}]
    set href [ad_conn url]?$tag_type=[ad_urlencode $tag]$s
    lappend entries "$tag <a href='$href'>($nr)</a>"
  }
  append content "[join $entries {, }]</BLOCKQUOTE>\n"
  return $content
}

set link ""
if {![info exists name]} {set name "Tags"}
if {![info exists limit]} {set limit 20}
set summary [ns_queryget summary 0]
set content [::xowiki::Page __render_html \
		 -folder_id    [$__including_page set parent_id] \
		 -user_id      [ad_conn user_id]  \
		 -summary      $summary \
		 -limit        $limit \
		 -popular      [info exists popular] \
		]

if {![info exists skin]} {set skin portlet-skin}
if {![string match /* $skin]} {set skin [file dir $__adp_stub]/$skin}
template::set_file $skin


