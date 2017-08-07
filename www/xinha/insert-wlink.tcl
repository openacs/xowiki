ad_page_contract {
	popup for choosing a target for wiki link
} {
	{package_id:naturalnum,notnull}
	{page_number:integer 1}
	{page_size:integer 20}
}

::xowiki::Package initialize -package_id $package_id
set total_rows [::xowiki::Includelet listing -package_id $package_id -count true]

set url [ad_conn url]
set back_link [expr { ($page_number > 1) ? \
                          [export_vars -base $url [list package_id [list page_number [expr {$page_number-1}]]]] \
                          : ""}]
set next_link [expr { $total_rows > ($page_number * $page_size) ? \
                          [export_vars -base $url [list package_id [list page_number [expr {$page_number+1}]]]] \
                          : ""}]

set listing [::xowiki::Includelet listing \
                 -package_id $package_id -page_number $page_number -page_size $page_size \
                 -orderby "title asc"]

set admin_p [::xo::cc permission \
                 -object_id $package_id -privilege admin \
                 -party_id [::xo::cc set untrusted_user_id]]
set show_heritage $admin_p

TableWidget t1 -volatile \
    -set show_heritage $admin_p \
    -columns {
      if {[[my info parent] set show_heritage]} {
        Field inherited -label ""
      }
      AnchorField name -label [_ xowiki.Page-name] -CSSclass "ok-handler"
      Field title -label [::xowiki::Page::slot::title set pretty_name]
    }

template::add_event_listener -CSSclass "ok-handler" -script {onOK(this);}
template::add_event_listener -id "body" -event "load" -script {Init();}

foreach entry [$listing children] {
  $entry instvar name parent_id title formatted_date page_id 
  set entry_package_id [$entry set package_id]
      
  set page_link [$package_id pretty_link -parent_id $parent_id $name]
  t1 add \
      -title $title \
      -name $name \
      -name.href "#"

  if {$show_heritage} {
    if {$entry_package_id == $package_id} {
      set label ""
    } else {
      set label [$entry_package_id instance_name]
    }
    [t1 last_child] set inherited $label
  }
}

set t1 [t1 asHTML]

# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
