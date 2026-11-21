ad_library {
  Clean up staging files for pasted XoWiki images.
}

ad_schedule_proc -thread t 3600 ::xowiki::markdown_image::expire_drafts
