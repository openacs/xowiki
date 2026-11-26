ad_page_contract {
  Stage a clipboard image and return the URL used in preview and after save.
} {
  parent_id:naturalnum,notnull
}

if {[ns_conn method] ne "POST"} {
  ns_return 405 text/plain "Use POST to upload an image."
  ad_script_abort
}

auth::require_login
set token [security::csrf::new]
if {$token eq "" || [ns_queryget __csrf_token] ne $token} {
  ns_return 403 text/plain "Invalid upload token."
  ad_script_abort
}

set package_id [ad_conn package_id]
::xowiki::Package initialize -package_id $package_id

if {[catch {::xo::db::CrClass get_instance_from_db -item_id $parent_id} parent]
    || $parent eq "" || ![$parent istype ::xowiki::Page]
    || [$parent package_id] != $package_id || ![$parent is_folder_page -include_folder_links false]} {
  ns_return 404 text/plain "Upload folder not found."
  ad_script_abort
}
permission::require_permission -object_id $parent_id -privilege create

set files [ns_getformfile upload]
if {[llength $files] != 1 || ![security::safe_tmpfile_p -must_exist [lindex $files 0]]} {
  ns_return 400 text/plain "Upload one image."
  ad_script_abort
}
set tmpfile [lindex $files 0]
if {[::xowiki::markdown_image::mime_type $tmpfile] eq ""} {
  ns_return 415 text/plain "Paste a PNG, JPEG, or GIF image."
  ad_script_abort
}

set image_id [db_nextval acs_object_id_seq]
set directory [::xowiki::markdown_image::directory]
file mkdir $directory
set channel [file tempfile temporary $directory/upload-]
close $channel
try {
  file copy -force -- $tmpfile $temporary
  file attributes $temporary -permissions 0600
  file rename -- $temporary [::xowiki::markdown_image::draft_path $image_id]
} finally {
  file delete -- $temporary
}
ns_return 201 text/plain [export_vars -base [ad_conn package_url]markdown-image {image_id}]
ad_script_abort
