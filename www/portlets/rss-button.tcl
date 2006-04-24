
set folder_id  [$__including_page set parent_id]
set package_id [$folder_id set package_id]
set instance [site_node::get_url_from_object_id -object_id $package_id]
