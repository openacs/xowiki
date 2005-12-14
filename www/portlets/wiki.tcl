
# get the folder id from the including page
set folder_id [$__including_page set parent_id]
set item_id   [::Generic::CrItem lookup -title $name -parent_id $folder_id]
set page      [::Generic::CrItem instantiate -item_id $item_id]
$page volatile

if {[::xowiki::Page incr recursion_count]<3} {
  set content [$page render]
  set link [export_vars -base view {item_id}]
  ns_log notice "RECURSION_COUNT = [::xowiki::Page set recursion_count]"
} else {
  set content "Recursion Limit exceeded, items are nested to deep!"
}

::xowiki::Page incr recursion_count -1
