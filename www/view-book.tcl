set title [$package_id get_parameter PackageTitle [$package_id instance_name]]
set toc   [$page include [list toc -open_page $name -decoration plain -remove_levels 1]]
set i     [$page set __last_includelet]
#$package_id log "--last includelet = $i, class=[$i info class] [$page exists __is_book_page]"

# prevent recursive books
if {$i ne "" && ![$page exists __is_book_page]} {
  set p     [$i position]
  set count [$i count]

  if {$count > 0} {
    set book_relpos [format %.2f%% [expr {100.0 * $p / $count}]]
    if {$p>1}      {set book_prev_link [$package_id pretty_link -parent_id [$i parent_id] [$i page_name [expr {$p - 1}]]]}
    if {$p<$count} {set book_next_link [$package_id pretty_link -parent_id [$i parent_id] [$i page_name [expr {$p + 1}]]]}
    set page_title "<h2>[$i current] $title</h2>"
  } else {
    set book_relpos 0.0%
    set page_title "<h2>$title</h2>"    
  }
}
set header_stuff [::xo::Page header_stuff]
