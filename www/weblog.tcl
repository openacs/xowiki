
set package_id  [ad_conn package_id]
set folder_id   [::xowiki::Page require_folder -package_id $package_id -name xowiki]
set weblog_page [$folder_id get_payload weblog_page]
if {$weblog_page eq ""} {set weblog_page "en:weblog"}
set item_id [Generic::CrItem lookup -name $weblog_page -parent_id $folder_id]

if {$item_id == 0} {
  set page [::xowiki::Page create new -volatile -noinit \
		-set creator {Gustaf Neumann} \
		-set name $weblog_page \
		-set title {Weblog} \
		-set creation_date {2006-06-18 00:32:30.674009+02} \
		-set creation_user 0 \
		-set item_id 0 \
		-set parent_id $folder_id \
		-set mime_type text/html \
		-set description {} \
		-set text {{<p>&gt;&gt;content&lt;&lt; 
  <br />{{adp portlets/weblog {name Weblog}}} 
  <br />&gt;&gt;&lt;&lt; 
  <br />&gt;&gt;sidebar&lt;&lt; 
  <br />{{adp portlets/weblog-mini-calendar}} 
  <br />{{adp portlets/categories {count 1 skin plain-include}}}
  <br />{{adp portlets/tags {skin plain-include}}} 
  <br />&gt;&gt;&lt;&lt; 
</p>} text/html}]
  set item_id [$page save_new]
}

#if {[ns_queryget page] eq ""} {rp_form_put page $page}
if {[ns_queryget item_id] eq ""} {rp_form_put item_id $item_id}
if {[ns_queryget folder_id] eq ""} {rp_form_put folder_id $folder_id}
rp_internal_redirect "/packages/xowiki/www/view"


