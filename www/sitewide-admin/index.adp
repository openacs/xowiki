<master>
<property name="doc(title)">@title;literal@</property>
<property name="context">@context;literal@</property>

<h1>@title;noquote@</h1>
<p>The pages available for all package instances @package_key@ are available here:
<a href='/acs-admin/site-wide/@package_key@'>@package_key@  site-wide pages</a>.

<h2>@resource_title;noquote@</h2>
<p>Checking for <strong>@resoure_name@</strong> in version @version@.
<include src="/packages/acs-tcl/lib/check-installed" &=resource_info &=version &=download_url>
