<master>
<property name="doc(title)">@title;literal@</property>
<property name="context">@context;literal@</property>

<h1>@title;noquote@</h1>

<p>The pages available for all package instances @package_key@ are available here:
<a href='/acs-admin/site-wide/@package_key@'>@package_key@  site-wide pages</a>.

<h2>@resource_title;noquote@</h2>

<ul class="list-group">
<li class="list-group-item">
  <h4>@resoure_name1@</h4>
  Checking for <strong>@resoure_name1@</strong> in version @version1@.
  <include src="/packages/acs-tcl/lib/check-installed" &resource_info=resource_info1 &download_url=download_url1>
</li>

<li class="list-group-item">
  <h4>@resoure_name2@</h4>
  <p>Checking for <strong>@resoure_name2@</strong> in version @version2@.
  <include src="/packages/acs-tcl/lib/check-installed" &resource_info=resource_info2 &download_url=download_url2>
</li>

<li class="list-group-item">
  <h4>@resoure_name3@</h4>
  <p>Checking for <strong>@resoure_name3@</strong> in version @version3@.
  <include src="/packages/acs-tcl/lib/check-installed" &resource_info=resource_info3 &download_url=download_url3>
</li>

<li class="list-group-item">
  <h4>@resoure_name4@</h4>
  <p>Checking for <strong>@resoure_name4@</strong> in version @version4@.
  <include src="/packages/acs-tcl/lib/check-installed" &resource_info=resource_info4 &download_url=download_url4>
</li>

</ul>