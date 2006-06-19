# $Id$
# display a wiki page included in a different wiki page
# -gustaf neumann
#
# valid parameters from the include are 
#     name: name of the xowiki page to render
#     skin: name of adp-file to render content


set folder_id  [$__including_page set parent_id]
set item_id    [::Generic::CrItem lookup -name $name -parent_id $folder_id]
set page       [::Generic::CrItem instantiate -item_id $item_id]
$page volatile

if {[::xowiki::Page incr recursion_count]<3} {
  set content [$page render]
  set link [::xowiki::Page pretty_link $name]
} else {
  set content "Recursion Limit exceeded, items are nested to deep!"
}

::xowiki::Page incr recursion_count -1
#strip language prefix for name
regexp {^..:(.*)$} $name _ name

if {![info exists skin]} {set skin portlet-skin}
if {![string match /* $skin]} {set skin [file dir $__adp_stub]/$skin}
template::set_file $skin

