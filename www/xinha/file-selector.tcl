ad_page_contract {
  @author Guenter Ernst guenter.ernst@wu-wien.ac.at
  @author Gustaf Neumann neumann@wu-wien.ac.at
  @creation-date 13.10.2005
  @cvs-id $Id$
} {
  {fs_package_id:naturalnum,notnull,optional}
  {folder_id:naturalnum,optional}
  {orderby:token,optional}
  {selector_type "image"}
  {file_types "*"}
}

set HTML_NothingSelected [_ acs-templating.HTMLArea_SelectImageNothingSelected]
switch -- $selector_type {
  "image" {
    set HTML_Title  [_ acs-templating.HTMLArea_SelectImageTitle]
    set HTML_Legend [_ acs-templating.HTMLArea_SelectImage]
    set HTML_Preview [_ acs-templating.HTMLArea_SelectImagePreview]
    set HTML_UploadTitle [_ acs-templating.HTMLArea_SelectImageUploadTitle]
    set HTML_Context "COMMUNITY NAME"
  }
  "file" {
    set HTML_Title  [_ acs-templating.HTMLArea_SelectFileTitle]
    set HTML_Legend [_ acs-templating.HTMLArea_SelectFile]
    set HTML_Preview [_ acs-templating.HTMLArea_SelectImagePreview]
    set HTML_UploadTitle [_ acs-templating.HTMLArea_SelectFileUploadTitle]
    set HTML_Context "COMMUNITY NAME"
  }
}

template::add_event_listener -id "body" -event "blur" -script {
  myFocus();
}
template::add_event_listener -id "ok_button" -script {
  onOK();
}
template::add_event_listener -id "cancel_button" -script {
  onCancel();
}

if {![info exists fs_package_id]} {
  # we have not filestore package_id. This must be the first call.
  if {[info exists folder_id]} {
    # get package_id from folder_id
    foreach {fs_package_id root_folder_id} \
        [fs::get_folder_package_and_root $folder_id] break
  } else {
    # get package_id from package name
    set key file-storage
    # get file-storage instance from this subsite
    set subsite_node [subsite::get_element -element node_id]
    set mount_url [site_node::get_children -package_key $key -node_id $subsite_node]
    if { $mount_url eq "" } {
        # no file-storage instance at this subsite so look to main site
        set subsite_node [subsite::get_element -subsite_id [subsite::main_site_id] -element node_id]
        set mount_url [site_node::get_children -package_key file-storage -node_id $subsite_node]
    }
    if { $mount_url ne "" } {
        # file-storage instance IS at main site
        array set site_node [site_node::get -url $mount_url]
        set fs_package_id $site_node(package_id)
    } else {
        # look for any file-storage instance
        # probably not what user wants; could return error instead
        set id [apm_version_id_from_package_key $key]
        set mount_url [site_node::get_children -all -package_key $key -node_id $id]
        if {$mount_url ne ""} {
          array set site_node [site_node::get -url $mount_url]
          set fs_package_id $site_node(package_id)
        }
    }
  }
}

set write_p 0
set error_msg ""
set folder_name "*** unknown ***"
array set formerror [list upload_file $error_msg]

if {![info exists folder_id]} {
  if {![info exists fs_package_id]} {
    # The folder_id was not specified, the fs_package_id was not
    # specified, and we could not locate any usable file-storage.  We
    # give up with a semi-i18ned message, nobody should ever see
    # this...
    set error_msg "[_ file-storage.lt_bad_folder_id_folder_].\nPerhaps you have no file-storage package mounted?"
    array set formerror [list upload_file $error_msg]
    ad_complain $error_msg
    return
  }
  set folder_id [fs_get_root_folder -package_id $fs_package_id]
  set root_folder_id $folder_id
}

if {![fs_folder_p $folder_id]} {
  set error_msg [_ file-storage.lt_The_specified_folder__1]
  array set formerror [list upload_file $error_msg]
  ad_complain $error_msg
  return
}

