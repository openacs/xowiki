ad_page_contract {

} {
  parent_id:notnull,integer
  {bild_url ""}
}
set js_update ""
ad_form -name upload_form \
    -export { parent_id CKEditorFuncNum } \
    -html { enctype multipart/form-data } \
    -mode edit \
    -form {
      {upload_file:file(file),optional {label "Bild zum Hochladen auswählen"}}
      {width:text(text),optional {label "Breite in Pixel"}}
      {height:text(text),optional {label "Höhe in Pixel"}}
    } -on_submit {
      set width [template::element::get_values upload_form width]
      set height [template::element::get_values upload_form height]
      set size ""
      if {$width ne ""} {append size $width}
      if {$height ne ""} {append size x$height}

      set file_name [template::util::file::get_property filename $upload_file]
      set upload_tmpfile [template::util::file::get_property tmp_filename $upload_file]
      set mime_type [template::util::file::get_property mime_type $upload_file]
      #ds_comment $upload_tmpfile
      if {$size ne ""} {exec convert -resize $size $upload_tmpfile $upload_tmpfile}

      if {![string match image/* $mime_type]} {
	# File is no image
	template::form::set_error "upload_image" "upload_file" "[_ acs-templating.HTMLArea_SelectImageUploadNoImage]"
	break
      }

      #set parent_id  [db_string _ "select parent_id from cr_items where item_id=:fs_package_id"]
      set title $file_name
      
      set existing_filenames [db_list _ "select name from cr_items  where parent_id = :parent_id" ]
      ns_log notice "util_text_to_url  -text ${title} -existing_urls \"$existing_filenames\" -replacement \"_\""	
      set filename [util_text_to_url  -text "${title}" -existing_urls "$existing_filenames" -replacement "_"]
      set package_id [db_string _ "select package_id from acs_objects where object_id=:parent_id"]
      ::xowiki::Package initialize -package_id $package_id
      set file_object [::xowiki::File new -destroy_on_cleanup \
                           -title $title \
                           -name file:$filename \
                           -parent_id $parent_id \
                           -package_id $package_id \
                           -mime_type [::xowiki::guesstype $title] \
                           -creation_user [ad_conn user_id]]
      $file_object set import_file $upload_tmpfile
      $file_object save_new
      set revision_id [$file_object set revision_id]

      set bild_url "[$file_object pretty_link]?m=download"
      set image_browser_url [ad_conn package_url]/ckeditor-images
      set js_update "parent.frames\['thumbs'\].location='$image_browser_url/thumb-view?parent_id=${parent_id}';"
    }
