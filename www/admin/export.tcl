set object_type ::xowiki::Page
set folder_id [$object_type require_folder -name xowiki]

set content ""
db_foreach instance_select \
    [$object_type instance_select_query -folder_id $folder_id -with_subtypes true] {
      ::Generic::CrItem instantiate -item_id $item_id
      $item_id volatile
      append content [::Serializer deepSerialize $item_id] \n
    }

ns_return 200 text/plain $content