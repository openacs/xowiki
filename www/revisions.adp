<master>
<property name="title">@title;noquote@</property>
<property name="&doc">property_doc</property>
<property name="header">@title;noquote@</property>
<property name="context">@context;noquote@</property>
<property name="displayed_object_id">@page_id;noquote@</property>

@content;noquote@

<if @gc_comments@ not nil>
    <p>#file-storage.lt_Comments_on_this_file#
    <ul>@gc_comments;noquote@</ul></p>
</if>
<if @gc_link@ not nil>
    <p>@gc_link;noquote@</p>
</if>
