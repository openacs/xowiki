ad_page_contract {

} {
  parent_id:notnull,naturalnum
  {bild_url ""}
}
set package_url [ad_conn package_url]
set image_browser_url $package_url/ckeditor-images
set fs_package_id $parent_id
set CKEditorFuncNum 0
set item_id $fs_package_id
#::xo::db::CrClass get_instance_from_db -item_id $fs_package_id

template::add_body_handler -event onload -script {Init();}

# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
