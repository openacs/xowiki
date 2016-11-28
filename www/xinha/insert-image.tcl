ad_page_contract {
  @author Guenter Ernst guenter.ernst@wu-wien.ac.at, 
  @author Gustaf Neumann neumann@wu-wien.ac.at
  @creation-date 13.07.2004
  @cvs-id $Id$
} {
  {fs_package_id:naturalnum,optional}
  {folder_id:naturalnum,optional}
}
 
set selector_type "image"
set file_selector_link [export_vars -base file-selector \
                            {fs_package_id folder_id selector_type}]
set fs_found 1


## Add event handlers

template::add_event_listener -id "body" -event "load" -script {
  Init();
}
template::add_event_listener -id "f_url" -event "change" -script {
  ChangeImageSrc();
}
template::add_event_listener -id "preview_button" -script {
  onPreview();
}
template::add_event_listener -id "image_selector_button" -script {
  openImageSelector();
}
template::add_event_listener -id "ok_button" -script {
  onOK();
}
template::add_event_listener -id "cancel_button" -script {
  onCancel();
}

##

# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