# now we have at least a valid folder_id and a valid fs_package_id
if {![info exists root_folder_id]} {
  set root_folder_id [fs_get_root_folder -package_id $fs_package_id]
}

set fs_url [lindex [site_node::get_url_from_object_id -object_id $fs_package_id] 0]

# # Don't allow delete if root folder
set root_folder_p [expr {$folder_id == $root_folder_id}]

set user_id [ad_conn user_id]
permission::require_permission \
    -party_id $user_id -object_id $folder_id \
    -privilege "read"

set up_url {}

if { !$root_folder_p} {
  set parent_folder_id [fs::get_parent -item_id $folder_id]
  set up_name [fs::get_object_name -object_id $parent_folder_id]
  set up_url [export_vars -base file-selector \
                  {fs_package_id {folder_id $parent_folder_id}
                    selector_type file_types}]
}


# if user has write permission, create image upload form,
if {[permission::permission_p -party_id $user_id -object_id $folder_id \
         -privilege "write"]} {
  set write_p 1
  ad_form \
      -name upload_form \
      -mode edit \
      -export {fs_package_id folder_id orderby selector_type file_types} \
      -html { enctype multipart/form-data } \
      -form {
        {upload_file:file(file) {html {size 30}} }
        {ok_btn:text(submit) {label "[_ acs-templating.HTMLArea_SelectUploadBtn]"}
        }
      } \
      -on_submit {
        # check filename
        if {$upload_file eq ""} {
            template::form::set_error upload_form upload_file \
                [_ acs-templating.HTMLArea_SpecifyUploadFilename]
          break
        }

        if {[info exists folder_size]} {
          # check per folder quota
          set maximum_folder_size [parameter::get -parameter "MaximumFolderSize"]

          if { $maximum_folder_size ne "" } {
            if { $folder_size+[ad_file size ${upload_file.tmpfile}] > $maximum_folder_size } {
              template::form::set_error upload_form upload_file \
                [_ file-storage.out_of_space]
              break
            }
          }
        }

        set file_name [template::util::file::get_property filename $upload_file]
        set upload_tmpfile [template::util::file::get_property tmp_filename $upload_file]
        set mime_type [template::util::file::get_property mime_type $upload_file]

        if {$selector_type eq "image" && ![string match "image/*" $mime_type]} {
          template::form::set_error upload_form upload_file \
              [_ acs-templating.HTMLArea_SelectImageUploadNoImage]
          break
        }

        set existing_file_id [fs::get_item_id -name $file_name -folder_id $folder_id]

        if {$existing_file_id ne ""} {
          # write new revision
          fs::add_file \
              -name $file_name \
              -item_id $existing_file_id \
              -parent_id $folder_id \
              -tmp_filename $upload_tmpfile \
              -creation_user $user_id \
              -creation_ip [ad_conn peeraddr] \
              -package_id $fs_package_id
        } else {
          # write file
          fs::add_file \
              -name $file_name \
              -parent_id $folder_id \
              -tmp_filename $upload_tmpfile \
              -creation_user $user_id \
              -creation_ip [ad_conn peeraddr] \
              -package_id $fs_package_id
        }

      }
}

# display the contents

set folder_name [lang::util::localize [fs::get_object_name -object_id  $folder_id]]
set content_size_total 0

set folder_path [::xo::db::sql::content_item get_path \
                     -item_id $folder_id \
                     -root_folder_id $root_folder_id]

# -pass_to_urls {c}

