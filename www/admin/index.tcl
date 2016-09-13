::xowiki::Package initialize -ad_doc {

  This is the admin page for the package.  It displays all of the types 
  of wiki pages provides links to delete them

  @author Gustaf Neumann neumann@wu-wien.ac.at
  @cvs-id $Id$

} -parameter {
  {-object_type ::xowiki::Page}
}

set context [list]
set pretty_plural [$object_type set pretty_plural]
set title [_ xowiki.admin_all_title]

set object_types [$object_type object_types]
set return_url   [ns_conn url]
set category_url [export_vars -base [$package_id package_url] { {manage-categories 1} {object_id $package_id}}]

lang::message::lookup "" xowiki.admin " "
TableWidget t1 -volatile \
    -actions [subst {
      Action new -label #xowiki.All_pages# -url list
      Action new -label "[lang::message::lookup {} categories.Categories Categories]" \
          -url $category_url
      Action new -label [_ acs-subsite.Parameters] -url \
          [export_vars -base /shared/parameters {package_id return_url}]
      Action new -label [_ xowiki.export] -url export
      Action new -label [_ xowiki.import] -url import
      Action new -label [_ acs-subsite.Permissions] -url [export_vars -base permissions {package_id}]
    }] \
    -columns {
      Field object_type -label [_ xowiki.page_type]
      AnchorField instances -label [_ xowiki.instances] -html {align center}
      AnchorField edit -CSSclass add-item-button -label [_ xowiki.add] -html {align center}
      AnchorField delete -CSSclass delete-item-button -label [_ xowiki.delete_all] \
          -html {align center class delete-all}
    }

template::add_body_script -script [subst {
  var confirmIt = function (e) {
    if (!confirm('[_ xowiki.delete_all_confirm]')) e.preventDefault();
  };
  var el = document.getElementsByTagName('td');
  for (i = 0; i < el.length; i++) {
    if (el\[i\].className == 'delete-all') {
      el\[i\].addEventListener('click', confirmIt, false);
    }
  };
}]

set base [::$package_id package_url]
foreach object_type $object_types {
  set return_url [export_vars -base ${base}admin {object_type}]
  set add_title ""
  set add_href ""
  set pretty_plural [$object_type pretty_plural]
  if {[catch {set n [db_list count [$object_type instance_select_query \
                                       -folder_id [::$package_id set folder_id] \
                                       -count 1 -with_subtypes false]]}]} {
    set n -
    set delete_title [_ xowiki.delete_all_items]
  } else {
    set add_title [_ xotcl-core.add [list type [$object_type pretty_name]]]
    set add_href  [$package_id make_link -with_entities 0 $package_id edit-new object_type return_url autoname]
    set delete_title [_ xowiki.delete_all_instances]
  }
  t1 add \
      -object_type  $object_type \
      -instances    $n \
      -instances.href [export_vars -base ./list {object_type}] \
      -edit         "" \
      -edit.href    $add_href \
      -edit.title   $add_title \
      -delete       "" \
      -delete.href  [export_vars -base delete-type {object_type}] \
      -delete.title $delete_title
}

set t1 [t1 asHTML]


# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
