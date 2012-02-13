ad_page_contract {

} {
  parent_id:notnull,integer
  {bild_url ""}
} 
set package_url [ad_conn package_url]
set image_browser_url [ad_conn url]
set fs_package_id $parent_id
set CKEditorFuncNum 0
set item_id $fs_package_id
#::xo::db::CrClass get_instance_from_db -item_id $fs_package_id