template::list::create \
    -name contents \
    -multirow contents \
    -pass_properties {fs_package_id selector_type folder_id} \
    -key object_id \
    -html {width 100%}\
    -filters {folder_id {} file_types {} selector_type {} fs_package_id {}} \
    -elements {
      name {
        label "[_ file-storage.Name]"
        display_template {
          <if @contents.folder_p;literal@ false>
          <input type="radio" name="linktarget" value="@contents.object_id@"
             id="oi@contents.object_id@" />
          <input type="hidden" name="@contents.object_id@_file_url"
             id="@contents.object_id@_file_url" value="@contents.file_url@" />
          <input type="hidden" name="@contents.object_id@_file_name"
             id="@contents.object_id@_file_name" value="@contents.name@" />
          <input type="hidden" name="@contents.object_id@_file_title"
             id="@contents.object_id@_file_title" value="@contents.title@" />
          </if>
          <img src="@contents.icon@"  border="0" alt="#file-storage.@contents.type@#" />
          <a href="@contents.file_url@" id="link@contents.object_id@">@contents.name@</a>
        }
        orderby_desc {name desc}
        orderby_asc {name asc}
        html {nowrap ""}
      }
      content_size_pretty {
        label "[_ file-storage.Size]"
        orderby_desc {content_size desc}
        orderby_asc {content_size asc}
      }
      type {
        label "[_ file-storage.Type]"
        orderby_desc {type desc}
        orderby_asc {type asc}
      }
      last_modified_pretty {
        label "[_ file-storage.Last_Modified]"
        orderby_desc {last_modified_ansi desc}
        orderby_asc {last_modified_ansi asc}
        html {nowrap ""}
      }
    }

set order_by_clause [expr {([info exists orderby] && $orderby ne "") ?
                           [template::list::orderby_clause -orderby -name contents] :
                           " order by fs_objects.sort_key, fs_objects.name asc"}]


if {$selector_type eq "image"} {
  set file_types "image/%"
}
set filter_clause [expr {$file_types eq "*" ? "" :
                         "and (type like '$file_types' or type = 'folder')" }]

set fs_sql "select object_id, name, live_revision, type, title,
           to_char(last_modified, 'YYYY-MM-DD HH24:MI:SS') as last_modified_ansi,
           content_size, url, sort_key, file_upload_name,
           case
             when :folder_path::text is null
             then fs_objects.name
             else :folder_path::text || '/' || name
           end as file_url,
           case
             when last_modified >= (now() - cast('99999' as interval))
             then 1
             else 0
           end as new_p
        from fs_objects
        where parent_id = :folder_id
        and acs_permission__permission_p(fs_objects.object_id,:user_id,'read')='t'
         $filter_clause
         $order_by_clause"

db_multirow -extend {
  icon last_modified_pretty content_size_pretty
  properties_link properties_url folder_p title
} contents get_fs_contents $fs_sql {
  set last_modified_ansi   [lc_time_system_to_conn $last_modified_ansi]
  set last_modified_pretty [lc_time_fmt $last_modified_ansi "%x %X"]

  if {$type ne "folder"} {
    set content_size_pretty [lc_content_size_pretty -size $content_size]
  } else {
    set content_size_pretty ""
  }

  if {$title eq ""} {
    set title $name
  }

  if { $content_size ne "" } {
    incr content_size_total $content_size
  }

  set file_upload_name [ad_sanitize_filename \
                            -tolower \
                            $file_upload_name]

  set name [lang::util::localize $name]

  switch -- $type {
    folder {
      set folder_p 1
      set icon /resources/file-storage/folder.gif
      set file_url [export_vars -base file-selector \
                        {fs_package_id {folder_id $object_id}
                          selector_type file_types}]
    }
    url {
      set folder_p 1
      set icon /resources/url-button.gif
      set file_url $fs_url/$url
    }
    default {
      set folder_p 0
      set icon /resources/file-storage/file.gif
      set file_url ${fs_url}view/$file_url
    }
  }

  # We need to encode the hashes in any i18n message keys (.LRN plays
  # this trick on some of its folders). If we don't, the hashes will cause
  # the path to be chopped off (by ns_conn url) at the leftmost hash.
  regsub -all -- {\#} $file_url {%23} file_url

  #
  # Register listeners
  #
  template::add_event_listener -id "oi$object_id" -script [subst {
    onPreview('$file_url','$type');
  }]
  if {$folder_p == 0} {
    template::add_event_listener -id "link$object_id" -script [subst {
      selectImage('$object_id','$file_url','$type');
    }]
  }
}

ad_return_template

# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
