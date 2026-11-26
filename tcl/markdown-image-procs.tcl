ad_library {
  Stage clipboard images and store them as child XoWiki Files on save.
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
      || [ad_conn package_id] != [$page package_id]} {
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

      # Promote images from the earlier attachment implementation on the next
      # save of their owner. Retain the old attachment for historical revisions.
      if {[acs_object_type $image_id] ne ""} {
        if {[$page exists item_id]
            && [namespace which ::attachments::richtext::file_attach] ne ""} {
          set owner_id [$page item_id]
          if {[db_0or1row xowiki_markdown_legacy_image {
            select r.revision_id, r.mime_type
            from attachments a join cr_items i on i.item_id = a.item_id
            join cr_revisions r on r.revision_id = i.live_revision
            where a.object_id = :owner_id and a.item_id = :image_id
              and r.mime_type in ('image/png', 'image/jpeg', 'image/gif')
          }]} {
            set path [content::revision::get_cr_file_path -revision_id $revision_id]
            dict set drafts $image_id [list $path $mime_type legacy]
          }
        }
        continue
      }
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
  Save each staged image as a child File, using the standard export lifecycle.
} {
  set object_id [$page item_id]
  dict for {image_id draft} $drafts {
    lassign $draft path mime origin
    set file [::xowiki::File new -destroy_on_cleanup \
                  -parent_id $object_id -context_id $object_id \
                  -package_id [$page package_id] \
                  -name file:[file_name $image_id $mime] \
                  -title "Pasted image" -mime_type $mime \
                  -creation_user [ad_conn user_id]]
    $file set import_file $path
    $file save_new
    # FormPage may have an outer transaction. Retain the draft on rollback.
    if {$origin ne "legacy"} {
      ns_atclose [list ::xowiki::markdown_image::discard_attached_draft \
                      $object_id [$file item_id] $path]
    }
  }
}

ad_proc -private ::xowiki::markdown_image::discard_attached_draft {object_id image_id path} {
  Drop a staging file after the page and child File commit.
} {
  if {[db_string xowiki_markdown_image_committed {
    select 1 from cr_items where parent_id = :object_id and item_id = :image_id
  } -default 0]} {
    file delete -- $path
  }
}

ad_proc -private ::xowiki::markdown_image::file_name {image_id mime} {
  Return a portable name retained across export/import, independent of new IDs.
} {
  return pasted-$image_id.[lindex [split $mime /] 1]
}

ad_proc -private ::xowiki::markdown_image::rewrite {html references} {
  Replace draft IMG tags and their Markdown metadata with self-relative links.
} {
  set replacements {}
  foreach token [ns_parsehtml -- $html] {
    if {[lindex $token 0] ne "tag"} continue
    lassign [lindex $token 2] element attributes
    if {[string equal -nocase $element img] && [dict exists $attributes src]
        && [dict exists $references [dict get $attributes src]]} {
      lappend replacements [lindex $token 1] [dict get $references [dict get $attributes src]]
    }
  }
  set html [string map $replacements $html]
  if {[regexp {<!--openacs-markdown:v1:([A-Za-z0-9+/]+={0,2})-->\s*$} $html comment encoded]} {
    set markdown [encoding convertfrom utf-8 [ns_base64decode -binary -strict -- $encoded]]
    # Rewrite complete Markdown image expressions rather than URL substrings.
    set offset 0
    set rewritten ""
    while {[regexp -indices -start $offset {!\[[^\r\n]*?\]\(<([^<>\r\n]+)>\)} $markdown match url]} {
      lassign $match start end
      lassign $url url_start url_end
      append rewritten [string range $markdown $offset $start-1]
      set src [string range $markdown $url_start $url_end]
      append rewritten [expr {[dict exists $references $src]
                               ? [dict get $references $src]
                               : [string range $markdown $start $end]}]
      set offset [expr {$end + 1}]
    }
    append rewritten [string range $markdown $offset end]
    set encoded [binary encode base64 -maxlen 0 [encoding convertto utf-8 $rewritten]]
    set html [string map [list $comment "<!--openacs-markdown:v1:$encoded-->"] $html]
  }
  return $html
}

ad_proc -private ::xowiki::markdown_image::prepare {page drafts} {
  Rewrite both body and custom fields before saving. Return originals for rollback.
} {
  set references {}
  dict for {image_id draft} $drafts {
    lassign $draft path mime
    dict set references [ad_conn package_url]markdown-image?image_id=$image_id \
        "\[\[.SELF./image:[file_name $image_id $mime]\]\]"
  }
  set originals {}
  if {[dict size $references] == 0} {return $originals}
  foreach slot {text instance_attributes} {
    if {![$page exists $slot]} continue
    set value [$page set $slot]
    dict set originals $slot $value
    if {$slot eq "instance_attributes"} {
      dict for {name html} $value {
        dict set value $name [rewrite_value $html $references]
      }
    } else {
      set value [rewrite_value $value $references]
    }
    $page set $slot $value
  }
  return $originals
}

ad_proc -private ::xowiki::markdown_image::rewrite_value {value references} {
  Preserve the richtext content/format pair used by ordinary Wiki pages.
} {
  if {![catch {llength $value} length] && $length == 2
      && [lindex $value 1] eq "text/html"} {
    return [list [rewrite [lindex $value 0] $references] text/html]
  }
  return [rewrite $value $references]
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
