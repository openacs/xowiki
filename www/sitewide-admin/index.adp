<master>
<property name="doc(title)">@title;literal@</property>
<property name="context">@context;literal@</property>

<h1>@title;noquote@</h1>
<p>Checking for <strong>@resoure_name@</strong> in version @version@.
<include src="/packages/acs-tcl/lib/check-installed" &=resource_info &=version &=download_url>
