ad_page_contract {

} {
  parent_id:notnull,naturalnum
  {bild_url ""}
}

#      {width:text(text),optional {label #xowiki.width_in_pixel}}
#      {height:text(text),optional {label #xowiki.height_in_pixel}}

set js_update ""
ad_form -name upload_form \
    -export { parent_id CKEditorFuncNum } \
    -html { enctype multipart/form-data } \
    -has_submit 1 \
    -mode edit \
    -form {
	{upload_file:file(file),optional {label #xowiki.choose_file#}}
    } -on_submit {
      #set width [template::element::get_values upload_form width]
      #set height [template::element::get_values upload_form height]
      set size ""
      #if {$width ne ""} {append size $width}
      #if {$height ne ""} {append size x$height}

      set file_name [template::util::file::get_property filename $upload_file]
      set upload_tmpfile [template::util::file::get_property tmp_filename $upload_file]
      set mime_type [::xowiki::guesstype $file_name]
      set tmp_size [file size $upload_tmpfile]

      if {$size ne ""} {exec convert -resize $size $upload_tmpfile $upload_tmpfile}
      if {![regexp (image/*|audio/mpeg|application/x-shockwave-flash|application/vnd.adobe.flash-movie|video/mp4) $mime_type]} {
        #template::form::set_error "upload_image" "upload_file" "[_ tlf-resource-integrator.HTMLArea_SelectImageUploadNoImage]"
        break
      }    

      set title $file_name
      set existing_filenames [xo::dc list _ "select name from cr_items  where parent_id = :parent_id" ]
      set filename [util_text_to_url  -text $title -existing_urls $existing_filenames -replacement "_"]
      set package_id [xo::dc get_value _ "select package_id from acs_objects where object_id=:parent_id"]

      ::xowiki::Package initialize -package_id $package_id
      set file_object [::xowiki::File new -destroy_on_cleanup \
                           -title $title \
                           -name file:$filename \
                           -parent_id $parent_id \
                           -package_id $package_id \
                           -mime_type $mime_type \
                           -creation_user [ad_conn user_id]]
      $file_object set import_file $upload_tmpfile
      $file_object save_new
      set revision_id [$file_object set revision_id]

      set bild_url "[$file_object pretty_link]?m=download"
      set image_browser_url [ad_conn package_url]/ckeditor-images
      set js_update "parent.frames\['thumbs'\].location='$image_browser_url/thumb-view?parent_id=$parent_id';"
    }

# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
