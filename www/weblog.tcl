set package_id [ad_conn package_id]
set Package    [::xowiki::Package create ::$package_id]
$Package instvar folder_id
set weblog_page [$Package get_parameter weblog_page "en:weblog"]
set page [$Package resolve_request -path $weblog_page]
#$Package log "weblog-page = $page"

if {$page eq ""} {
  set page [::xowiki::Page create new -volatile -name $weblog_page \
		-title Weblog -parent_id $folder_id -package_id $package_id \
		-text [::xowiki::Page quoted_html_content {>>content<<
{{adp portlets/weblog {name Weblog}}}
>><<
>>sidebar<<
{{adp portlets/weblog-mini-calendar}}
{{adp portlets/tags {skin plain-include}}}
{{adp portlets/tags {skin plain-include popular 1 limit 30}}}
{{adp portlets/categories {count 1 skin plain-include}}}
>><<}]]
  set item_id [$page save_new]
}
$Package url [::xowiki::Page pretty_link -package_id $package_id $weblog_page]
ns_return 200 text/html [$page view]




