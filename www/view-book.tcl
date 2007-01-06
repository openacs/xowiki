
#ns_log notice "--including_page= $__including_page, portlet=$portlet"
set toc [$page include_portlet [list toc -open_page $name  -decoration plain -remove_levels 1]]
set i [$page set __last_includelet]
my log "--last includelet = [$page set __last_includelet] [$page exists __is_book_page]"
if {$i ne "" && ![$page exists __is_book_page]} {
  set p [$i position]
  set count [$i count]
  set book_relpos [format %.2f%% [expr {100.0 * $p / $count}]]
  if {$p>1}      {set book_prev_link [$package_id pretty_link [$i page_name [expr {$p - 1}]]]}
  if {$p<$count} {set book_next_link [$package_id pretty_link [$i page_name [expr {$p + 1}]]]}
  ns_log notice "--p=$p, count=$count, relpos=$book_relpos, {100.0 * $p / $count} next=[info exists next_link], prev=[info exists prev_link]"
  set page_title "<h2>[$i current] $title</h2>"
}
set header_stuff [::xowiki::Page header_stuff]
