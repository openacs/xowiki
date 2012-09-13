ad_page_contract {
  @author Neophytos Demetriou
} {
  item_id:naturalnum
  revision_id:naturalnum
  {preview:boolean "0"}
}

set file_object [::xo::db::CrClass get_instance_from_db -item_id $item_id]

set name [$file_object name]
set type [string trimleft [string tolower [file extension ${name}]] {.}]
if { $type eq {} && -1 == [string first {:} $id] } {
  set type "folder"
}
if { $type eq {pdf} && $preview } {
  set infile [$file_object full_file_name]
  set dir [file join [acs_root_dir] cr_preview ${item_id}]
  set outfile [file join $dir ${item_id}-0.png]
  set thumbnail_file [file join $dir ${item_id}-200.png]
  if { ![file isdirectory $dir] } {
    file mkdir $dir
    util_gen_doc_preview $infile $outfile
    util_scale_image "200x" $outfile $thumbnail_file
  }
} else {
  set thumbnail_file [file join [acs_root_dir] packages xowiki www resources ${type}-icon.png]
}

ad_returnfile_background 200 image/png $thumbnail_file