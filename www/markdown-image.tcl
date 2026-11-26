ad_page_contract {
  Serve child Files for editor Preview, legacy attachments, or private drafts.
} {
  {image_id:naturalnum ""}
  {page_id:naturalnum ""}
  {name ""}
}

set package_id [ad_conn package_id]
if {$page_id ne ""} {
  ::xowiki::Package initialize -package_id $package_id
  if {![regexp {^pasted-[1-9][0-9]*\.(png|jpeg|gif)$} $name]
      || [catch {::xo::db::CrClass get_instance_from_db -item_id $page_id} page]
      || $page eq "" || ![$page istype ::xowiki::Page]
      || [$page package_id] != $package_id
      || ![::$package_id check_permissions $page view]} {
    ns_returnnotfound
    ad_script_abort
  }
  set child_id [::xo::db::CrClass lookup -parent_id $page_id -name file:$name]
  if {$child_id != 0} {
    set child [::xo::db::CrClass get_instance_from_db -item_id $child_id]
    if {[$child istype ::xowiki::File] && [$child mime_type] in {image/png image/jpeg image/gif}} {
      cr_write_content -revision_id [$child revision_id]
      ad_script_abort
    }
  }
  ns_returnnotfound
  ad_script_abort
}
if {$image_id eq ""} {
  ns_returnnotfound
  ad_script_abort
}
if {[namespace which ::attachments::richtext::file_attach] ne ""
    && [db_0or1row xowiki_markdown_image_attachment {
  select a.object_id, r.revision_id
  from attachments a
  join cr_items i on i.item_id = a.item_id
  join acs_objects o on o.object_id = i.item_id and o.context_id = a.object_id
  join cr_revisions r on r.revision_id = i.live_revision
  where a.item_id = :image_id and o.package_id = :package_id
    and r.mime_type in ('image/png', 'image/jpeg', 'image/gif')
}]} {
  ::xowiki::Package initialize -package_id $package_id
  set page [::xo::db::CrClass get_instance_from_db -item_id $object_id]
  if {![$page istype ::xowiki::Page] || ![::$package_id check_permissions $page view]} {
    ns_returnnotfound
    ad_script_abort
  }
  cr_write_content -revision_id $revision_id
  ad_script_abort
}

if {[ad_conn user_id] != 0 && [acs_object_type $image_id] eq ""} {
  set path [::xowiki::markdown_image::draft_path $image_id]
  set mime [::xowiki::markdown_image::mime_type $path]
  if {$mime ne ""} {
    ns_set put [ns_conn outputheaders] Cache-Control "private, no-store"
    ns_returnfile 200 $mime $path
    ad_script_abort
  }
}
ns_returnnotfound
ad_script_abort
