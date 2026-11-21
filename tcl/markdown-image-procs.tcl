ad_library {
  Stage clipboard images and attach them when their XoWiki page is saved.
}

namespace eval ::xowiki::markdown_image {}

ad_proc -private ::xowiki::markdown_image::directory {} {
  Return the temporary directory for pasted XoWiki images.
} {
  return [file join [ns_config ns/parameters tmpdir] xowiki-markdown-images]
}

ad_proc -private ::xowiki::markdown_image::draft_path {image_id} {
  Find the staged image for the current user and XoWiki instance.
} {
  return [file join [directory] "[ad_conn package_id].[ad_conn user_id].$image_id"]
}

ad_proc -private ::xowiki::markdown_image::mime_type {path} {
  Identify a supported bitmap by its contents.
} {
  if {![file isfile $path] || [catch {ns_imgtype $path} type] || $type ni {png jpeg gif}
      || [catch {ns_imgsize $path} size] || [llength $size] != 2
      || [lindex $size 0] <= 0 || [lindex $size 1] <= 0} {
    return ""
  }
  return image/$type
}

ad_proc -private ::xowiki::markdown_image::drafts {page} {
  Collect this user's staged inline images referenced by the page and its form fields.
} {
  if {![ns_conn isconnected] || [ad_conn user_id] == 0
      || [ad_conn package_id] != [$page package_id]
      || [namespace which ::attachments::richtext::file_attach] eq ""} {
    return {}
  }
  set values {}
  if {[$page exists text]} {
    lappend values [$page set text]
  }
  if {[$page exists instance_attributes]} {
    lappend values {*} [dict values [$page set instance_attributes]]
  }

  set prefix [ad_conn package_url]markdown-image?image_id=
  set drafts {}
  foreach html $values {
    if {[string first $prefix $html] == -1} continue
    foreach tag [ns_parsehtml -onlytags -- $html] {
      lassign $tag element attributes
      if {![string equal -nocase $element img] || ![dict exists $attributes src]} continue
      set src [dict get $attributes src]
      if {[string first $prefix $src] != 0} continue
      set image_id [string range $src [string length $prefix] end]
      if {![regexp {^[1-9][0-9]*$} $image_id] || [dict exists $drafts $image_id]} continue

      # A previously attached image, including one referenced from another page,
      # keeps its current owner.
      if {[acs_object_type $image_id] ne ""} continue
      set path [draft_path $image_id]
      set mime [mime_type $path]
      if {$mime eq ""} {
        error "A pasted image is unavailable. Remove it or paste it again."
      }
      dict set drafts $image_id [list $path $mime]
    }
  }
  return $drafts
}

ad_proc -private ::xowiki::markdown_image::attach {page drafts} {
  Save each staged image as an attachment owned by this page.
} {
  set object_id [$page item_id]
  dict for {image_id draft} $drafts {
    lassign $draft path mime
    set result [attachments::richtext::file_attach \
                    -item_id $image_id -object_id $object_id \
                    -import_file $path -mime_type $mime \
                    -title "Pasted image.[lindex [split $mime /] 1]" \
                    -user_id [ad_conn user_id] -peeraddr [ad_conn peeraddr] \
                    -package_id [$page package_id]]
    if {![dict get $result success]} {
      error "Could not attach the pasted image."
    }
    # FormPage may still be inside an outer transaction. Verify the commit
    # before discarding the file, so the editor can retry a failed save.
    ns_atclose [list ::xowiki::markdown_image::discard_attached_draft $object_id $image_id $path]
  }
}

ad_proc -private ::xowiki::markdown_image::discard_attached_draft {object_id image_id path} {
  Drop a staging file after the page and attachment commit.
} {
  if {[db_string xowiki_markdown_image_committed {
    select 1 from attachments where object_id = :object_id and item_id = :image_id
  } -default 0]} {
    file delete -- $path
  }
}

ad_proc -private ::xowiki::markdown_image::expire_drafts {} {
  Clean up private staging files, including uploads from abandoned forms.
} {
  set cutoff [expr {[clock seconds] - 86400}]
  foreach path [glob -nocomplain -directory [directory] -types f *] {
    catch {
      if {[file mtime $path] < $cutoff} {
        file delete -- $path
      }
    }
  }
}
