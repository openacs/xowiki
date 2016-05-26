<master>
<property name="doc(title)">@title;literal@</property>
<property name="&doc">property_doc</property>
<property name="header">@title;literal@</property>
<property name="context">@context;literal@</property>
<property name="displayed_object_id">@page_id;literal@</property>

@content;noquote@

<if @gc_comments@ not nil>
    <p>#file-storage.lt_Comments_on_this_file#
    <ul>@gc_comments;noquote@</ul></p>
</if>
<if @gc_link@ not nil>
    <p>@gc_link;noquote@</p>
</if>
